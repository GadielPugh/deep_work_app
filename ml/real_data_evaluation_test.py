from __future__ import annotations

import json
import subprocess
import sys
import tempfile
import unittest
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent))

from evaluate_model import threshold_sweep
from train_model import analyze_shadow_logs


PROJECT_ROOT = Path(__file__).resolve().parents[1]


class RealDataEvaluationTest(unittest.TestCase):
    def test_real_export_directory_generates_evaluation_report(self) -> None:
        with tempfile.TemporaryDirectory() as data_dir_raw, tempfile.TemporaryDirectory() as out_dir_raw:
            data_dir = Path(data_dir_raw)
            out_dir = Path(out_dir_raw)
            _write_jsonl(data_dir / "sessions.jsonl", _session_rows())
            _write_jsonl(data_dir / "coach_feedback.jsonl", _feedback_rows())
            _write_jsonl(data_dir / "coach_snapshots.jsonl", _snapshot_rows())
            _write_jsonl(data_dir / "shadow_predictions.jsonl", _shadow_rows())

            subprocess.run(
                [
                    sys.executable,
                    str(PROJECT_ROOT / "ml" / "train_model.py"),
                    "--data-dir",
                    str(data_dir),
                    "--output-dir",
                    str(out_dir),
                    "--epochs",
                    "50",
                    "--test-fraction",
                    "0.34",
                    "--real-data-eval",
                ],
                cwd=PROJECT_ROOT,
                check=True,
                capture_output=True,
                text=True,
            )

            report_path = out_dir / "real_data_evaluation_report.json"
            model_path = out_dir / "session_success_model.json"
            self.assertTrue(report_path.exists())
            self.assertTrue(model_path.exists())

            report = json.loads(report_path.read_text(encoding="utf-8"))
            self.assertEqual(report["dataset"]["dataset_kind"], "real")
            self.assertEqual(report["dataset"]["num_rows"], 8)
            self.assertIn("model_a_session_only", report["models"])
            self.assertIn("thresholds_tried", report["models"]["model_a_session_only"]["threshold_tuning"])
            self.assertIn("chosen_threshold", report["chosen_model"])
            self.assertEqual(report["shadow_log_analysis"]["resolved_rows"], 4)
            self.assertEqual(report["shadow_log_analysis"]["unresolved_rows"], 1)
            self.assertEqual(report["recommendation"]["decision"], "not_enough_data")

    def test_threshold_sweep_handles_tiny_dataset(self) -> None:
        result = threshold_sweep([1], [0.2], thresholds=[0.1, 0.5, 0.9])

        self.assertEqual(len(result["thresholds_tried"]), 3)
        self.assertIn("best_threshold_by_f1", result)
        self.assertIn("best_threshold_by_balanced_usefulness", result)

    def test_shadow_analysis_handles_missing_outcome_rows(self) -> None:
        with tempfile.TemporaryDirectory() as data_dir_raw:
            path = Path(data_dir_raw) / "shadow_predictions.jsonl"
            _write_jsonl(
                path,
                [
                    {"mlSuccessProbability": 0.7, "laterSessionSucceeded": True},
                    {"mlSuccessProbability": 0.4, "laterSessionSucceeded": False},
                    {"mlSuccessProbability": 0.8},
                    {"laterSessionSucceeded": True},
                ],
            )

            analysis = analyze_shadow_logs(path)

            self.assertEqual(analysis["resolved_rows"], 2)
            self.assertEqual(analysis["unresolved_rows"], 1)
            self.assertEqual(analysis["invalid_probability_rows"], 1)
            self.assertAlmostEqual(analysis["avg_probability_before_success"], 0.7)
            self.assertAlmostEqual(analysis["avg_probability_before_failure"], 0.4)


def _write_jsonl(path: Path, rows: list[dict[str, object]]) -> None:
    with path.open("w", encoding="utf-8") as file:
        for row in rows:
            file.write(json.dumps(row))
            file.write("\n")


def _session_rows() -> list[dict[str, object]]:
    base = 1767265800000
    outcomes = ["yes", "no", "yes", "partially", "yes", "no", "yes", "no"]
    categories = ["Coding", "Writing", "Coding", "Reading", "Coding", "Study", "Writing", "Coding"]
    rows: list[dict[str, object]] = []
    for index, outcome in enumerate(outcomes):
        started = base + index * 86_400_000
        rows.append(
            {
                "session_id": str(index + 1),
                "intention": f"Session {index + 1}",
                "category": categories[index],
                "started_at_ms": started,
                "stopped_at_ms": started + 1_500_000,
                "duration_seconds": 1500,
                "outcome": outcome,
                "reflection": "good flow" if outcome == "yes" else "phone distraction",
                "created_at_ms": started + 1_600_000,
            }
        )
    return rows


def _feedback_rows() -> list[dict[str, object]]:
    return [
        {
            "id": "feedback_1",
            "createdAt": 1767265000000,
            "coachMessageType": "positive",
            "recommendedCategory": "Coding",
            "recommendedDurationMinutes": 25,
            "confidenceLabel": "medium",
            "wasHelpful": True,
            "optionalReason": None,
        }
    ]


def _snapshot_rows() -> list[dict[str, object]]:
    return [
        {
            "createdAt": 1767265000000,
            "title": "Coach",
            "body": "Try Coding.",
            "actionText": "Try 25 min of Coding",
            "coachMessageType": "positive",
            "confidenceLabel": "medium",
            "recommendedCategory": "Coding",
            "recommendedDurationMinutes": 25,
            "betterLaterHint": None,
        }
    ]


def _shadow_rows() -> list[dict[str, object]]:
    return [
        {"createdAt": 1, "mlSuccessProbability": 0.8, "laterSessionSucceeded": True},
        {"createdAt": 2, "mlSuccessProbability": 0.3, "laterSessionSucceeded": False},
        {"createdAt": 3, "mlSuccessProbability": 0.7, "laterSessionSucceeded": True},
        {"createdAt": 4, "mlSuccessProbability": 0.4, "laterSessionSucceeded": False},
        {"createdAt": 5, "mlSuccessProbability": 0.6},
    ]


if __name__ == "__main__":
    unittest.main()
