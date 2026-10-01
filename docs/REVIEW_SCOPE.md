# Independent review scope

This is a brief for the next review, not a record that it has been performed.

Review the exact simulation repository commit supplied by the author together
with BATTS v0.1.0, commit `ceb5fb6bb0045ab6b72f2a91c620a0b3c5bba3b0`.
Record both full hashes at the start; do not substitute another branch or HEAD.
Assess the existing implementation independently, using prior review findings
as a checklist after the initial examination.

## Package and integration

- Check implemented FS/GB updates and BAT transitions against the manuscript's
  stated mathematical model, including normalization and empty leaves.
- Verify the fixes in BATTS NEWS and distinguish resolved findings from
  limitations that remain. Reproduce any new finding with a minimal example.
- Verify API calls, `2 * log(w)` scale and ratio direction, initialization,
  sample-space transformations, version checks and package provenance.

## Experiments

- Verify scenario definitions, analytic truth, sample sizes, seeds and method
  reset points against the intended experiments.
- Check group weighting, MSE/SE, CV selection, posterior summaries, symmetric
  intervals, coverage and non-finite-value handling.
- Audit comparator settings and CDC calibration without silently changing them.
- Check raw/transformed 20D generators, seed-specific loading matrices and
  agreement of datasets across methods.
- Check smoke/canonical separation, output identity, hash-verified resume,
  no-overwrite behavior and library propagation to workers.
- Identify missing run or plotting entry points using MIGRATION_STATUS.md.

## Deliverable and limits

For each finding provide severity, file/line, reproduction evidence, scientific
impact, whether numbers/RNG may change, and a minimal proposed repair. Include
checks passed, untested areas and unresolved decisions. Separate implementation
defects from proposed extensions to the scientific comparison.

Read-only analysis and isolated reduced diagnostics are permitted. Do not
change code, launch full simulations, regenerate submission wrappers, edit the
paper or contact coauthors as part of the review without explicit authorization.
