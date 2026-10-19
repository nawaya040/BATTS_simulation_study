# Environment

The paper's results were computed with BATTS 0.2.2, Git commit
`77c217297910a5ba50b71313e8289d9024b669c9` (tag `v0.2.2` of
[nawaya040/BATTS](https://github.com/nawaya040/BATTS)), and the modified
`densratio` 0.2.1 source vendored under `vendor/densratio` (see
[its provenance](DENSRATIO_PROVENANCE.md)).

Environment used for the paper runs:

| Component | Version |
| --- | --- |
| R | 4.5.2 (x86_64-w64-mingw32, Windows) |
| Compiler | Rtools45 / GCC 14.3.0, `-std=gnu++17 -O2` |
| BATTS | 0.2.2 |
| densratio (vendored) | 0.2.1 |
| ada | 2.0.5 |
| rpart | 4.1.24 |
| mvtnorm | 1.3.3 |
| pracma | 2.4.4 |
| matrixStats | 1.5.0 |
| digest | 0.6.37 |
| Rcpp | 1.1.1.1 |
| RcppArmadillo | 14.4.1.1 |

The figure scripts in `scripts/figures/paper/` additionally require
ggplot2 4.0.3 and patchwork 1.3.2; with these versions they reproduce the
published figure layout exactly. `scripts/prepare_environment.R` does not
install them.

`scripts/prepare_environment.R` installs BATTS from its full commit and the
vendored densratio into a new library, and records R, OS, compiler, dependency
versions and installed-file hashes in `study-environment.rds`. Every run
checks this receipt. This is a record of the tested environment, not a complete
dependency lock. Keep installed libraries outside version control.
