"""Train the first synthetic Deep Work session-success model.

This script intentionally avoids heavyweight dependencies so the pipeline can
run anywhere a normal Flutter checkout has Python 3 available.
"""

from __future__ import annotations

import argparse
import json
import math
from dataclasses import dataclass
from pathlib import Path
from typing import Any

from evaluate_model import (
    calibration_buckets,
    category_only_baseline,
    evaluate_probabilities,
    global_success_rate_baseline,
    threshold_sweep,
)
from export_model import build_logistic_regression_artifact, write_json
from feature_engineering import (
    FEATURE_SETS,
    FeatureSet,
    FeatureVectorizer,
    load_and_build_dataset,
    train_test_split_chronological,
)


PROJECT_ROOT = Path(__file__).resolve().parents[1]
MOUNTED_DATA_DIR = Path("/mnt/data/deep_work_synthetic_ml")
REPO_DATA_DIR = PROJECT_ROOT / "lib" / "models" / "ml" / "data"
DEFAULT_DATA_DIR = MOUNTED_DATA_DIR if MOUNTED_DATA_DIR.exists() else REPO_DATA_DIR
DEFAULT_OUTPUT_DIR = PROJECT_ROOT / "ml" / "artifacts"
COACH_FEATURE_PREFIXES = (
    "recent_coach_",
    "coach_recommended_",
    "latest_coach_",
)


@dataclass
class LogisticRegression:
    coefficients: list[float]
    intercept: float

    @classmethod
    def fit(
        cls,
        x_train: list[list[float]],
        y_train: list[int],
        *,
        learning_rate: float,
        epochs: int,
        l2: float,
    ) -> "LogisticRegression":
        if not x_train:
            raise ValueError("x_train must not be empty")

        num_features = len(x_train[0])
        coefficients = [0.0] * num_features
        base_rate = min(0.99, max(0.01, sum(y_train) / len(y_train)))
        intercept = math.log(base_rate / (1.0 - base_rate))

        for _ in range(epochs):
            gradient_w = [0.0] * num_features
            gradient_b = 0.0

            for features, label in zip(x_train, y_train):
                probability = _sigmoid(_dot(coefficients, features) + intercept)
                error = probability - label
                gradient_b += error
                for index, value in enumerate(features):
                    gradient_w[index] += error * value

            n = len(x_train)
            intercept -= learning_rate * (gradient_b / n)
            for index in range(num_features):
                regularization = l2 * coefficients[index]
                coefficients[index] -= learning_rate * (
                    gradient_w[index] / n + regularization
                )

        return cls(coefficients=coefficients, intercept=intercept)

    def predict_probability(self, x_rows: list[list[float]]) -> list[float]:
        return [
            _sigmoid(_dot(self.coefficients, row) + self.intercept)
            for row in x_rows
        ]


