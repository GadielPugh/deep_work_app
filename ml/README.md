# Deep Work ML Pipeline

This folder contains the first practical, synthetic-data ML pipeline for session
success prediction. It is intentionally small: no app UI changes, no coach-card
changes, and no LiteRT dependency.

## Data

Default inputs are read from `lib/models/ml/data/`:

- `synthetic_sessions.csv` is the primary dataset.
- `synthetic_coach_feedback.jsonl` is optional prior feedback signal.
- `synthetic_coach_snapshots.jsonl` is optional prior coach context.

If `/mnt/data/deep_work_synthetic_ml/` exists, `train_model.py` uses that
mounted data directory by default. Otherwise it falls back to the repo-local
copies under `lib/models/ml/data/`.

The target is `session_success`:

- `outcome == yes` => `1`
- anything else => `0`

## Feature Variants

The trainer evaluates three logistic-regression variants side by side:

- Model A, `model_a_session_only`: category, time block, day of week,
  duration bucket, recent success rate, recent category success rate, streak,
  and prior-session reflection tag indicators.
- Model B, `model_b_reflection_plus`: Model A plus aggregate prior reflection
  signal counts.
- Model C, `model_c_coach_context`: Model B plus recent coach feedback and the
  latest prior coach snapshot context.

Reflection tags and coach context are time-aware. The current session's
reflection is not used as a same-row feature, which keeps the training setup
closer to a pre-session predictor.

## Run

```bash
python3 ml/train_model.py
python3 ml/inference_smoke_test.py
```

To train on a real app export created by `LocalMlExportService`:

```bash
python3 ml/train_model.py --data-dir /path/to/deep_work_ml_export_YYYYMMDD... --real-data-eval
python3 ml/inference_smoke_test.py
```

Outputs:

- `ml/artifacts/session_success_model.json`
- `ml/artifacts/session_success_metrics.json`
- `ml/artifacts/feature_audit_report.json`
- `ml/artifacts/real_data_evaluation_report.json` when `--real-data-eval` is used

The exported model is a JSON logistic regression artifact with coefficients,
feature order, numeric scaling metadata, categorical one-hot metadata, the
classification threshold, metrics, data summary, and selected variant metadata.

The export selector prefers the simplest clean model that performs reasonably
well. If coach-context features dominate Model C, Model C is rejected even when
its metrics are stronger.

## Real App Export

The Flutter app exposes a dev hook, not a UI flow:

```dart
final result = await AppServices.exportMlTrainingDataForDebug();
print(result.directory.path);
```

That writes:

- `manifest.json`
- `sessions.jsonl`
- `coach_feedback.jsonl`
- `coach_snapshots.jsonl`
- `shadow_predictions.jsonl`

The JSONL files use millisecond UTC timestamps and field names compatible with
the training pipeline. Shadow prediction logs are exported for validation and
calibration analysis; they are not currently used as training features.

The real-data evaluation report includes class balance, split counts, Model A/B/C
metrics, baseline comparisons, threshold sweeps, selected threshold, and
shadow-log calibration summaries when resolved shadow outcomes exist.

## Caveat

The synthetic data is highly separable. If metrics look perfect, treat that as a
pipeline proof, not proof that the model is production-ready. In this dataset,
recent coach snapshot fields are especially strong signals, so the next step
should be validating the same pipeline against real local history before
replacing or heavily weighting app heuristics.
