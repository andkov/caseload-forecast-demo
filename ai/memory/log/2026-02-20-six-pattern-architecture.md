# 6-Pattern Pipeline Architecture

**Date**: 2026-02-20  
**Scope**: Project-wide documentation and configuration restructuring  
**Trigger**: Human request to formalize pipeline stages beyond Ferry/Ellis, especially for forecasting workflows

---

## Summary

Restructured the project pipeline from an ad-hoc sequence into a formal **6-pattern architecture** with clear contracts between stages:

```
Ferry (1) → Ellis (2) → [EDA] → Mint (3) → Train (4) → Forecast (5) → Report (6)
                          ↕
                      (advisory)
```

## New Concepts Introduced

### Mint Pattern (Stage 3)
- **Named for**: Coin minting — producing standardized artifacts of exact specification
- **Purpose**: Shape Ellis output into model-ready data slices consumed identically by all Train lanes
- **Codifies EDA decisions**: Each transform references an EDA finding (e.g., `[EDA-001] Log transform: TRUE`)
- **Output**: `./data-private/derived/forge/` containing `.rds` ts objects, xreg matrices, and `forge_manifest.yml`
- **Forbidden**: Model fitting, new data sourcing, re-running Ellis logic

### EDA Reclassified as Advisory
- EDA is no longer a numbered pipeline stage
- It operates on Ellis output and produces reports/insight, not data artifacts
- Its findings are codified as documented decisions in Mint scripts
- EDA scripts remain outside `flow.R` (run ad-hoc by analysts)

### Mint-Train-Forecast Lineage
- These three patterns form a **versioned chain** keyed by `focal_date`
- Changing `focal_date` invalidates all downstream artifacts
- `forge_manifest.yml` provides the hash linking model registry entries to their exact input data
- Minimum viable versioning for Phase 1; transitions to Azure ML model registry in Phase 2

### Lane Definition Expanded
- A lane may now be implemented as **a single script or a group of scripts** operating within the same pattern
- Full naming convention: `{n}-ferry-{source}.R`, `{n}-ellis-{entity}.R`, `{n}-mint-{target}.R`, `{n}-train-{model}.R`, `{n}-forecast-{target}.R`, `{n}-report-{target}.qmd`

## Files Modified

| File | Change |
|------|--------|
| `ai/project/glossary.md` | Added Mint, Train, Forecast, Report, EDA definitions; expanded Pattern/Lane; added Forge Manifest and Lineage sections |
| `ai/project/method.md` | Renamed pipeline; inserted EDA advisory + Mint §3; updated Train §4 to consume Mint; added Lineage section |
| `ai/project/mission.md` | Updated pipeline sequence and completeness metric |
| `flow.R` | Restructured `ds_rail` into 6 phases with commented placeholders for Mint/Train/Forecast/Report |
| `config.yml` | Added `focal_date`, `backtest_months`, `use_log_transform`, `seasonal_period`, `forecast_horizon`, `random_seed`; added `forge`/`models` directory paths; renamed project |
| `manipulation/README.md` | Added Mint pattern philosophy section; expanded Quick Reference to 3 patterns; added 6-pattern naming convention |
| `manipulation/pipeline.md` | Updated visual diagram to 6 patterns with EDA lateral; updated lane naming table; updated `ds_rail` example |
| `analysis/eda-2/README.md` | Reframed "Next Steps" around Mint lane with `[EDA-001]`–`[EDA-005]` decision codes |
| `ai/personas/data-engineer.md` | Added 6-pattern pipeline reference |
| `.vscode/tasks.json` | Added task stubs for Mint Lane 3, Train Lane 4, Forecast Lane 5 |

## Design Decisions

1. **"Mint" over "Forge"/"Prepare"**: Metaphor consistency with Ferry/Ellis tradition (place/process names); brevity in filenames (`3-mint-IS.R`)
2. **Output directory named "forge"**: The artifact type is "forged data contract"; the pattern is "Mint". Parallels how Ellis produces CACHE-manifest (manifest describes storage layer, not pattern)
3. **EDA not numbered**: Avoids forcing ad-hoc exploratory work into deterministic `ds_rail` execution
4. **Train consumes Mint only**: Prevents train/test leakage by centralizing split logic in one place
5. **`forge_manifest.yml` as versioning anchor**: Lightweight alternative to full MLflow before Phase 2 Azure migration

## What's Next

- Implement `manipulation/3-mint-IS.R` (first Mint lane)
- Implement `manipulation/4-train-IS.R` (model estimation across 4 tiers)
- Implement `manipulation/5-forecast-IS.R` (24-month horizon predictions)
- Create `analysis/report-1/report-1.qmd` (combined deliverable)
- Regenerate `.github/copilot-instructions.md` via persona activation task