def main() -> None:
    parser = argparse.ArgumentParser(
        description="Train a logistic regression model on Deep Work synthetic data.",
    )
    parser.add_argument(
        "--data-dir",
        type=Path,
        default=DEFAULT_DATA_DIR,
        help=(
            "Directory containing either synthetic_* files or exported real "
            "app JSONL files."
        ),
    )
    parser.add_argument(
        "--sessions",
        type=Path,
        default=None,
        help="Path to synthetic_sessions.csv or synthetic_sessions.jsonl.",
    )
    parser.add_argument(
        "--coach-feedback",
        type=Path,
        default=None,
        help="Path to synthetic_coach_feedback.jsonl.",
    )
    parser.add_argument(
        "--coach-snapshots",
        type=Path,
        default=None,
        help="Path to synthetic_coach_snapshots.jsonl.",
    )
    parser.add_argument(
        "--shadow-logs",
        type=Path,
        default=None,
        help="Path to exported shadow_predictions.jsonl.",
    )
    parser.add_argument(
        "--output-dir",
        type=Path,
        default=DEFAULT_OUTPUT_DIR,
        help="Directory for exported artifacts.",
    )
    parser.add_argument(
        "--dataset-kind",
        choices=("auto", "synthetic", "real"),
        default="auto",
        help="Controls reporting mode. Auto treats sessions.jsonl exports as real data.",
    )
    parser.add_argument(
        "--real-data-eval",
        action="store_true",
        help="Force real-data validation reporting.",
    )
    parser.add_argument("--epochs", type=int, default=4000)
    parser.add_argument("--learning-rate", type=float, default=0.05)
    parser.add_argument("--l2", type=float, default=0.01)
    parser.add_argument("--test-fraction", type=float, default=0.2)
    parser.add_argument("--threshold", type=float, default=0.5)
    args = parser.parse_args()
    sessions_path, feedback_path, snapshots_path, shadow_logs_path = resolve_input_paths(
        data_dir=args.data_dir,
        sessions_path=args.sessions,
        feedback_path=args.coach_feedback,
        snapshots_path=args.coach_snapshots,
        shadow_logs_path=args.shadow_logs,
    )
    dataset_kind = resolve_dataset_kind(
        requested=args.dataset_kind,
        sessions_path=sessions_path,
    )
    is_real_data_eval = args.real_data_eval or dataset_kind == "real"

    dataset = load_and_build_dataset(
        sessions_path=sessions_path,
        feedback_path=feedback_path,
        snapshots_path=snapshots_path,
        shadow_logs_path=shadow_logs_path,
    )
    train_rows, y_train, test_rows, y_test = train_test_split_chronological(
        dataset.rows,
        dataset.labels,
        test_fraction=args.test_fraction,
    )

    trained_variants: dict[str, tuple[FeatureSet, FeatureVectorizer, LogisticRegression]] = {}
    model_results: dict[str, Any] = {}
    audit_results: dict[str, Any] = {}
    validation_probabilities: dict[str, list[float]] = {}

    for feature_set in FEATURE_SETS:
        vectorizer = FeatureVectorizer.fit(
            train_rows,
            numeric_features=feature_set.numeric_features,
            categorical_features=feature_set.categorical_features,
        )
        x_train = vectorizer.transform(train_rows)
        x_test = vectorizer.transform(test_rows)

        model = LogisticRegression.fit(
            x_train,
            y_train,
            learning_rate=args.learning_rate,
            epochs=args.epochs,
            l2=args.l2,
        )
        model_probabilities = model.predict_probability(x_test)
        model_metrics = evaluate_probabilities(
            y_test,
            model_probabilities,
            threshold=args.threshold,
        )
        threshold_report = threshold_sweep(y_test, model_probabilities)
        top_features = top_weighted_features(model, vectorizer)
        audit = audit_feature_dominance(top_features, vectorizer.feature_names)

        trained_variants[feature_set.id] = (feature_set, vectorizer, model)
        validation_probabilities[feature_set.id] = model_probabilities
        model_results[feature_set.id] = {
            "name": feature_set.name,
            "description": feature_set.description,
            "feature_count": len(vectorizer.feature_names),
            "metrics": model_metrics,
            "threshold_tuning": threshold_report,
        }
        audit_results[feature_set.id] = {
            "name": feature_set.name,
            "top_weighted_features": top_features,
            **audit,
        }

    global_baseline_metrics = global_success_rate_baseline(
        y_train,
        y_test,
        threshold=args.threshold,
    )
    category_baseline_metrics = category_only_baseline(
        train_rows,
        y_train,
        test_rows,
        y_test,
        threshold=args.threshold,
    )

    training_config = {
        "algorithm": "batch_gradient_descent",
        "epochs": args.epochs,
        "learning_rate": args.learning_rate,
        "l2": args.l2,
        "test_fraction": args.test_fraction,
        "split": "chronological",
        "dataset_kind": dataset_kind,
    }
    chosen_variant_id = choose_export_variant(model_results, audit_results)
    chosen_threshold = (
        model_results[chosen_variant_id]["threshold_tuning"][
            "best_threshold_by_balanced_usefulness"
        ]["threshold"]
        if is_real_data_eval
        else args.threshold
    )
    metrics_payload: dict[str, Any] = {
        "dataset_kind": dataset_kind,
        "dataset": dataset.summary,
        "split": {
            "train_count": len(train_rows),
            "test_count": len(test_rows),
            "train_success_rate": sum(y_train) / len(y_train),
            "test_success_rate": sum(y_test) / len(y_test),
        },
        "models": model_results,
        "baselines": {
            "global_success_rate": global_baseline_metrics,
            "category_only": category_baseline_metrics,
        },
        "best_exported_model": chosen_variant_id,
        "chosen_threshold": chosen_threshold,
        "training_config": training_config,
    }

    chosen_feature_set, chosen_vectorizer, chosen_model = trained_variants[chosen_variant_id]
    artifact = build_logistic_regression_artifact(
        model=chosen_model,
        vectorizer=chosen_vectorizer,
        metrics=metrics_payload,
        dataset_summary=dataset.summary,
        training_config=training_config,
        classification_threshold=chosen_threshold,
        model_id=f"session_success_{chosen_variant_id}_v1",
        variant={
            "id": chosen_feature_set.id,
            "name": chosen_feature_set.name,
            "description": chosen_feature_set.description,
            "selection_reason": export_selection_reason(
                chosen_variant_id,
                model_results,
                audit_results,
            ),
        },
    )

    model_path = args.output_dir / "session_success_model.json"
    metrics_path = args.output_dir / "session_success_metrics.json"
    audit_path = args.output_dir / "feature_audit_report.json"
    real_report_path = args.output_dir / "real_data_evaluation_report.json"
    write_json(model_path, artifact)
    write_json(metrics_path, metrics_payload)
    write_json(
        audit_path,
        {
            "chosen_export_model": chosen_variant_id,
            "selection_reason": artifact["variant"]["selection_reason"],
            "variants": audit_results,
        },
    )
    real_report = None
    if is_real_data_eval:
        shadow_analysis = analyze_shadow_logs(shadow_logs_path)
        real_report = build_real_data_evaluation_report(
            metrics_payload=metrics_payload,
            audit_results=audit_results,
            shadow_analysis=shadow_analysis,
        )
        write_json(real_report_path, real_report)

    print(
        json.dumps(
            _console_summary(
                metrics_payload,
                audit_results,
                model_path,
                metrics_path,
                audit_path,
                real_report_path if real_report is not None else None,
            ),
            indent=2,
        )
    )


