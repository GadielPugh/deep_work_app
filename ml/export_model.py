"""Export helpers for app-friendly model artifacts."""

from __future__ import annotations

import json
from datetime import datetime, timezone
from pathlib import Path
from typing import Any

from feature_engineering import FeatureVectorizer


def build_logistic_regression_artifact(
    *,
    model: Any,
    vectorizer: FeatureVectorizer,
    metrics: dict[str, Any],
    dataset_summary: dict[str, Any],
    training_config: dict[str, Any],
    classification_threshold: float,
    model_id: str = "session_success_logistic_regression_v1",
    variant: dict[str, Any] | None = None,
) -> dict[str, Any]:
    return {
        "schema_version": 1,
        "model_id": model_id,
        "model_type": "logistic_regression",
        "variant": variant,
        "target": {
            "name": "session_success",
            "positive_class": "outcome == yes",
            "negative_class": "outcome != yes",
        },
        "created_at": datetime.now(timezone.utc).isoformat(),
        "prediction": {
            "link_function": "sigmoid",
            "classification_threshold": classification_threshold,
        },
        "parameters": {
            "intercept": model.intercept,
            "coefficients": [
                {"feature": feature, "coefficient": coefficient}
                for feature, coefficient in zip(
                    vectorizer.feature_names,
                    model.coefficients,
                )
            ],
        },
        "feature_names": list(vectorizer.feature_names),
        "feature_metadata": vectorizer.to_metadata(),
        "metrics": metrics,
        "dataset": dataset_summary,
        "training_config": training_config,
        "integration_note": (
            "Flutter can evaluate this artifact with: sigmoid(intercept + "
            "sum(coefficient_i * transformed_feature_i)). Numeric features use "
            "the exported mean/scale; categorical features are one-hot encoded."
        ),
    }


def write_json(path: Path, payload: dict[str, Any]) -> None:
    path.parent.mkdir(parents=True, exist_ok=True)
    with path.open("w", encoding="utf-8") as file:
        json.dump(payload, file, indent=2, sort_keys=True)
        file.write("\n")
