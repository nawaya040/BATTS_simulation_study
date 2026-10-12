# Manuscript simulation figures

`make_paper_figures.R` rebuilds the manuscript's simulation figures from a
complete combined summary (`scripts/summarize_combined.R`). It does not fit an
estimator. Case-study figures (Section 5) are not produced here.

1. `prepare_paper_figure_inputs.R` reads only the results listed in the
   summary manifest, checks each result and input hash, and writes the
   intermediate files that the original drawing scripts expect.
2. `draw/` holds the Round 2 drawing scripts, copied without modification
   from the reproducibility package (`code/r2/scripts/figures/` and
   `code/portable/`). Given the Round 2 inputs, they reproduce the submitted
   PDFs pixel for pixel at 110 dpi with ggplot2 4.0.3 and patchwork 1.3.2.

```text
Rscript scripts/figures/paper/make_paper_figures.R --summary-dir=SUMMARY --output-dir=NEW_DIR
```

The output directory must be new. `final/` contains the PDFs under their
manuscript file names, and `manifest.txt` records the commit, environment,
script hashes and output hashes.

| Manuscript figure | Data |
| --- | --- |
| Main Figure 1 and the 1D unbalanced supplement figure | 1D BAT: seed-1 grid, inverse temperature, 50-seed coverage |
| Main Figure 3, S2, S3, S5 | Observed-point estimates of one data set (seeds 1, 21, 16 and 21, as before) |
| Main 20D calibration figure, S4 | `coverage-per-seed.csv` |
| Main 20D pointwise figure | BAT 2.5%/97.5% quantiles and truth, all 50 seeds (previously 10) |
| S1 | 1D fixed-tree Ada/GB grid curves, 50 seeds |

The colour range of the surface figures follows the original rule, with the
displayed GB estimate as the scale reference (previously the Round 1 GB
estimate). Scatter points are drawn in the original order by restoring each
data set's saved post-data RNG state.