def _console_summary(
    metrics_payload: dict[str, Any],
    audit_results: dict[str, Any],
    model_path: Path,
    metrics_path: Path,
    audit_path: Path,
    real_report_path: Path | None = None,
) -> dict[str, Any]:
    summary = {
        "dataset": metrics_payload["dataset"],
        "split": metrics_payload["split"],
        "models": {
            variant_id: {
                "name": result["name"],
                **_short_metrics(result["metrics"]),
                "audit_notes": audit_results[variant_id]["notes"],
            }
            for variant_id, result in metrics_payload["models"].items()
        },
        "baselines": {
            "global_success_rate": _short_metrics(
                metrics_payload["baselines"]["global_success_rate"]
            ),
            "category_only": _short_metrics(
                metrics_payload["baselines"]["category_only"]
            ),
        },
        "chosen_export_model": metrics_payload["best_exported_model"],
        "chosen_threshold": metrics_payload["chosen_threshold"],
        "artifacts": {
            "model": str(model_path),
            "metrics": str(metrics_path),
            "feature_audit": str(audit_path),
        },
    }
    if real_report_path is not None:
        summary["artifacts"]["real_data_evaluation_report"] = str(real_report_path)
    return summary


def _short_metrics(metrics: dict[str, Any]) -> dict[str, Any]:
    keys = ("accuracy", "precision", "recall", "f1", "roc_auc", "brier_score")
    return {key: metrics[key] for key in keys}


