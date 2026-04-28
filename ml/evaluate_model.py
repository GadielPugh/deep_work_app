"""Evaluation helpers for the synthetic Deep Work ML pipeline."""

from __future__ import annotations

from typing import Any


def evaluate_probabilities(
    y_true: list[int],
    y_probability: list[float],
    threshold: float = 0.5,
) -> dict[str, Any]:
    if len(y_true) != len(y_probability):
        raise ValueError("y_true and y_probability must have the same length")
    if not y_true:
        raise ValueError("cannot evaluate empty predictions")

    tp = fp = tn = fn = 0
    brier_sum = 0.0

    for actual, probability in zip(y_true, y_probability):
        p = min(1.0, max(0.0, probability))
        predicted = 1 if p >= threshold else 0
        brier_sum += (p - actual) ** 2

        if predicted == 1 and actual == 1:
            tp += 1
        elif predicted == 1 and actual == 0:
            fp += 1
        elif predicted == 0 and actual == 0:
            tn += 1
        else:
            fn += 1

    total = len(y_true)
    accuracy = (tp + tn) / total
    precision = tp / (tp + fp) if (tp + fp) else 0.0
    recall = tp / (tp + fn) if (tp + fn) else 0.0
    f1 = (
        2 * precision * recall / (precision + recall)
        if (precision + recall)
        else 0.0
    )

    return {
        "total_count": total,
        "threshold": threshold,
        "accuracy": accuracy,
        "precision": precision,
        "recall": recall,
        "f1": f1,
        "specificity": tn / (tn + fp) if (tn + fp) else 0.0,
        "balanced_accuracy": (
            (tp / (tp + fn) if (tp + fn) else 0.0)
            + (tn / (tn + fp) if (tn + fp) else 0.0)
        )
        / 2,
        "roc_auc": roc_auc_score(y_true, y_probability),
        "brier_score": brier_sum / total,
        "confusion_matrix": {
            "true_positive": tp,
            "false_positive": fp,
            "true_negative": tn,
            "false_negative": fn,
        },
    }


def roc_auc_score(y_true: list[int], y_probability: list[float]) -> float | None:
    positives = [
        probability
        for actual, probability in zip(y_true, y_probability)
        if actual == 1
    ]
    negatives = [
        probability
        for actual, probability in zip(y_true, y_probability)
        if actual == 0
    ]

    if not positives or not negatives:
        return None

    wins = 0.0
    comparisons = 0
    for positive in positives:
        for negative in negatives:
            comparisons += 1
            if positive > negative:
                wins += 1.0
            elif positive == negative:
                wins += 0.5

    return wins / comparisons if comparisons else None


def global_success_rate_baseline(
    y_train: list[int],
    y_test: list[int],
    threshold: float = 0.5,
) -> dict[str, Any]:
    probability = sum(y_train) / len(y_train) if y_train else 0.5
    probabilities = [probability for _ in y_test]
    metrics = evaluate_probabilities(y_test, probabilities, threshold=threshold)
    metrics["baseline_probability"] = probability
    return metrics


def category_only_baseline(
    train_rows: list[dict[str, Any]],
    y_train: list[int],
    test_rows: list[dict[str, Any]],
    y_test: list[int],
    threshold: float = 0.5,
) -> dict[str, Any]:
    global_probability = sum(y_train) / len(y_train) if y_train else 0.5
    counts: dict[str, int] = {}
    successes: dict[str, int] = {}

    for row, label in zip(train_rows, y_train):
        category = str(row.get("category", "unknown"))
        counts[category] = counts.get(category, 0) + 1
        successes[category] = successes.get(category, 0) + label

    category_probabilities = {
        category: successes[category] / count
        for category, count in counts.items()
    }
    probabilities = [
        category_probabilities.get(str(row.get("category", "unknown")), global_probability)
        for row in test_rows
    ]

    metrics = evaluate_probabilities(y_test, probabilities, threshold=threshold)
    metrics["global_fallback_probability"] = global_probability
    metrics["category_probabilities"] = category_probabilities
    return metrics


def threshold_sweep(
    y_true: list[int],
    y_probability: list[float],
    thresholds: list[float] | None = None,
) -> dict[str, Any]:
    if thresholds is None:
        thresholds = [round(index / 20, 2) for index in range(1, 20)]

    rows = [
        {
            **evaluate_probabilities(y_true, y_probability, threshold=threshold),
            "balanced_usefulness": _balanced_usefulness(
                evaluate_probabilities(y_true, y_probability, threshold=threshold)
            ),
        }
        for threshold in thresholds
    ]

    best_by_f1 = max(rows, key=lambda row: (row["f1"], row["recall"], row["precision"]))
    best_by_usefulness = max(
        rows,
        key=lambda row: (
            row["balanced_usefulness"],
            row["f1"],
            row["balanced_accuracy"],
        ),
    )
    default_threshold = min(rows, key=lambda row: abs(row["threshold"] - 0.5))

    return {
        "thresholds_tried": rows,
        "best_threshold_by_f1": _threshold_summary(best_by_f1),
        "best_threshold_by_balanced_usefulness": _threshold_summary(
            best_by_usefulness
        ),
        "default_threshold": _threshold_summary(default_threshold),
    }


def calibration_buckets(
    y_true: list[int],
    y_probability: list[float],
    bucket_count: int = 5,
) -> list[dict[str, Any]]:
    if len(y_true) != len(y_probability):
        raise ValueError("y_true and y_probability must have the same length")
    if not y_true:
        return []

    buckets: list[list[tuple[int, float]]] = [[] for _ in range(bucket_count)]
    for actual, probability in zip(y_true, y_probability):
        p = min(1.0, max(0.0, probability))
        index = min(bucket_count - 1, int(p * bucket_count))
        buckets[index].append((actual, p))

    result: list[dict[str, Any]] = []
    for index, rows in enumerate(buckets):
        start = index / bucket_count
        end = (index + 1) / bucket_count
        if rows:
            avg_probability = sum(row[1] for row in rows) / len(rows)
            observed_success_rate = sum(row[0] for row in rows) / len(rows)
        else:
            avg_probability = 0.0
            observed_success_rate = 0.0
        result.append(
            {
                "range_start": start,
                "range_end": end,
                "count": len(rows),
                "avg_predicted_probability": avg_probability,
                "observed_success_rate": observed_success_rate,
            }
        )
    return result


def _balanced_usefulness(metrics: dict[str, Any]) -> float:
    # Small, explicit utility: reward positive-class usefulness (F1) and not
    # calling everything positive/negative (balanced accuracy) equally.
    return 0.5 * metrics["f1"] + 0.5 * metrics["balanced_accuracy"]


def _threshold_summary(metrics: dict[str, Any]) -> dict[str, Any]:
    keys = (
        "threshold",
        "accuracy",
        "precision",
        "recall",
        "specificity",
        "f1",
        "balanced_accuracy",
        "balanced_usefulness",
    )
    return {key: metrics[key] for key in keys}
