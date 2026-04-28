"""Feature engineering for the Deep Work synthetic ML pipeline.

The pipeline treats sessions as the primary source of truth. Coach feedback and
coach snapshots are optional, time-aware context: only rows created before a
session start are allowed to influence that session's features.
"""

from __future__ import annotations

import csv
import json
import math
from dataclasses import dataclass
from datetime import datetime, timezone
from pathlib import Path
from typing import Any


ROLLING_SESSION_COUNT = 10
ROLLING_FEEDBACK_DAYS = 30
LATEST_SNAPSHOT_WINDOW_HOURS = 6

REFLECTION_TAG_KEYWORDS: dict[str, tuple[str, ...]] = {
    "flow": ("flow", "rhythm", "momentum", "deep work"),
    "quiet": ("quiet", "silent", "calm", "environment helped"),
    "low_energy": ("low energy", "tired", "fatigue", "sleepy"),
    "phone": ("phone", "scroll", "social"),
    "interruption": ("interruption", "interrupted", "distraction", "distracted"),
    "unclear": ("unclear", "confused", "not clear", "uncertain"),
}

NUMERIC_FEATURES: tuple[str, ...] = (
    "duration_minutes",
    "recent_success_rate",
    "recent_session_count",
    "recent_category_success_rate",
    "recent_category_session_count",
    "current_streak",
    "current_success_streak",
    "current_failure_streak",
    "recent_coach_helpful_rate",
    "recent_coach_feedback_count",
    "coach_recommended_same_category",
    "coach_recommended_duration_delta_minutes",
    "recent_tag_flow",
    "recent_tag_quiet",
    "recent_tag_low_energy",
    "recent_tag_phone",
    "recent_tag_interruption",
    "recent_tag_unclear",
)

CATEGORICAL_FEATURES: tuple[str, ...] = (
    "category",
    "time_block",
    "day_of_week",
    "duration_bucket",
    "latest_coach_message_type",
    "latest_coach_confidence_label",
)

CATEGORICAL_VALUE_HINTS: dict[str, tuple[str, ...]] = {
    "time_block": ("morning", "afternoon", "evening", "night"),
    "day_of_week": (
        "monday",
        "tuesday",
        "wednesday",
        "thursday",
        "friday",
        "saturday",
        "sunday",
    ),
    "duration_bucket": ("short", "standard", "long", "extended"),
    "latest_coach_message_type": ("none", "positive", "neutral", "warning"),
    "latest_coach_confidence_label": ("none", "low", "medium", "high"),
}


@dataclass(frozen=True)
class Dataset:
    rows: list[dict[str, Any]]
    labels: list[int]
    summary: dict[str, Any]


@dataclass(frozen=True)
class FeatureSet:
    id: str
    name: str
    description: str
    numeric_features: tuple[str, ...]
    categorical_features: tuple[str, ...]


SESSION_NUMERIC_FEATURES: tuple[str, ...] = (
    "recent_success_rate",
    "recent_category_success_rate",
    "current_streak",
    "current_success_streak",
    "current_failure_streak",
)

SESSION_CATEGORICAL_FEATURES: tuple[str, ...] = (
    "category",
    "time_block",
    "day_of_week",
    "duration_bucket",
)

REFLECTION_TAG_FEATURES: tuple[str, ...] = (
    "recent_tag_flow",
    "recent_tag_quiet",
    "recent_tag_low_energy",
    "recent_tag_phone",
    "recent_tag_interruption",
    "recent_tag_unclear",
)

REFLECTION_AGGREGATE_FEATURES: tuple[str, ...] = (
    "recent_reflection_tag_count",
    "recent_positive_reflection_tag_count",
    "recent_distraction_reflection_tag_count",
)

COACH_NUMERIC_FEATURES: tuple[str, ...] = (
    "recent_coach_helpful_rate",
    "recent_coach_feedback_count",
    "coach_recommended_same_category",
    "coach_recommended_duration_delta_minutes",
)

COACH_CATEGORICAL_FEATURES: tuple[str, ...] = (
    "latest_coach_message_type",
    "latest_coach_confidence_label",
)

