# BATTS simulation study

Simulation development and review repository for *Two-sample Comparison
through Additive Tree Models for Density Ratios*.

**Status: initial source import for review.** This repository contains existing
simulation workflows with their scientific source unchanged. Coverage and
boosting smoke runs are being checked against BATTS 0.1.0. Some historical
20D workflows still require an older BATTS commit; see
[migration status](docs/MIGRATION_STATUS.md) before running them.
This import is not a complete, validated rerun of the paper.

## Repositories and versions

- Estimation package: [nawaya040/BATTS](https://github.com/nawaya040/BATTS).
- Target package release: **v0.1.0**, commit
  `ceb5fb6bb0045ab6b72f2a91c620a0b3c5bba3b0`.
- Simulation code and settings: this repository.
- Case study: [yuliangxu/TwoSample](https://github.com/yuliangxu/TwoSample).

BATTS package source, case-study data, manuscript files, and generated results
are not bundled here. The journal submission archive will be rebuilt after
the manuscript and computational changes are settled.

## Contents

| Directory | Purpose |
| --- | --- |
| `scripts/coverage/` | Corrected symmetric interval coverage for 1D, 2D and latent 20D settings; includes data generators |
| `scripts/boosting/` | GB, FS and AdaBoost DRT tree-selection experiments |
| `scripts/revision/20d_global_shift/` | Historical 20D global-shift/null, transformed settings, kernel and CDC workflows; old version guards remain |
| `scripts/revision/` | Historical job planning and table aggregation |
| `scripts/figures/` | Imported plotting scripts that accept portable paths or use repository-relative paths |
| `docs/` | Source provenance, migration gaps, environment and review scope |

Inherited directory READMEs describe the runs for which the scripts were
originally written. Their historical approvals and completion claims do not
authorize a new canonical run or establish validation with BATTS 0.1.0.

## Install the target BATTS version

Use an isolated library. In R, starting from this repository:

```r
dir.create(".Rlib", showWarnings = FALSE)
.libPaths(c(normalizePath(".Rlib"), .libPaths()))
install.packages("remotes", lib = ".Rlib")
remotes::install_github(
  "nawaya040/BATTS@ceb5fb6bb0045ab6b72f2a91c620a0b3c5bba3b0",
  lib = ".Rlib", dependencies = NA, upgrade = "never"
)
install.packages(c("ada", "rpart", "mvtnorm", "pracma"), lib = ".Rlib")
stopifnot(as.character(packageVersion("BATTS")) == "0.1.0")
stopifnot(packageDescription("BATTS")$RemoteSha ==
  "ceb5fb6bb0045ab6b72f2a91c620a0b3c5bba3b0")
```

A C++17 toolchain is required when building BATTS from source. See
[environment notes](docs/ENVIRONMENT.md) for the tested environment and optional
dependencies. These installation instructions pin BATTS; they do not constitute
a complete dependency lock.

## Smoke runs

Run from the repository root, using a fresh output directory:

```text
Rscript scripts/coverage/run_coverage_2d.R --mode=smoke --scenario=local_shift --seed=1 --batts-lib=.Rlib --output-dir=output/coverage-check
Rscript scripts/boosting/run_boosting_selection.R --mode=smoke --family=2d --scenario=local_shift --seed=1 --r-lib=.Rlib --output-dir=output/boosting-check
```

These use reduced settings and write `SMOKE_NOT_FOR_PAPER` metadata, source and
package hashes, and output checksums. Existing results are refused unless the
runner's explicit resume checks succeed. Consult each workflow's README for
its arguments and settings. A smoke result does not validate paper numbers.

The imported coverage/boosting loaders record the installed package but do not
enforce the target release themselves. Use the isolated, pinned library above.
The historical 20D global/null guards still reject this release until their
version contract is updated and reviewed.

## Before full computation

1. Review [the import and remaining work](docs/MIGRATION_STATUS.md).
2. Audit the exact BATTS commit and exact simulation commit using
   [the review scope](docs/REVIEW_SCOPE.md).
3. Agree with the coauthors on comparator changes and sensitivity analyses.
4. Approve scientific patches and canonical settings, then freeze both commits.

No independent AI review, coauthor approval of this new repository, or full
simulation rerun is implied by its creation.
