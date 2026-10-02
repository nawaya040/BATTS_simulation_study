# Study settings and saved figure inputs

The authoritative configuration is `config/study.R`; job enumeration is
`study_plan()` in `scripts/study/common.R`. Selection filters do not alter
scientific settings. This patch is reproducibility infrastructure, reusing the
approved estimators and CV rules. It does not introduce a new estimator.

| Family | Paper settings | Smoke settings |
| --- | --- | --- |
| 1D BAT | (500,500), (100,900), (2500,2500), (500,4500) | (40,40), (16,64) |
| 1D fixed Ada/GB | (500,500), (300,700), (200,800), (100,900); 100 trees, depth 2, rate .01, no CV, subsample .5 for both | Smaller groups, same fixed tree specification |
| 2D | global shift, local shift, local dispersion; (5000,5000), (9000,1000) | Same scenarios; (40,40), (72,8) |
| 20D | global shift, null, latent location shift, latent dispersion; both transforms and both 2D sample-size settings | Same scenarios/transforms and 20 dimensions; smoke sample sizes |

Paper uses seeds 1–50; smoke uses seed 1. BAT uses 200 trees, burn-in 2000 and
1000 saved draws in every paper dimension, with lambda 5. Smoke uses 20 trees,
burn-in 20 and 40 saved draws. GB/FS/Ada use five folds and at most 1000 trees
for paper; smoke uses two folds and at most 60 trees. Rate .01 and depth 4
are unchanged. Ada uses bag fraction .5. GB/FS build each tree from a
random half of the training observations drawn in the same way (BATTS 0.2.2
`subsample_fraction = .5`: one per group, the rest unstratified, without
replacement), also in the 1D fixed-tree comparison. KLIEP/uLSIF use the vendored defaults;
their parameter grids are preserved even in smoke runs.

For 2D/20D the methods are BAT, GB, FS, Ada DRT, KLIEP, uLSIF and CDC.
Ada saves all three selection variants. Exponential loss is the primary Ada
variant; classification error is retained for historical comparisons and
balancing loss for diagnostics. Fold losses are averaged arithmetically with
log-sum-exp stabilization. CDC uses that saved primary Ada score and retains
the existing `submitted` and `stable` calibration variants; this infrastructure
does not decide to replace the submitted calibration formula.

## Random numbers and numerical scope

RNG kind is Mersenne-Twister / Inversion / Rejection. Data use the replicate
seed. 1D BAT continues the post-data state; 2D/20D BAT reset to the replicate
seed, following the existing runners. The boosting helpers retain their seed
map (shared fold seed 100000 + replicate). Kernels use 700000 + replicate for
KLIEP and 710000 + replicate for uLSIF, matching the global/null workflow.
The fixed 1D comparison preserves the submitted order: data, Ada, GB, without
an intervening seed reset. Its source is `Experiments/supp_check_ada_bias.R`
and the K_CV=0 branch of `R/utilities_for_experiment.R` in the research source.

Each saved result records its actual RNG policy and final state. Scheduling
order does not select a different dataset. Historical results made by other
entry points may use different seeds or dependencies; this workflow does not
claim byte-identical reproduction of those historical files. Current model
changes (BATTS 0.2.0, arithmetic CV, 1D MCMC settings) were separately approved
before this infrastructure patch.

The latent generator now additionally returns its already-computed loading
matrix and pre-transform observations. This adds output fields without adding
random draws or changing observations/truth. Grid predictions retain an explicit
inside-domain mask; predictions outside the fitted BATTS domain are omitted
to avoid stochastic extrapolation during result export.

## Saved information and plots

| Paper content | Stored inputs for new runs |
| --- | --- |
| 1D posterior curves and temperature | Posterior forests (all seeds), means, quantiles, omega and inverse omega; seed-1 grid predictions |
| 1D fixed-tree Ada/GB comparison (S1) | Both observed-point estimates and grid curves, truth, Ada probabilities and fixed settings |
| 2D surfaces and credible intervals | Data, truth, posterior forests (all seeds), seed-1 grid predictions |
| 20D generated data and latent projections | Observed/latent data, loading matrix and pre-transform data for latent scenarios |
| Coverage/calibration and localization | Per-seed coverage at 99 nominal levels computed from the exact draws during fitting, 95% zero-exclusion indicators derived from quantiles; forests allow draw reconstruction |
| MSE tables | Per-method/per-variant/per-seed symmetric training MSE, finite/failed counts and MCSE |

`summarize_study.R` exports these numerical summaries and a diagnostic PDF from
validated saved objects, with no estimator rerun. Every seed retains BAT
posterior forests (observed-point draws are reconstructed with `study_bat_draws()`);
seed 1 additionally retains grid predictions. Detailed
forests can be large in paper runs, so reserve disk space before starting them.

Exact historic manuscript layouts and standalone illustrative datasets (such
as S5's separate n=500+500, seed-2 illustration) remain documented historical
plotting work. They are not silently substituted with the larger main-study
datasets. Building the final journal figure/submission package remains deferred.

## Saved-posterior validation (U24)

Validation checks the retained temperature count, positivity and finiteness.
For detail seeds, it checks every serialized tree's preorder structure,
split dimensions and locations, and positive finite leaf parameters. It
independently evaluates every saved forest in R at all observed points and
all stored in-domain grid points, comparing observed draws and grid summaries
with tolerance 1e-10. Grid coordinates, truth and the domain mask must match
the saved input. Non-detail seeds do not store forests and receive the draw,
temperature and summary checks only. These checks do not fit a model or use
random numbers; full forest evaluation adds time and a grid-by-draw matrix.
File checksums continue to be required. Internal consistency does not establish
external authenticity or MCMC convergence. Existing result files are read only.