FEATURE_SETS: tuple[FeatureSet, ...] = (
    FeatureSet(
        id="model_a_session_only",
        name="Model A: session-only",
        description=(
            "Core pre-session context plus prior-session reflection tag indicators; "
            "no coach feedback or coach snapshot context."
        ),
        numeric_features=SESSION_NUMERIC_FEATURES + REFLECTION_TAG_FEATURES,
        categorical_features=SESSION_CATEGORICAL_FEATURES,
    ),
    FeatureSet(
        id="model_b_reflection_plus",
        name="Model B: reflection-plus",
        description=(
            "Model A plus aggregate prior reflection signal counts. Still no "
            "coach feedback or coach snapshot context."
        ),
        numeric_features=(
            SESSION_NUMERIC_FEATURES
            + REFLECTION_TAG_FEATURES
            + REFLECTION_AGGREGATE_FEATURES
        ),
        categorical_features=SESSION_CATEGORICAL_FEATURES,
    ),
    FeatureSet(
        id="model_c_coach_context",
        name="Model C: coach-context",
        description="Model B plus recent coach feedback and latest coach snapshot context.",
        numeric_features=(
            SESSION_NUMERIC_FEATURES
            + REFLECTION_TAG_FEATURES
            + REFLECTION_AGGREGATE_FEATURES
            + COACH_NUMERIC_FEATURES
        ),
        categorical_features=SESSION_CATEGORICAL_FEATURES + COACH_CATEGORICAL_FEATURES,
    ),
)


@dataclass(frozen=True)
class FeatureVectorizer:
    numeric_features: tuple[str, ...]
    categorical_values: dict[str, tuple[str, ...]]
    numeric_means: dict[str, float]
    numeric_scales: dict[str, float]
    feature_names: tuple[str, ...]

    @classmethod
    def fit(
        cls,
        rows: list[dict[str, Any]],
        *,
        numeric_features: tuple[str, ...] = NUMERIC_FEATURES,
        categorical_features: tuple[str, ...] = CATEGORICAL_FEATURES,
    ) -> "FeatureVectorizer":
        numeric_means: dict[str, float] = {}
        numeric_scales: dict[str, float] = {}

        for name in numeric_features:
            values = [_as_float(row.get(name, 0.0)) for row in rows]
            mean = sum(values) / len(values) if values else 0.0
            variance = (
                sum((value - mean) ** 2 for value in values) / len(values)
                if values
                else 0.0
            )
            scale = math.sqrt(variance)
            numeric_means[name] = mean
            numeric_scales[name] = scale if scale > 1e-9 else 1.0

        categorical_values: dict[str, tuple[str, ...]] = {}
        for name in categorical_features:
            hinted = CATEGORICAL_VALUE_HINTS.get(name)
            if hinted is not None:
                values = hinted
            else:
                values = tuple(sorted({str(row.get(name, "unknown")) for row in rows}))
            categorical_values[name] = values

        feature_names = list(numeric_features)
        for name in categorical_features:
            feature_names.extend(f"{name}={value}" for value in categorical_values[name])

        return cls(
            numeric_features=numeric_features,
            categorical_values=categorical_values,
            numeric_means=numeric_means,
            numeric_scales=numeric_scales,
            feature_names=tuple(feature_names),
        )

    def transform(self, rows: list[dict[str, Any]]) -> list[list[float]]:
        vectors: list[list[float]] = []

        for row in rows:
            vector: list[float] = []

            for name in self.numeric_features:
                value = _as_float(row.get(name, 0.0))
                mean = self.numeric_means[name]
                scale = self.numeric_scales[name]
                vector.append((value - mean) / scale)

            for name in self.categorical_values:
                row_value = str(row.get(name, "unknown"))
                for allowed_value in self.categorical_values[name]:
                    vector.append(1.0 if row_value == allowed_value else 0.0)

            vectors.append(vector)

        return vectors

    def to_metadata(self) -> dict[str, Any]:
        return {
            "numeric_features": [
                {
                    "name": name,
                    "mean": self.numeric_means[name],
                    "scale": self.numeric_scales[name],
                }
                for name in self.numeric_features
            ],
            "categorical_features": [
                {
                    "name": name,
                    "values": list(values),
                    "encoding": "one_hot",
                }
                for name, values in self.categorical_values.items()
            ],
            "feature_order": list(self.feature_names),
        }


def load_and_build_dataset(
    sessions_path: Path,
    feedback_path: Path | None = None,
    snapshots_path: Path | None = None,
    shadow_logs_path: Path | None = None,
) -> Dataset:
    sessions = _load_sessions(sessions_path)
    feedback = _load_jsonl(feedback_path) if feedback_path and feedback_path.exists() else []
    snapshots = _load_jsonl(snapshots_path) if snapshots_path and snapshots_path.exists() else []
    shadow_logs = (
        _load_jsonl(shadow_logs_path)
        if shadow_logs_path and shadow_logs_path.exists()
        else []
    )

    rows, labels = build_feature_rows(
        sessions=sessions,
        feedback_entries=feedback,
        snapshots=snapshots,
    )

    successes = sum(labels)
    categories = sorted({row["category"] for row in rows})
    summary = {
        "num_sessions": len(sessions),
        "num_rows": len(rows),
        "num_feedback_entries": len(feedback),
        "num_snapshots": len(snapshots),
        "num_shadow_prediction_entries": len(shadow_logs),
        "success_count": successes,
        "failure_count": len(labels) - successes,
        "success_rate": successes / len(labels) if labels else 0.0,
        "categories": categories,
        "source_files": {
            "sessions": str(sessions_path),
            "coach_feedback": str(feedback_path) if feedback_path else None,
            "coach_snapshots": str(snapshots_path) if snapshots_path else None,
            "shadow_predictions": str(shadow_logs_path) if shadow_logs_path else None,
        },
    }

    return Dataset(rows=rows, labels=labels, summary=summary)


