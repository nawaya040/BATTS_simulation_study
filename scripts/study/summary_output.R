# Write the summary tables, posterior tables, diagnostic figures and manifest of
# a validated result set (one run root, or several combined by study_combine).
# No estimator is rerun. extra_tables (named data frames) are written as CSV files
# and extra_manifest adds fields to summary-manifest.rds.
study_write_summary <- function(checked,out,root,extra_manifest=list(),extra_tables=list()) {
  if(dir.exists(out)||file.exists(out)) stop('Summary output directory must be new')
  dir.create(out,recursive=TRUE)
  tables<-study_summarize(checked)
  job_diagnostics<-do.call(rbind,lapply(checked$records,function(rec) cbind(as.data.frame(rec$row),
    data.frame(elapsed_seconds=rec$value$timing[['elapsed']],
      warning_count=length(rec$value$warnings),warnings=paste(rec$value$warnings,collapse=' | '),
      run_status=checked$run$identity$config$status))))
  write.csv(job_diagnostics,file.path(out,'job-diagnostics.csv'),row.names=FALSE)
  source(file.path(root,'scripts/study/posterior_tables.R'),local=TRUE)
  posterior_tables<-study_posterior_tables(checked)
  for(name in names(posterior_tables)) {
    z<-posterior_tables[[name]]
    z$run_status<-checked$run$identity$config$status
    write.csv(z,file.path(out,paste0(gsub('_','-',name),'.csv')),row.names=FALSE)
  }
  tables$metrics$run_status<-checked$run$identity$config$status
  tables$summary$run_status<-checked$run$identity$config$status
  tables$summary$full_grid_complete<-checked$complete
  write.csv(tables$metrics,file.path(out,'per-seed-metrics.csv'),row.names=FALSE)
  write.csv(tables$summary,file.path(out,'mse-summary.csv'),row.names=FALSE)
  write.csv(checked$run$plan[checked$run$plan$job%in%checked$missing,],file.path(out,'missing-jobs.csv'),row.names=FALSE)
  source(file.path(root,'scripts/study/figures.R'),local=TRUE)
  study_figures(checked,file.path(out,'simulation-diagnostics.pdf'))
  for(name in names(extra_tables)) write.csv(extra_tables[[name]],file.path(out,paste0(name,'.csv')),row.names=FALSE)
  study_save(c(list(run_id=checked$run_id,status=checked$run$identity$config$status,
    full_grid_complete=checked$complete,missing_jobs=checked$missing,
    input_hashes=setNames(lapply(checked$records,`[[`,'sha256'),names(checked$records)),
    output_hashes=study_files_hash(out,list.files(out)),
    plotting_source=study_source_identity(root)),extra_manifest),file.path(out,'summary-manifest.rds'))
  invisible(tables)
}
