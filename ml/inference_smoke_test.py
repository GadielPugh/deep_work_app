"""Load the exported JSON model and score one app-shaped sample."""

from __future__ import annotations

import argparse
import json
import math
from pathlib import Path
from typing import Any


PROJECT_ROOT = Path(__file__).resolve().parents[1]
DEFAULT_MODEL_PATH = PROJECT_ROOT / "ml" / "artifacts" / "session_success_model.json"
DEFAULT_METRICS_PATH = PROJECT_ROOT / "ml" / "artifacts" / "session_success_metrics.json"
DEFAULT_AUDIT_PATH = PROJECT_ROOT / "ml" / "artifacts" / "feature_audit_report.json"


def main() -> None:
    parser = argparse.ArgumentParser(
        description="Smoke test JSON logistic-regression inference.",
    )
    parser.add_argument(
        "--model",
        type=Path,
        default=DEFAULT_MODEL_PATH,
        help="Path to the exported JSON model artifact.",
    )
    parser.add_argument(
        "--metrics",
        type=Path,
        default=DEFAULT_METRICS_PATH,
        help="Path to the saved training metrics.",
    )
    parser.add_argument(
        "--audit",
        type=Path,
        default=DEFAULT_AUDIT_PATH,
        help="Path to the saved feature audit report.",
    )
    args = parser.parse_args()

    artifact = json.loads(args.model.read_text(encoding="utf-8"))
    metrics = json.loads(args.metrics.read_text(encoding="utf-8"))
    audit = json.loads(args.audit.read_text(encoding="utf-8"))
    validate_ablation_outputs(metrics=metrics, artifact=artifact, audit=audit)
    sample = {
        "category": "Coding",
        "time_block": "morning",
        "day_of_week": "monday",
        "duration_bucket": "standard",
        "latest_coach_message_type": "none",
        "latest_coach_confidence_label": "none",
        "duration_minutes": 25.0,
        "recent_success_rate": 0.6,
        "recent_session_count": 5.0,
        "recent_category_success_rate": 0.7,
        "recent_category_session_count": 3.0,
        "current_streak": 2.0,
        "current_success_streak": 2.0,
        "current_failure_streak": 0.0,
        "recent_coach_helpful_rate": 0.5,
        "recent_coach_feedback_count": 0.0,
        "coach_recommended_same_category": 0.0,
        "coach_recommended_duration_delta_minutes": 0.0,
        "recent_tag_flow": 0.0,
        "recent_tag_quiet": 0.0,
        "recent_tag_low_energy": 0.0,
        "recent_tag_phone": 0.0,
        "recent_tag_interruption": 0.0,
        "recent_tag_unclear": 0.0,
    }

    probability = score_sample(artifact, sample)
    if not 0.0 <= probability <= 1.0:
        raise AssertionError(f"probability out of range: {probability}")

    print(
        json.dumps(
            {
                "model": str(args.model),
                "model_id": artifact.get("model_id"),
                "variant": artifact.get("variant", {}).get("id"),
                "sample_probability": probability,
            },
            indent=2,
        )
    )


def validate_ablation_outputs(
    *,
    metrics: dict[str, Any],
    artifact: dict[str, Any],
    audit: dict[str, Any],
) -> None:
    required_variants = {
        "model_a_session_only",
        "model_b_reflection_plus",
        "model_c_coach_context",
    }
    model_ids = set(metrics.get("models", {}).keys())
    missing = required_variants - model_ids
    if missing:
        raise AssertionError(f"missing model variants: {sorted(missing)}")

    chosen = metrics.get("best_exported_model")
    if chosen not in required_variants:
        raise AssertionError(f"unexpected chosen export model: {chosen}")

    artifact_variant = artifact.get("variant", {}).get("id")
    if artifact_variant != chosen:
        raise AssertionError(
            f"artifact variant {artifact_variant} does not match metrics choice {chosen}"
        )

    audit_choice = audit.get("chosen_export_model")
    if audit_choice != chosen:
        raise AssertionError(
            f"audit choice {audit_choice} does not match metrics choice {chosen}"
        )


def score_sample(artifact: dict[str, Any], sample: dict[str, Any]) -> float:
    if artifact.get("model_type") != "logistic_regression":
        raise ValueError(f"Unsupported model_type: {artifact.get('model_type')}")

    parameters = artifact["parameters"]
    metadata = artifact["feature_metadata"]
    numeric_metadata = {
        row["name"]: row for row in metadata.get("numeric_features", [])
    }

    score = float(parameters["intercept"])
    for row in parameters["coefficients"]:
        feature_name = row["feature"]
        coefficient = float(row["coefficient"])
        score += coefficient * transformed_value(
            feature_name=feature_name,
            sample=sample,
            numeric_metadata=numeric_metadata,
        )

    return sigmoid(score)


def transformed_value(
    *,
    feature_name: str,
    sample: dict[str, Any],
    numeric_metadata: dict[str, dict[str, Any]],
) -> float:
    if "=" in feature_name:
        name, expected = feature_name.split("=", 1)
        actual = str(sample.get(name, ""))
        return 1.0 if actual.lower() == expected.lower() else 0.0

    value = float(sample.get(feature_name, 0.0))
    metadata = numeric_metadata.get(feature_name)
    if metadata is None:
        return value

    scale = float(metadata["scale"])
    if abs(scale) < 1e-9:
        scale = 1.0
    return (value - float(metadata["mean"])) / scale


def sigmoid(value: float) -> float:
    if value >= 0:
        z = math.exp(-value)
        return 1.0 / (1.0 + z)
    z = math.exp(value)
    return z / (1.0 + z)


if __name__ == "__main__":
    main()