def build_feature_rows(
    sessions: list[dict[str, Any]],
    feedback_entries: list[dict[str, Any]],
    snapshots: list[dict[str, Any]],
) -> tuple[list[dict[str, Any]], list[int]]:
    sorted_sessions = sorted(sessions, key=lambda row: _as_int(row["started_at_ms"]))
    sorted_feedback = sorted(feedback_entries, key=lambda row: _as_int(row["createdAt"]))
    sorted_snapshots = sorted(snapshots, key=lambda row: _as_int(row["createdAt"]))

    rows: list[dict[str, Any]] = []
    labels: list[int] = []

    for index, session in enumerate(sorted_sessions):
        started_at_ms = _as_int(session["started_at_ms"])
        prior_sessions = sorted_sessions[:index]
        category = str(session.get("category", "unknown"))
        prior_category_sessions = [
            item for item in prior_sessions if str(item.get("category", "unknown")) == category
        ]

        recent_sessions = prior_sessions[-ROLLING_SESSION_COUNT:]
        recent_category_sessions = prior_category_sessions[-ROLLING_SESSION_COUNT:]
        recent_feedback = _recent_feedback(sorted_feedback, started_at_ms)
        latest_snapshot = _latest_snapshot(sorted_snapshots, started_at_ms)

        started_at = datetime.fromtimestamp(started_at_ms / 1000, tz=timezone.utc)
        duration_minutes = _as_float(session.get("duration_seconds", 0.0)) / 60.0

        current_success_streak, current_failure_streak = _current_streaks(prior_sessions)
        signed_streak = (
            current_success_streak if current_success_streak > 0 else -current_failure_streak
        )

        recent_tags = _recent_reflection_tags(recent_sessions)
        positive_tags = {"flow", "quiet"}
        distraction_tags = {"low_energy", "phone", "interruption", "unclear"}
        coach_duration_delta = 0.0
        coach_same_category = 0.0
        coach_message_type = "none"
        coach_confidence_label = "none"
        if latest_snapshot is not None:
            recommended_category = str(latest_snapshot.get("recommendedCategory", ""))
            recommended_duration = _as_float(
                latest_snapshot.get("recommendedDurationMinutes", duration_minutes)
            )
            coach_same_category = 1.0 if recommended_category == category else 0.0
            coach_duration_delta = duration_minutes - recommended_duration
            coach_message_type = str(latest_snapshot.get("coachMessageType", "none"))
            coach_confidence_label = str(latest_snapshot.get("confidenceLabel", "none"))

        row = {
            "session_id": str(session.get("session_id", "")),
            "category": category,
            "time_block": _time_block(started_at.hour),
            "day_of_week": _day_of_week_name(started_at.weekday()),
            "duration_bucket": _duration_bucket(duration_minutes),
            "duration_minutes": duration_minutes,
            "recent_success_rate": _success_rate(recent_sessions, default=0.5),
            "recent_session_count": min(len(recent_sessions), ROLLING_SESSION_COUNT),
            "recent_category_success_rate": _success_rate(
                recent_category_sessions,
                default=0.5,
            ),
            "recent_category_session_count": min(
                len(recent_category_sessions),
                ROLLING_SESSION_COUNT,
            ),
            "current_streak": signed_streak,
            "current_success_streak": current_success_streak,
            "current_failure_streak": current_failure_streak,
            "recent_coach_helpful_rate": _coach_helpful_rate(recent_feedback),
            "recent_coach_feedback_count": min(len(recent_feedback), ROLLING_SESSION_COUNT),
            "coach_recommended_same_category": coach_same_category,
            "coach_recommended_duration_delta_minutes": coach_duration_delta,
            "latest_coach_message_type": coach_message_type,
            "latest_coach_confidence_label": coach_confidence_label,
            "recent_reflection_tag_count": len(recent_tags),
            "recent_positive_reflection_tag_count": len(recent_tags & positive_tags),
            "recent_distraction_reflection_tag_count": len(recent_tags & distraction_tags),
        }

        for tag in REFLECTION_TAG_KEYWORDS:
            row[f"recent_tag_{tag}"] = 1.0 if tag in recent_tags else 0.0

        rows.append(row)
        labels.append(1 if str(session.get("outcome", "")).lower() == "yes" else 0)

    return rows, labels