def _dot(left: list[float], right: list[float]) -> float:
    return sum(a * b for a, b in zip(left, right))


def _sigmoid(value: float) -> float:
    if value >= 0:
        z = math.exp(-value)
        return 1.0 / (1.0 + z)
    z = math.exp(value)
    return z / (1.0 + z)


def resolve_input_paths(
    *,
    data_dir: Path,
    sessions_path: Path | None,
    feedback_path: Path | None,
    snapshots_path: Path | None,
    shadow_logs_path: Path | None,
) -> tuple[Path, Path | None, Path | None, Path | None]:
    sessions = sessions_path or first_existing(
        data_dir / "sessions.jsonl",
        data_dir / "synthetic_sessions.csv",
        data_dir / "synthetic_sessions.jsonl",
    )
    if sessions is None:
        raise FileNotFoundError(
            f"No sessions file found in {data_dir}. Expected sessions.jsonl "
            "or synthetic_sessions.csv/jsonl."
        )

    feedback = feedback_path or first_existing(
        data_dir / "coach_feedback.jsonl",
        data_dir / "synthetic_coach_feedback.jsonl",
    )
    snapshots = snapshots_path or first_existing(
        data_dir / "coach_snapshots.jsonl",
        data_dir / "synthetic_coach_snapshots.jsonl",
    )
    shadow_logs = shadow_logs_path or first_existing(
        data_dir / "shadow_predictions.jsonl",
    )
    return sessions, feedback, snapshots, shadow_logs


def resolve_dataset_kind(*, requested: str, sessions_path: Path) -> str:
    if requested != "auto":
        return requested
    return "real" if sessions_path.name == "sessions.jsonl" else "synthetic"


def first_existing(*paths: Path) -> Path | None:
    for path in paths:
        if path.exists():
            return path
    return None


def top_weighted_features(
    model: LogisticRegression,
    vectorizer: FeatureVectorizer,
    limit: int = 12,
) -> list[dict[str, Any]]:
    rows = [
        {
            "feature": feature,
            "coefficient": coefficient,
            "abs_coefficient": abs(coefficient),
        }
        for feature, coefficient in zip(vectorizer.feature_names, model.coefficients)
    ]
    rows.sort(key=lambda row: row["abs_coefficient"], reverse=True)
    return rows[:limit]


def audit_feature_dominance(
    top_features: list[dict[str, Any]],
    feature_names: tuple[str, ...],
) -> dict[str, Any]:
    coach_features = [
        name for name in feature_names if is_coach_feature(name)
    ]
    top_coach_features = [
        row for row in top_features if is_coach_feature(str(row["feature"]))
    ]
    top_three = top_features[:3]
    coach_in_top_three = any(is_coach_feature(str(row["feature"])) for row in top_three)
    strongest = top_features[0] if top_features else None
    strongest_is_coach = (
        strongest is not None and is_coach_feature(str(strongest["feature"]))
    )
    top_abs_sum = sum(float(row["abs_coefficient"]) for row in top_features) or 1.0
    coach_top_abs_sum = sum(
        float(row["abs_coefficient"]) for row in top_coach_features
    )
    coach_top_abs_share = coach_top_abs_sum / top_abs_sum
    suspicious = bool(
        coach_features
        and (strongest_is_coach or coach_in_top_three or coach_top_abs_share >= 0.35)
    )

    notes: list[str] = []
    if not coach_features:
        notes.append("No coach feedback or coach snapshot features in this variant.")
    elif suspicious:
        notes.append(
            "Coach-context features dominate the top weights; treat this variant as suspicious for export."
        )
    else:
        notes.append("Coach-context features are present but do not dominate top weights.")

    return {
        "coach_feature_count": len(coach_features),
        "coach_top_weight_share": coach_top_abs_share if coach_features else 0.0,
        "coach_feature_in_top_three": coach_in_top_three,
        "strongest_feature_is_coach_context": strongest_is_coach,
        "suspicious_coach_context_dependence": suspicious,
        "notes": notes,
    }


