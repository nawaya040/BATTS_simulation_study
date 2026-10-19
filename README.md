# BATTS simulation study

Code to reproduce the simulation studies (Section 4 and the corresponding
Supplementary Materials) of *Two-sample Comparison through Additive Tree Models
for Density Ratios* by Naoki Awaya, Yuliang Xu and Li Ma
([arXiv:2508.03059](https://arxiv.org/abs/2508.03059)).

- The proposed methods are implemented in the R package
  [BATTS](https://github.com/nawaya040/BATTS). The paper's simulations use
  **BATTS 0.2.2** (tag `v0.2.2`, commit `77c217297910a5ba50b71313e8289d9024b669c9`),
  which this workflow installs and checks automatically.
- The kernel-based comparators use the modified `densratio` source vendored in
  `vendor/densratio` ([provenance](docs/DENSRATIO_PROVENANCE.md)).
- The case study (Section 5) is reproduced separately in
  [yuliangxu/TwoSample](https://github.com/yuliangxu/TwoSample).

## What is computed

| Family | Settings | Methods |
| --- | --- | --- |
| 1D | N(0,1) vs N(1,1.5^2); (n0,n1) = (500,500), (100,900), (2500,2500), (500,4500) | BAT |
| 1D fixed trees | same distributions; (500,500), (300,700), (200,800), (100,900); 100 trees, depth 2 | AdaBoost DRT and GB (Supplementary Figure S1) |
| 2D | global shift, local shift, local dispersion; (5000,5000), (9000,1000) | BAT, GB, FS, DRT, CDC, KLIEP, uLSIF |
| 20D | global shift, null, latent location shift, latent dispersion; raw and transformed; (5000,5000), (9000,1000) | same as 2D |

Every setting is replicated with seeds 1 to 50, giving 8,100 jobs. Tuning
parameters, seeds, the random-number generator and the saved outputs are
described in the [study settings](docs/STUDY_CONTRACT.md); the authoritative
values are in `config/study.R` (profile `paper`).

## 1. Prepare the environment

Use R 4.5 or later and a C++17 compiler (Rtools45 on Windows). Install the
prerequisites in your ordinary R library:

```r
install.packages(c("remotes", "Rcpp", "RcppArmadillo", "ada", "rpart",
                   "mvtnorm", "pracma", "digest", "matrixStats"))
```

From the repository root, create a new, empty study library. This installs
BATTS 0.2.2 from its commit and the vendored densratio, and records the
environment in `.Rlib/study-environment.rds`:

```text
Rscript scripts/prepare_environment.R --install=true --r-lib=.Rlib
```

For an offline build, add `--batts-source=/path/to/BATTS` pointing to a clean
checkout of the same commit. The versions used for the paper are listed in
[docs/ENVIRONMENT.md](docs/ENVIRONMENT.md).

## 2. Check the workflow quickly

The default profile `smoke` uses small samples and short runs; its results are
labelled as not for the paper. For example:

```text
Rscript scripts/run_study.R --dry-run=true
Rscript scripts/run_study.R --profile=smoke --family=2d --scenario=local_shift --balance=balanced --methods=bat,gb,fs,ada --workers=2 --r-lib=.Rlib --output-dir=output/smoke-local
```

`--dry-run=true` prints the plan without computing anything.

## 3. Run the paper settings

The `paper` profile uses the settings of the paper. It requires a clean Git
checkout and `--confirm-canonical=YES`:

```text
Rscript scripts/run_study.R --profile=paper --dry-run=true
Rscript scripts/run_study.R --profile=paper --workers=8 --r-lib=.Rlib --output-dir=output/paper --confirm-canonical=YES
```

Each job uses its own fixed seed (see the study settings), so a selected job
gives the same result regardless of the order of execution or the number of
workers. A subset can be run with the filters `--family`, `--scenario`,
`--methods`, `--seeds`, `--case`, `--balance` and `--transformed`; for example,
one data set of the 2D local-shift scenario:

```text
Rscript scripts/run_study.R --profile=paper --case=2d_local_shift_n0-5000_n1-5000_t-FALSE_s-001 --methods=gb,kliep --workers=1 --r-lib=.Rlib --output-dir=output/paper-check --confirm-canonical=YES
```

Computing time. The full paper profile took about 710 CPU hours on the machine
used for the paper. Typical times per job are a few seconds to a minute for GB
and FS, about 2 minutes (1D), 8 minutes (2D) and 15 minutes (20D) for BAT, and
10 to 20 minutes for AdaBoost with cross-validation. The saved results occupy
about 11 GB, mostly the posterior forests of BAT. A 20D AdaBoost job needs
about 0.5 GB of memory, so choose the number of workers accordingly.

An interrupted run is continued with the same arguments and `--resume=true`.
Completed jobs are verified and skipped; corrupt or incomplete outputs stop the
run instead of being replaced. See [operations and recovery](docs/OPERATIONS.md).

## 4. Validate and summarize

```text
Rscript scripts/validate_results.R --run-dir=output/paper --require-complete=true
Rscript scripts/summarize_study.R --run-dir=output/paper --output-dir=output/summary --require-complete=true
```

The summary contains the MSE tables with Monte Carlo standard errors
(`mse-summary.csv`), per-seed metrics, coverage and localization summaries, a
diagnostic PDF and a manifest linking input and output hashes. If one plan is
computed in several output directories (for example, with different numbers of
workers), summarize them together:

```text
Rscript scripts/summarize_combined.R --run-dirs=output/paper-a,output/paper-b --output-dir=output/summary-combined
```

## 5. Draw the figures

The simulation figures of the paper are drawn from a complete summary without
refitting any estimator. This step needs ggplot2 4.0.3 and patchwork 1.3.2 in
addition to the study library:

```text
Rscript scripts/figures/paper/make_paper_figures.R --summary-dir=output/summary --output-dir=output/figures
```

The PDFs are written to `output/figures/final/` under the file names used in
the manuscript. See [scripts/figures/paper](scripts/figures/paper/README.md).

## Repository layout

- `config/study.R`: settings of the `smoke` and `paper` profiles.
- `scripts/run_study.R`, `validate_results.R`, `summarize_study.R`,
  `summarize_combined.R`: the supported workflow; `scripts/study/` holds its
  functions.
- `scripts/figures/paper/`: figures of the paper.
- `scripts/coverage`, `scripts/boosting`, `scripts/revision`: data generators
  and estimator helpers used by the workflow, together with older standalone
  entry points that are kept for reference.
- `tests/`: checks of the workflow infrastructure.
- `vendor/densratio`: the vendored comparator package.
