# AdaBoost arithmetic-mean CV validation

Date: 2026-10-01. Classification: independent audit correction (U13), approved
by the author. This change can alter simulation numbers through tree selection.

## Change and scope

In `scripts/boosting/boosting_selection_common.R`, the two fold aggregations
for exponential loss and diagnostic balancing loss now use the existing
`boosting_log_mean_exp_columns()` helper. Given fold log losses `ell_k(t)`,
the selection curve is `log(sum(exp(ell_k(t))) / K)`, evaluated with
log-sum-exp. Every fold has equal weight. The previous curve was
`sum(ell_k(t)) / K`. Field names `mean_log_exponential_loss` and
`mean_log_balancing_loss` are retained; they now mean the log of arithmetic
mean loss. Classification-error aggregation, fold construction, learner
settings and BATTS package source are unchanged.

Old simulation commit: `26743fd9782aa37f59e889e32a7630423026358f`.
New simulation commit: `27241e22265eeb37a14ab9d644081e80120213b2`.
Reverting the latter restores the previous CV criterion and associated docs/test.

## Paired experiment

The existing canonical boosting runner was executed separately at both commits
for 2D `local_shift`, seed index 1, with `(n0,n1)=(5000,5000)` and `(9000,1000)`.
All four jobs finished successfully (about nine minutes each).
Settings: 5 stratified folds, maximum 1000 trees, learning rate 0.01,
Ada depth 4, bag fraction 0.5, GB/FS depth 4. Data seed 1; fold seed 100001;
Ada fold-fit seeds 200101 through 200105; Ada final-fit seed 300001.
GB and FS both reset seed 100001, as implemented by this runner. Its metadata
also contains unused `gb=500001` and `fs=600001` seed-map entries.

MSE is evaluated on the training observations and equals half the sum of the
two group-specific mean squared errors of the estimated full log density ratio.
Each group therefore receives weight one half, including the unbalanced case.

| Pattern | Criterion | Trees old / new | Symmetric MSE old / new | Maximum absolute estimate difference |
| --- | --- | --- | --- | --- |
| Balanced | Exponential (primary) | 388 / 388 | 0.05102174823 / 0.05102174823 | 0 |
| Unbalanced | Exponential (primary) | 370 / 370 | 0.12525008967 / 0.12525008967 | 0 |
| Balanced | Balancing (diagnostic) | 388 / 388 | 0.05102174823 / 0.05102174823 | 0 |
| Unbalanced | Balancing (diagnostic) | 370 / 370 | 0.12525008967 / 0.12525008967 | 0 |
| Balanced | Classification (legacy) | 10 / 10 | 0.23270867027 / 0.23270867027 | 0 |
| Unbalanced | Classification (legacy) | 11 / 11 | 4.11752159781 / 4.11752159781 | 0 |

For primary AdaBoost, group-0/group-1 MSEs are 0.03337035326 / 0.06867314319
in the balanced case and 0.08428285187 / 0.16621732748 in the unbalanced case,
identically before and after the patch. All estimates are finite; pointwise
RMS differences are zero and correlations are one.

The aggregated CV curves do change: maximum absolute differences in log CV
score are approximately 7.561196e-6 (balanced) and 1.594975e-4 (unbalanced),
for both exponential and diagnostic balancing loss. Their minimizing tree
counts happen to remain unchanged for these data and seeds.

| Control | Balanced trees / MSE | Unbalanced trees / MSE |
| --- | --- | --- |
| GB | 183 / 0.0295133488316 | 142 / 0.0677488670050 |
| FS | 197 / 0.0255670004139 | 128 / 0.0750087271841 |

The entire saved GB/FS result objects are exactly identical between versions.
These controls use this runner's seed mapping; earlier comparisons using a
different method seed need not have the same MSE.

## Validation and provenance

- `Rscript tests/ada_cv_aggregation.R` passed. A two-candidate example selects
  different optima under arithmetic and geometric averaging; stable results
  are also checked for log losses near +1000 and -1000.
- All four output SHA-256 values match their manifests.
- Fold allocations, labels and analytic truths are exactly identical in each
  old/new pair. All per-fold classification, exponential and balancing loss
  curves are exactly identical.
- The saved old aggregate curves equal `colMeans(fold_log_loss)` exactly;
  the saved new aggregate curves equal the log-sum-exp arithmetic aggregation
  exactly. Thus the actual runner, as well as the helper, uses the new rule.
- GB/FS diagnostics, fold loss curves, selected trees, estimates and metrics
  are identical. Ada estimates and selected counts are also identical.

Environment: Windows x86_64, R 4.5.2; BATTS 0.1.0, ada 2.0.5,
rpart 4.1.24, Rcpp 1.1.1.1, RcppArmadillo 14.4.1.1, mvtnorm 1.3.3,
pracma 2.4.4. The paired runs use the same isolated BATTS 0.1.0 candidate
installation from release validation (scientific code matching v0.1.0),
including identical installed-package hashes. They do not independently
revalidate installation from the GitHub release. RNG is Mersenne-Twister /
Inversion / Rejection; each job is sequential with one core, and four jobs
were launched concurrently. Each output records source/package hashes,
configuration, commit, environment and timing.

Local evidence is retained under the external run directory named
`adaboost-cv-arithmetic-20261001`: old/new RDS results and manifests,
`compare.R`, `comparison.csv`, `comparison.txt`, and `comparison-audit.rds`.
Generated results and installed libraries are excluded from source control.

These two paired cases establish zero output impact for the chosen scenario
and seed. Other seeds or scenarios can select different tree counts under the
new criterion; this check does not establish that existing full-study AdaBoost
results are unchanged. No complete simulation rerun or manuscript edit was
performed.