def train_test_split_chronological(
    rows: list[dict[str, Any]],
    labels: list[int],
    test_fraction: float = 0.2,
) -> tuple[list[dict[str, Any]], list[int], list[dict[str, Any]], list[int]]:
    if len(rows) != len(labels):
        raise ValueError("rows and labels must have the same length")
    if len(rows) < 5:
        raise ValueError("need at least five rows for a useful train/test split")

    test_count = max(1, int(round(len(rows) * test_fraction)))
    train_count = len(rows) - test_count
    if train_count <= 0:
        raise ValueError("test_fraction leaves no training rows")

    return (
        rows[:train_count],
        labels[:train_count],
        rows[train_count:],
        labels[train_count:],
    )


def _load_sessions(path: Path) -> list[dict[str, Any]]:
    if path.suffix == ".jsonl":
        return _load_jsonl(path)

    with path.open("r", encoding="utf-8", newline="") as file:
        return [dict(row) for row in csv.DictReader(file)]


def _load_jsonl(path: Path | None) -> list[dict[str, Any]]:
    if path is None:
        return []

    rows: list[dict[str, Any]] = []
    with path.open("r", encoding="utf-8") as file:
        for line in file:
            stripped = line.strip()
            if not stripped:
                continue
            rows.append(json.loads(stripped))
    return rows


def _recent_feedback(
    feedback_entries: list[dict[str, Any]],
    started_at_ms: int,
) -> list[dict[str, Any]]:
    window_ms = ROLLING_FEEDBACK_DAYS * 24 * 60 * 60 * 1000
    lower_bound = started_at_ms - window_ms
    return [
        row
        for row in feedback_entries
        if lower_bound <= _as_int(row.get("createdAt", 0)) < started_at_ms
    ]


def _latest_snapshot(
    snapshots: list[dict[str, Any]],
    started_at_ms: int,
) -> dict[str, Any] | None:
    window_ms = LATEST_SNAPSHOT_WINDOW_HOURS * 60 * 60 * 1000
    lower_bound = started_at_ms - window_ms
    candidates = [
        row
        for row in snapshots
        if lower_bound <= _as_int(row.get("createdAt", 0)) <= started_at_ms
    ]
    return candidates[-1] if candidates else None


def _success_rate(rows: list[dict[str, Any]], default: float) -> float:
    if not rows:
        return default
    yes_count = sum(1 for row in rows if str(row.get("outcome", "")).lower() == "yes")
    return yes_count / len(rows)


def _current_streaks(prior_sessions: list[dict[str, Any]]) -> tuple[int, int]:
    if not prior_sessions:
        return 0, 0

    last_success = str(prior_sessions[-1].get("outcome", "")).lower() == "yes"
    streak = 0
    for row in reversed(prior_sessions):
        is_success = str(row.get("outcome", "")).lower() == "yes"
        if is_success != last_success:
            break
        streak += 1

    if last_success:
        return streak, 0
    return 0, streak


def _recent_reflection_tags(recent_sessions: list[dict[str, Any]]) -> set[str]:
    tags: set[str] = set()
    for row in recent_sessions:
        reflection = str(row.get("reflection", "")).lower()
        for tag, keywords in REFLECTION_TAG_KEYWORDS.items():
            if any(keyword in reflection for keyword in keywords):
                tags.add(tag)
    return tags


def _coach_helpful_rate(feedback_entries: list[dict[str, Any]]) -> float:
    if not feedback_entries:
        return 0.5
    helpful = sum(1 for row in feedback_entries if bool(row.get("wasHelpful")))
    return helpful / len(feedback_entries)


def _time_block(hour: int) -> str:
    if 5 <= hour < 12:
        return "morning"
    if 12 <= hour < 17:
        return "afternoon"
    if 17 <= hour < 21:
        return "evening"
    return "night"


def _day_of_week_name(weekday: int) -> str:
    names = (
        "monday",
        "tuesday",
        "wednesday",
        "thursday",
        "friday",
        "saturday",
        "sunday",
    )
    return names[weekday]


def _duration_bucket(duration_minutes: float) -> str:
    if duration_minutes <= 15:
        return "short"
    if duration_minutes <= 30:
        return "standard"
    if duration_minutes <= 45:
        return "long"
    return "extended"


def _as_float(value: Any) -> float:
    try:
        if value is None or value == "":
            return 0.0
        return float(value)
    except (TypeError, ValueError):
        return 0.0


def _as_int(value: Any) -> int:
    try:
        if value is None or value == "":
            return 0
        return int(value)
    except (TypeError, ValueError):
        return 0
