# Initial import and remaining work

## Source baseline

The initial import copies 41 files without changing their bytes from the
research checkout at commit `aee3eb5` in
[nawaya040/BATTS](https://github.com/nawaya040/BATTS/tree/aee3eb5).
The full commit, source path, destination and SHA-256 for each file are recorded
in [SOURCE_MANIFEST.csv](SOURCE_MANIFEST.csv). This historical checkout has a
different purpose from the current BATTS package default branch.

The initial import preserves estimator calls, settings, data generators,
evaluation rules and RNG behavior. The target dependency for new runs is BATTS
v0.1.0 at `ceb5fb6bb0045ab6b72f2a91c620a0b3c5bba3b0`.

## Readiness

| Workflow | Import status | Remaining work |
| --- | --- | --- |
| 1D/2D/latent-20D BAT coverage | Source and generators present; reduced tests listed in VALIDATION.md | Review full-run settings and output coverage; these runners primarily save coverage summaries, not every posterior surface needed by the figures |
| 2D/latent-20D GB, FS, Ada DRT | Source and generators present; reduced tests listed in VALIDATION.md | Review selection criteria and comparator controls before new canonical runs |
| 20D global-shift/null BAT and comparator workflows | Source present with original contract | Update old BATTS identity guards and historical metadata; review library propagation and resume contracts |
| Revision table summaries | Source present | Some cells use external historical RDS inputs; this is not yet a fresh all-methods rerun pipeline |
| Figures | Portable subset present | Four older plotting scripts need approved path migration; complete figure coverage is pending |
| 2D/latent-20D kernel and CDC reruns | Some historical results are consumed by summaries | Establish dedicated, current run entry points and settle CDC specification before claiming a complete simulation pipeline |

### Old version constraints to resolve

The new-run guard now pins BATTS 0.2.0 at `c4d194336bd0610372fe8d1b08caa7f94a7cd168`.
`assert_batts_version()` checks `RemoteSha`; the pilot and canonical BAT
runners use this check. Historical result readers still contain the old
identity `6f625bad83702b36e5480be1ed1343258a9b075a`:

- `plot_unbalanced_calibration_curve.R`
- `summarize_20d_global_null_canonical.R`
- `summarize_20d_global_shift_pilot.R`

Do not replace historical result labels blindly: distinguish validation of old
inputs from the identity required for newly generated outputs. Adding uniform version enforcement and updating readers for newly generated
results remain part of the planned simulation infrastructure work. The API
migration removes deleted arguments from all BAT calls; historical result
metadata remains unchanged.

### Intentionally not imported

The following source files have machine-specific input defaults and need path
migration before they belong in the portable simulation workflow:

- `scripts/figures/plot_figure3_r2_preview.R`
- `scripts/figures/plot_figure4_r2_preview.R`
- `scripts/figures/plot_supplement_s1_r2_preview.R`
- `scripts/figures/plot_supplement_s2_s3_r2_preview.R`

Their source remains available at the baseline commit. The manuscript plan,
legacy `Experiments/` scripts with machine-specific paths, package source,
case-study data, and generated results were also excluded. The submitted
reproduction wrappers and journal archive are outside this task.

## Scientific decisions still open

The coauthor-shared audit recommends changes to CDC calibration, comparator
complexity checks, a probit-BART DRT baseline and prior-sensitivity analyses.
Their inclusion is not decided by this import. Preserve existing implementations
as the review baseline and obtain author approval for any scientific change.

## Rollback and provenance

The original checkout and official results remain unchanged. The first source
import commit in this repository is the migration baseline. Future patches
must update the status here and keep their provenance distinct from the
unchanged source import.


## Post-import scientific changes

AdaBoost fold losses are now averaged arithmetically using log-sum-exp
(independent audit U13; author approved). The fixed-seed balanced/unbalanced
2D comparison and exact commits are documented in
[paired validation](ADABOOST_CV_ARITHMETIC_VALIDATION.md). The original
SOURCE_MANIFEST remains a record of the unchanged initial import.
