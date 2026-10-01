# BATTS 0.2.0 API integration (2026-10-01)

Target: c4d194336bd0610372fe8d1b08caa7f94a7cd168, version 0.2.0.
Remove update_lambda, alpha_cutpoint and lambda_prior_parameters from calls.
The previous defaults are now fixed behavior; lambda_0 remains configurable.
The new-run Global/Null identity guard and installation instructions pin the
new commit. Historical result readers retain historical identities.

All simulation R scripts parsed. Existing arithmetic CV and cross-dimension
MCMC setting tests passed. The 1D, 2D local-shift, latent dispersion coverage
and 2D boosting smoke runners completed with the isolated 0.2.0 build, and
all four output hashes matched their manifests. Latent coverage smoke uses
five dimensions; this is not a complete 20D validation. These runs were made
before committing the simulation integration and their metadata records that
state and the actual source hashes. They are diagnostic outputs, not paper data.

The package was locally built from the reviewed source, without a fabricated
RemoteSha. Its source installation is separate from a remotes GitHub install;
the strict Global/Null RemoteSha guard was not bypassed to claim an end-to-end
run. Full Global/Null runner migration and common environment enforcement are
still tracked in MIGRATION_STATUS.md. Removing the legacy API arguments has
been verified by parsing these paths; their full runs were not launched.

Package regression and API tests passed. Six fixed-seed balanced/unbalanced
GB/FS/BAT fits match 0.1.0 exactly, including predictions and final RNG states.
This does not establish all-scenario equality or MCMC convergence. U16 remains
an explicitly deferred numerical limitation. Outputs are retained outside the
repository under batts-api-review-20261001.
