# Run from the simulation repository root.
source('scripts/coverage/coverage_common.R')
expected <- list(num_trees=200L, size_burnin=2000L,
                 size_backfitting=1000L, lambda_0=5L)
for (family in c('1d','2d','20d')) {
  stopifnot(identical(coverage_bart_settings('canonical', family), expected))
  smoke <- coverage_bart_settings('smoke', family)
  stopifnot(smoke$size_burnin==20L, smoke$size_backfitting==40L)
}
cat('MCMC configuration checks passed for all families.\n')
