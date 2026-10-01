# Run from the repository root: Rscript tests/ada_cv_aggregation.R
source('scripts/boosting/boosting_selection_common.R')
loss <- matrix(c(1, 100, 20, 20), nrow = 2)
stopifnot(which.min(colMeans(log(loss))) == 1L)
stopifnot(which.min(boosting_log_mean_exp_columns(log(loss))) == 2L)
stopifnot(isTRUE(all.equal(boosting_log_mean_exp_columns(log(loss)),
                          log(colMeans(loss)), tolerance = 1e-14)))
# Direct exponentiation would overflow/underflow, but both answers are finite.
extreme <- cbind(c(1000, 999), c(-1000, -1001))
expected <- c(1000, -1000) + log((1 + exp(-1))/2)
stopifnot(isTRUE(all.equal(boosting_log_mean_exp_columns(extreme),expected)))
cat('Arithmetic CV aggregation: all checks passed\n')
