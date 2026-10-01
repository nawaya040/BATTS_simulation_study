# Per-replicate summaries retain the sampling unit for Monte Carlo standard errors.
study_posterior_tables <- function(checked) {
  bats<-Filter(function(z)z$row$method=='bat',checked$records)
  if(!length(bats)) return(list())
  coverage<-do.call(rbind,lapply(bats,function(rec) {
    z<-rec$value$coverage
    cbind(as.data.frame(rec$row)[rep(1,length(z$nominal_mass)),],
      data.frame(nominal=z$nominal_mass,coverage=z$coverage_rate_BAT))
  }))
  localization<-do.call(rbind,lapply(bats,function(rec) {
    cbind(as.data.frame(rec$row),rec$value$localization)
  }))
  keys<-c('family','scenario','n0','n1','transformed','nominal')
  groups<-split(seq_len(nrow(coverage)),interaction(coverage[keys],drop=TRUE))
  coverage_summary<-do.call(rbind,lapply(groups,function(idx) cbind(coverage[idx[1],keys,drop=FALSE],
    data.frame(completed_seeds=length(idx),expected_seeds=length(checked$run$identity$config$seeds),
      mean_coverage=mean(coverage$coverage[idx]),
      mcse=if(length(idx)>1) sd(coverage$coverage[idx])/sqrt(length(idx)) else NA_real_))))
  list(coverage_per_seed=coverage,coverage_summary=coverage_summary,localization_per_seed=localization)
}
