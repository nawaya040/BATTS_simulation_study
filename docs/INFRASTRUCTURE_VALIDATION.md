# Infrastructure validation — 2026-10-01

## Environment and identity

Validation used Windows x86_64, R 4.5.2, GCC 14.3/Rtools45, BATTS 0.2.0 at
`c4d194336bd0610372fe8d1b08caa7f94a7cd168`, and the submitted modified
densratio 0.2.1 installed from this repository's vendor source. Other observed
versions included ada 2.0.5, rpart 4.1.24, mvtnorm 1.3.3, Rcpp 1.1.1.1 and
RcppArmadillo 14.4.1.1. The fresh study library and each worker verified the
same installed-file fingerprints.

The tested working tree was based on `65e43e15fff25ae7c134d9fb3c141e95bf8680a9`.
The run accurately records that base commit and a dirty working tree, with the
exact modified/new source bytes in `INFRASTRUCTURE_TESTED_SOURCES.csv`.
These file hashes identify the implementation tested before its infrastructure
commit. No artificial replacement commit or RemoteSha was injected.

## Results

- Full smoke grid: **160/160 jobs completed**, covering 1D BAT, four fixed-tree
  1D Ada/GB pairs, 2D scenarios and all 20D scenarios/transforms/sample balances.
  Four PSOCK workers took about **40–45 seconds** from run creation to the last
  job; initial environment compilation was separate. No fitting warnings or
  nonfinite MSE were observed in these smoke results.
- The paper dry-run enumerated **8,100 jobs** without executing them.
- **29 infrastructure checks passed** (`tests/infrastructure.R`). Tests cover
  body/checksum validation, orphan RDS/manifest rejection, changed metrics and
  posterior quantiles, input identity, full-plan completeness, immutable saves,
  exact resume, partial selection expansion, source/worker/environment/source-pin
  mismatches, canonical acknowledgement, and finite-only MCSE.
- The latent generator's added fields leave original observations, truth and
  final RNG state exactly unchanged in both latent scenarios and transforms.
- 1D and 2D BAT draws exactly match direct package calls on the same inputs and
  RNG states. GB/FS/Ada reruns match estimates and final RNG states exactly.
- Streamed validation produces the same numerical summaries as retained-draw
  validation. A synthetic fixture exercises compact storage of non-detail seeds
  and localization summaries without keeping their posterior arrays in memory.
- Aggregation generated MSE, coverage, localization and job-diagnostic CSVs,
  missing-job records and a 56-page diagnostic PDF. Representative pages were
  rendered and inspected; smoke labels appear on each page. The final summary
  manifest links input results, plotting source and output hashes.
- All repository R sources parse; `git diff --check` passes.

## Repeating the checks

Use fresh output directories and a prepared library, from the repository root:

```text
Rscript scripts/run_study.R --profile=smoke --workers=4 --r-lib=.Rlib --output-dir=output/full-smoke
Rscript tests/infrastructure.R --run-dir=output/full-smoke --r-lib=.Rlib --output-dir=output/infrastructure-tests
Rscript scripts/summarize_study.R --run-dir=output/full-smoke --require-complete=true --output-dir=output/smoke-summary
```

The test script mutates only copies beneath its fresh test directory. It also
resumes the real smoke run to prove unchanged result bytes, appending progress
events. Do not change source/commit/environment between the initial smoke run
and its resume tests.

## Limits

These checks establish operation on reduced datasets. They do not establish
MCMC convergence, paper-scale runtime/memory, equality with old published
numbers, or full reproducibility on another machine. No paper-scale job or
official result directory was run or overwritten. Full timing should be
estimated from an approved representative paper-scale job, rather than scaling
the smoke duration by the number of jobs. Manuscript-specific layouts and the
final journal reproduction archive remain separate work.
