# Scientific decisions

## 2026-10-01: Adopt arithmetic-mean AdaBoost CV (U13)

The author approved using equal-weight arithmetic mean fold losses as the
operational AdaBoost tree-selection criterion, computed stably with log-sum-exp.
Exponential loss is the primary criterion; the same aggregation applies to the
diagnostic balancing loss. Classification-error selection retains its existing
rule. The implementation is commit 27241e22265eeb37a14ab9d644081e80120213b2;
see [paired validation](ADABOOST_CV_ARITHMETIC_VALIDATION.md).

The balanced and unbalanced local-shift cases at seed 1 had identical selected
tree counts and estimates before and after the change. This observation does
not establish invariance over the full simulation grid. New AdaBoost runs use
the adopted arithmetic criterion; older results retain their original provenance.

## 2026-10-01: Align 1D MCMC with 2D/20D (U18)

The author approved canonical 1D burn-in 2000 and 1000 retained draws,
replacing burn-in 1000 and 2000 retained draws. The ensemble remains 200 trees;
other model settings and smoke settings remain unchanged. This is an approved
experimental specification change following independent audit U18. Previously
saved 1D results retain their original provenance; updated 1D figures and
summaries require new computation. The canonical study has not been rerun.

Validation: tests/coverage_mcmc_settings.R checks equality across 1D/2D/20D.
The 1D smoke runner completed with 80 observations per group and 40 draws.
A separate reduced-data diagnostic used 40 observations with canonical MCMC
settings (200 trees, burn-in 2000, retained 1000) and verified exactly 1000
saved draws and finite posterior means. This checks execution and dimensions;
it does not establish MCMC convergence or validate paper results. Evidence is
retained in the external run directory u18-mcmc-validation-20261001.
Rollback: revert the dedicated U18 commit; preserve both generations of outputs.
