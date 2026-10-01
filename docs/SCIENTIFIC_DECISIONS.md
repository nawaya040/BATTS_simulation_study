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