def choose_export_variant(
    model_results: dict[str, Any],
    audit_results: dict[str, Any],
) -> str:
    model_a = "model_a_session_only"
    model_b = "model_b_reflection_plus"
    model_c = "model_c_coach_context"

    f1_a = float(model_results[model_a]["metrics"]["f1"])
    f1_b = float(model_results[model_b]["metrics"]["f1"])
    clean_choice = model_a if f1_a + 0.02 >= f1_b else model_b

    f1_clean = float(model_results[clean_choice]["metrics"]["f1"])
    f1_c = float(model_results[model_c]["metrics"]["f1"])
    c_suspicious = bool(
        audit_results[model_c]["suspicious_coach_context_dependence"]
    )

    if not c_suspicious and f1_c > f1_clean + 0.05:
        return model_c
    return clean_choice


def export_selection_reason(
    chosen_variant_id: str,
    model_results: dict[str, Any],
    audit_results: dict[str, Any],
) -> str:
    chosen = model_results[chosen_variant_id]
    model_c_audit = audit_results["model_c_coach_context"]
    c_note = (
        "Model C was not selected because coach-context features looked dominant."
        if model_c_audit["suspicious_coach_context_dependence"]
        else "Model C did not improve enough to justify using coach-context features."
    )
    return (
        f"Selected {chosen['name']} with F1={chosen['metrics']['f1']:.3f}. "
        f"{c_note}"
    )


def is_coach_feature(feature_name: str) -> bool:
    return feature_name.startswith(COACH_FEATURE_PREFIXES)


def analyze_shadow_logs(shadow_logs_path: Path | None) -> dict[str, Any]:
    rows = load_jsonl(shadow_logs_path) if shadow_logs_path else []
    resolved: list[tuple[int, float]] = []
    unresolved_count = 0
    invalid_probability_count = 0

    for row in rows:
        probability = as_float_or_none(row.get("mlSuccessProbability"))
        if probability is None:
            invalid_probability_count += 1
            continue

        outcome = row.get("laterSessionSucceeded")
        if outcome is True:
            resolved.append((1, probability))
        elif outcome is False:
            resolved.append((0, probability))
        else:
            unresolved_count += 1

    success_probabilities = [prob for actual, prob in resolved if actual == 1]
    failure_probabilities = [prob for actual, prob in resolved if actual == 0]

    return {
        "source_file": str(shadow_logs_path) if shadow_logs_path else None,
        "total_rows": len(rows),
        "resolved_rows": len(resolved),
        "unresolved_rows": unresolved_count,
        "invalid_probability_rows": invalid_probability_count,
        "successful_session_rows": len(success_probabilities),
        "failed_session_rows": len(failure_probabilities),
        "avg_probability_before_success": average_or_none(success_probabilities),
        "avg_probability_before_failure": average_or_none(failure_probabilities),
        "calibration_buckets": calibration_buckets(
            [actual for actual, _ in resolved],
            [prob for _, prob in resolved],
        )
        if len(resolved) >= 5
        else [],
        "notes": shadow_analysis_notes(
            resolved_count=len(resolved),
            success_probabilities=success_probabilities,
            failure_probabilities=failure_probabilities,
        ),
    }


