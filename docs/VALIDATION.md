# Import validation, 2026-10-01

Tested source commit: `f3fbfd1e80d65c121d208aaa6ec089b71f962e68`.
Later documentation updates do not modify the tested scientific source.

## Checks completed

- All 41 imported files match their source SHA-256 in SOURCE_MANIFEST.csv.
- All 35 R files parse; the PowerShell phase launcher also parses.
- The imported scripts contain no hard-coded user/Dropbox paths or `setwd()`.
- BAT coverage smoke runs passed for 1D, 2D local shift and the latent-20D
  workflow, seed 1. Each used 80 observations per group, 20 trees, 20 burn-in
  iterations and 40 saved draws. The latent-20D smoke mode reduces dimension
  to 5; no claim about a full 20D fit follows from this test.
- The 2D local-shift boosting smoke run passed, seed 1, 80 observations per
  group, two folds and at most 60 trees. GB selected 33 trees and FS 45.
  GB/FS and AdaBoost metric records contain no non-finite estimates.
- All four output hashes match their sidecar manifests and are labelled
  `SMOKE_NOT_FOR_PAPER`. Coverage values are finite and in [0,1]; interval
  probabilities are symmetric to within 1e-12.
- Repeating the 2D coverage job without resume refuses overwrite. Explicit
  resume verifies the existing result and skips it.

All run outputs were written to an isolated verification directory outside
this repository. Generated RDS files, installed libraries and machine-specific
logs are not published.

## Environment

Windows; R 4.5.2; Rtools45/GCC 14.3.0; BATTS 0.1.0 compiled with C++17.
The isolated BATTS installation's scientific source was verified against
release `ceb5fb6bb0045ab6b72f2a91c620a0b3c5bba3b0` during release validation.

| Package | Version |
| --- | --- |
| Rcpp | 1.1.1.1 |
| RcppArmadillo | 14.4.1.1 |
| mvtnorm | 1.3.3 |
| pracma | 2.4.4 |
| ada | 2.0.5 |
| rpart | 4.1.24 |
| digest | 0.6.37 |
| matrixStats | 1.5.0 |
| ggplot2 | 4.0.0 |
| patchwork | 1.3.0 |

## Limits

This validates source transfer, parsing and selected integration paths.
It does not establish independent scientific review, full paper reproduction,
convergence, or compatibility of every historical workflow with BATTS 0.1.0.
Global/null 20D workflows retain their old-version guard and were not run.
Plotting, kernel and CDC workflows were parsed but not executed. The journal
submission scripts were not recreated. See MIGRATION_STATUS.md for the known
work before full computation.
