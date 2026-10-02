# Environment

Target BATTS version: 0.2.2, Git commit
`77c217297910a5ba50b71313e8289d9024b669c9`.

The initial checks use Windows, R 4.5.2, Rtools45 / GCC 14.3.0,
Rcpp 1.1.1.1 and RcppArmadillo 14.4.1.1. The BATTS build uses C++17.
This records a tested environment; it is not a complete dependency lock.

The coverage and boosting smoke workflows use BATTS, mvtnorm, pracma, ada
and rpart. Other imported workflows also use digest, matrixStats, densratio,
ggplot2 and patchwork; consult their explicit dependency checks. The historical
densratio implementation/version must be established before comparator reruns;
installing an arbitrary current version does not validate historical results.

The README installs BATTS from its full commit and checks both the package
version and RemoteSha. The local smoke tests may use an already-built isolated
BATTS library whose source was verified against that release. Those binaries
are not distributed here.

Keep installed libraries outside version control. Record package versions and
toolchain metadata for each actual run. Check the intended dependency versions
before upgrading packages or preparing a lock file.
