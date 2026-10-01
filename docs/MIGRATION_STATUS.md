# Simulation infrastructure status

The supported workflow is now `run_study.R` -> `validate_results.R` ->
`summarize_study.R`. It covers 1D BAT, the fixed 1D Ada/GB comparison,
2D and 20D methods through one execution, saving, resume and aggregation contract.

## Implemented

- Separate smoke/paper configurations, explicit selected-job filters and dry-run;
  canonical acknowledgement and clean-source checks.
- Exact BATTS source pin, vendored submitted densratio, installed dependency
  fingerprints and verification in each worker.
- One cached input dataset per case, source/configuration/environment identities,
  atomic per-job saves, checksums and immutable result bodies.
- Resume checks covering result contents, input hashes and CDC dependencies;
  explicit errors for partial/corrupt pairs and changed run identities.
- BAT posterior draws, temperature draws, seed-1 forests/grids, latent loadings;
  all comparator estimates, selection diagnostics, timing, warnings and RNG state.
- Fresh-output aggregation, missing/nonfinite counts, finite-only MCSE,
  coverage/localization tables and diagnostic figures from saved results.

Read [validation evidence](INFRASTRUCTURE_VALIDATION.md) and
[the study contract](STUDY_CONTRACT.md) before scheduling paper runs.
Reduced runs establish operational behavior; they do not establish convergence,
paper-scale memory requirements or the final paper numbers.

## Historical sources

The first import copied 41 source files from research commit `aee3eb5`;
`SOURCE_MANIFEST.csv` remains the unchanged record of that import.
The previous status document is preserved as `HISTORICAL_IMPORT_STATUS.md`.
Historical entry points and readers retain their original output contracts and
version labels. They are reference material; use the new root-level entry
points for new computations. Their standalone completion checks must not be
used to certify new results.

AdaBoost arithmetic-loss CV, 1D MCMC settings and BATTS 0.2.0 API/safeguard
changes were approved separately. This infrastructure adds metadata fields and
uses the submitted modified kernel package. It preserves the current CDC
submitted/stable variants. Probit BART, new prior sensitivity experiments and
replacement CDC estimators have not been introduced.

## Subsequent work

Freeze/review the exact code and environment, obtain coauthor confirmation and
schedule the approved paper computations. Final manuscript layouts and the
journal submission archive are deferred as requested. Some older figure scripts
consume historical RDS formats; the new saved objects supply the data for a
later manuscript-specific export without refitting. Standalone illustrations
with different seeds/sample sizes must keep their own documented settings.

No official results, manuscript source, case-study repository or BATTS package
source are changed by this infrastructure patch. Rollback is a checkout of the
pre-infrastructure simulation commit; retain all existing output roots separately.
