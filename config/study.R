# Frozen settings. Selection of jobs never changes these scientific settings.
study_config <- function(profile) {
  stopifnot(profile %in% c('smoke','paper'))
  small <- profile == 'smoke'
  list(schema=1L, profile=profile, status=if(small) 'SMOKE_NOT_FOR_PAPER' else 'CANONICAL',
       seeds=if(small) 1L else 1:50,
       bat=list(num_trees=if(small) 20L else 200L,
                size_burnin=if(small) 20L else 2000L,
                size_backfitting=if(small) 40L else 1000L, lambda_0=5L),
       boosting=list(folds=if(small) 2L else 5L, max_trees=if(small) 60L else 1000L,
                     min_trees_classification=if(small) 5L else 10L,
                     learn_rate=.01, ada_depth=4L, ada_bag_fraction=.5, proposed_depth=4L,
                     proposed_subsample_fraction=.5),
       fixed_1d=list(num_trees=100L, depth=2L, learn_rate=.01, n_bins=100L,
                     subsample_fraction=.5),
       dimension_20d=20L, grid_2d=if(small) 20L else 100L,
       detail_seeds=1L, save_draws=TRUE,
       rng_kind=c('Mersenne-Twister','Inversion','Rejection'),
       batts_sha='77c217297910a5ba50b71313e8289d9024b669c9')
}
