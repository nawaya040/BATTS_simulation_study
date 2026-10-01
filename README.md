# BATTS simulation study

Simulation code for *Two-sample Comparison through Additive Tree Models for
Density Ratios*. The supported entry point is `scripts/run_study.R`.
It runs selected jobs, saves each job independently, and resumes only verified
results from the same code, configuration and environment.

The package is maintained separately at [nawaya040/BATTS](https://github.com/nawaya040/BATTS).
This workflow pins BATTS **0.2.0**, commit
`c4d194336bd0610372fe8d1b08caa7f94a7cd168`, and the submitted modified
`densratio` source under `vendor/`. Case-study work remains in
[yuliangxu/TwoSample](https://github.com/yuliangxu/TwoSample).

## Prepare an environment

Use R 4.5 or later and a C++17 compiler (Rtools45 on Windows with R 4.5).
Install prerequisites in your ordinary R library if needed:

```r
install.packages(c("remotes", "Rcpp", "RcppArmadillo", "ada", "rpart",
                   "mvtnorm", "pracma", "digest", "matrixStats"))
```

From the repository root, create a **new, empty** study library:

```text
Rscript scripts/prepare_environment.R --install=true --r-lib=.Rlib
```

For an offline BATTS source build, add `--batts-source=/path/to/BATTS` pointing
to a clean checkout of the exact pinned commit. The bootstrap installs BATTS
and vendored densratio, then records R, OS, compiler, dependency versions and
installed-file hashes in `.Rlib/study-environment.rds`. Other dependencies are
resolved from the inherited R library paths and fingerprinted recursively.
Workers must resolve the same files. Changes to this environment require a new
run directory. This is a checked local environment receipt; preserve the
working libraries or package archives to rebuild the same binaries later.

## Inspect and run

```text
Rscript scripts/run_study.R --dry-run=true
Rscript scripts/run_study.R --profile=paper --dry-run=true
Rscript scripts/run_study.R --profile=smoke --family=2d --scenario=local_shift --balance=balanced --methods=bat,gb,fs,ada --workers=2 --r-lib=.Rlib --output-dir=output/smoke-local
```

The default profile is `smoke`. With no filters, smoke runs **160 jobs** across
all supported settings. Paper settings enumerate **8,100 jobs**, including
the fixed-tree 1D comparison. Both use 20 coordinates in the 20D scenarios.
`--dry-run=true` prints the plan without installing packages or producing results.

Filters accept comma-separated `--family`, `--scenario`, `--methods`,
`--seeds` and `--case`; `--balance=balanced|unbalanced` and
`--transformed=true|false` are also available. Families are `1d`, `1d_fixed`,
`2d`, `20d`. CDC automatically includes its prerequisite Ada job.

A paper run additionally requires a clean Git checkout and
`--confirm-canonical=YES`. Approve the actual computation separately before
using this option. Freezing the code and reviewing a dry-run plan should precede
a multi-day run. Start with a selected scenario/seed if desired; expanding the
selection later uses the same full plan stored in the run manifest.

## Resume and summarize

Use the same profile, library, worker count and output root, with explicit resume:

```text
Rscript scripts/run_study.R --profile=smoke --family=2d --scenario=local_shift --balance=balanced --workers=2 --r-lib=.Rlib --output-dir=output/smoke-local --resume=true
Rscript scripts/validate_results.R --run-dir=output/smoke-local
Rscript scripts/summarize_study.R --run-dir=output/smoke-local --output-dir=output/summary-local
```

The second invocation can add missing methods/cases by expanding its filters.
It checks existing result bodies and hashes before skipping completed jobs.
Changing source, commit, profile, environment or worker count requires a new
output root. A failed job leaves successful jobs available for resume.
Corrupt or half-written outputs stop validation; they are never silently replaced.
See [operations and recovery](docs/OPERATIONS.md).

Add `--require-complete=true` to validation or aggregation when every job in
the full profile must be present. Partial summaries explicitly report missing
jobs. Summary directories must be new. Outputs include MSE/MCSE, failure counts,
coverage and localization CSVs, diagnostic PDF pages, and a manifest linking
the input and output hashes. Every MSE table carries a smoke/paper label.

## Scope and evidence

- [Settings, seeds, saved objects and figure inputs](docs/STUDY_CONTRACT.md)
- [Infrastructure validation](docs/INFRASTRUCTURE_VALIDATION.md)
- [Current migration status and historical provenance](docs/MIGRATION_STATUS.md)
- [AdaBoost arithmetic-loss CV decision](docs/ADABOOST_CV_ARITHMETIC_VALIDATION.md)
- [Independent review scope](docs/REVIEW_SCOPE.md)

Older workflow entry points under `scripts/coverage`, `scripts/boosting`,
`scripts/revision` and `scripts/figures` are historical references. Their shared
functions and generators are reused by the supported runner; their standalone
commands and historical result readers are not part of its resume contract.
Use the commands above for new runs. Original import hashes remain in
`docs/SOURCE_MANIFEST.csv`.

Full paper runs, coauthor approval, journal-specific figure layout and the final
submission archive are separate follow-up work. Existing official results and
manuscript files are unchanged by this infrastructure.
