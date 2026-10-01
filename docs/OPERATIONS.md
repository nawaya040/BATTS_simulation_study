# Running, saving and recovering a study

## Output contract

`run.rds` stores the full plan, configuration, actual Git commit, source hashes,
dirty state, R/OS/compiler and package fingerprints, PSOCK backend and requested
worker count. The SHA-256 of this identity is the run ID. No command-line
argument can substitute a purported source commit.

`inputs/<case>.rds` stores the generated observations, labels, analytic truth,
latent coordinates and loadings where available, plus the RNG state immediately
after data generation. All methods read this one cached object. Each result
identity includes its input hash.

`results/<case>__<method>.rds` contains estimates, metrics, diagnostics,
elapsed/user/system times, warnings, seed policy and final RNG state. Every
RDS has a `.manifest.rds` containing the embedded identity, byte count and
SHA-256. Writes use a temporary file in the same directory followed by rename.
There is a brief interval between result and sidecar writes; interruption there
produces an explicitly incomplete pair that validation rejects.

Full BAT draws alone occupy approximately 92.8 GB uncompressed for the paper
grid; forests and other outputs require additional space. Actual gzip size is
data-dependent. Plan storage before scheduling the run. Validation reads one
result at a time, retaining compact per-seed metrics and only the designated
figure inputs; it does not accumulate all posterior samples in memory.

Results are immutable. The run lock prevents two supported runners from writing
the same output directory concurrently. `progress.log` appends completion,
verified-existing and error events. Failed jobs have no completed result pair.
Workers use one BLAS/OpenMP thread each and verify the parent's environment.
CDC is scheduled after Ada and records the exact Ada result hash.

## Recovery

After a normal failure, inspect `progress.log` and resume with the same identity.
When an interrupted process leaves `.run-lock`, verify that all parent/worker R
processes for this run have stopped before manually removing that lock directory.
The tool never clears another process's lock automatically.

For a damaged RDS/manifest pair, preserve the pair outside the run root for
diagnosis. Restore a verified backup or explicitly quarantine both files before
rerunning that job. If Ada is regenerated, quarantine dependent CDC results too.
Do not hand-edit hashes or result metadata. A source/dependency correction starts
a new output root; results from the old root remain available for comparison.

## Aggregation

Validation checks hashes, planned job identities, common input hashes, group
counts, estimate variants and dimensions, recalculated MSE, BAT draws/quantiles/
coverage, boosting fold allocation and CDC dependencies. It also rejects orphan
sidecars and unexpected jobs. This protects against accidental mismatches and
incomplete files; hashes are not a cryptographic signature from an external authority.

Summaries report completed and expected seeds, nonfinite estimates, finite-only
mean/SD/MCSE, and unconditional mean/MCSE only when every completed value is
finite. MCSE uses independent seeds as the sampling unit and is undefined for
one seed. Missing jobs are listed explicitly; `--require-complete=true` turns
missing full-plan jobs into an error. A one-seed smoke cannot estimate MCSE.

Summary outputs are written to a new directory. Their manifest records source
result hashes, output hashes, plotting source and completion status. A failed
summary can be rerun into another new directory without touching simulation
results. PDF pages are diagnostics for inspecting saved results; manuscript
layout and final submission packaging are deferred.

## Version freeze

Commit scientific source and configurations before canonical computation.
Even a Git commit containing only documentation changes creates a distinct run
identity. Keep the original checkout/commit available for resume. Preserve the
environment receipt and working libraries. New machines may create different
binary fingerprints and therefore need their own output roots and validation.