def build_real_data_evaluation_report(
    *,
    metrics_payload: dict[str, Any],
    audit_results: dict[str, Any],
    shadow_analysis: dict[str, Any],
) -> dict[str, Any]:
    chosen_variant = metrics_payload["best_exported_model"]
    chosen = metrics_payload["models"][chosen_variant]
    baseline_f1 = max(
        float(metrics_payload["baselines"]["global_success_rate"]["f1"]),
        float(metrics_payload["baselines"]["category_only"]["f1"]),
    )
    recommendation = real_data_recommendation(
        dataset=metrics_payload["dataset"],
        split=metrics_payload["split"],
        chosen_metrics=chosen["metrics"],
        baseline_f1=baseline_f1,
        shadow_analysis=shadow_analysis,
    )

    return {
        "schema_version": 1,
        "report_type": "real_data_validation",
        "dataset": {
            "dataset_kind": metrics_payload["dataset_kind"],
            "num_rows": metrics_payload["dataset"]["num_rows"],
            "num_sessions": metrics_payload["dataset"]["num_sessions"],
            "class_balance": {
                "success_count": metrics_payload["dataset"]["success_count"],
                "failure_count": metrics_payload["dataset"]["failure_count"],
                "success_rate": metrics_payload["dataset"]["success_rate"],
            },
            "source_files": metrics_payload["dataset"]["source_files"],
        },
        "split": metrics_payload["split"],
        "models": metrics_payload["models"],
        "baselines": metrics_payload["baselines"],
        "chosen_model": {
            "variant_id": chosen_variant,
            "name": chosen["name"],
            "chosen_threshold": metrics_payload["chosen_threshold"],
            "threshold_choice_reason": (
                "Selected by highest balanced usefulness on the validation split."
            ),
            "audit_notes": audit_results[chosen_variant]["notes"],
        },
        "shadow_log_analysis": shadow_analysis,
        "recommendation": recommendation,
    }


def real_data_recommendation(
    *,
    dataset: dict[str, Any],
    split: dict[str, Any],
    chosen_metrics: dict[str, Any],
    baseline_f1: float,
    shadow_analysis: dict[str, Any],
) -> dict[str, Any]:
    num_rows = int(dataset["num_rows"])
    test_count = int(split["test_count"])
    resolved_shadow = int(shadow_analysis["resolved_rows"])
    chosen_f1 = float(chosen_metrics["f1"])
    success_avg = shadow_analysis["avg_probability_before_success"]
    failure_avg = shadow_analysis["avg_probability_before_failure"]
    shadow_direction_ok = (
        success_avg is not None and failure_avg is not None and success_avg > failure_avg
    )

    if num_rows < 30 or test_count < 10 or resolved_shadow < 10:
        return {
            "decision": "not_enough_data",
            "message": (
                "Keep ML in shadow mode; real history or resolved shadow outcomes "
                "are still too sparse for blending."
            ),
        }
    if chosen_f1 >= baseline_f1 + 0.05 and shadow_direction_ok:
        return {
            "decision": "blend_later",
            "message": (
                "ML shows enough lift and shadow probabilities point in the "
                "right direction. Consider a cautious blend after more review."
            ),
        }
    return {
        "decision": "keep_shadow_only",
        "message": (
            "Keep ML in shadow mode until it shows clearer lift over baselines "
            "and better shadow calibration."
        ),
    }


def shadow_analysis_notes(
    *,
    resolved_count: int,
    success_probabilities: list[float],
    failure_probabilities: list[float],
) -> list[str]:
    if resolved_count == 0:
        return ["No resolved shadow outcomes yet."]
    if resolved_count < 5:
        return ["Very few resolved shadow outcomes; calibration buckets skipped."]
    if not success_probabilities or not failure_probabilities:
        return ["Resolved shadow outcomes contain only one class so far."]
    if average_or_none(success_probabilities) > average_or_none(failure_probabilities):
        return ["Average ML probability is higher before successful sessions."]
    return ["Average ML probability is not higher before successful sessions yet."]


def load_jsonl(path: Path | None) -> list[dict[str, Any]]:
    if path is None or not path.exists():
        return []
    rows: list[dict[str, Any]] = []
    with path.open("r", encoding="utf-8") as file:
        for line in file:
            stripped = line.strip()
            if not stripped:
                continue
            decoded = json.loads(stripped)
            if isinstance(decoded, dict):
                rows.append(decoded)
    return rows


def average_or_none(values: list[float]) -> float | None:
    return sum(values) / len(values) if values else None


def as_float_or_none(value: Any) -> float | None:
    try:
        if value is None or value == "":
            return None
        probability = float(value)
        return max(0.0, min(1.0, probability))
    except (TypeError, ValueError):
        return None


if __name__ == "__main__":
    main()
