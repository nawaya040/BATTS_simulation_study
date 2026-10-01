study_validate <- function(runroot,require_complete=FALSE,retain_draws=FALSE) {
  runobj<-study_read_result(file.path(runroot,'run.rds'))
  run<-runobj$value;run_id<-study_hash(run$identity)
  if(!identical(runobj$identity,list(run_id=run_id))) stop('Run manifest identity mismatch')
  plan<-run$plan
  if(!identical(plan,study_plan(run$identity$config))) stop('Run plan disagrees with frozen configuration')
  if(anyDuplicated(plan$job)) stop('Duplicate planned jobs')
  paths<-list.files(file.path(runroot,'results'),pattern='[.]rds$',full.names=TRUE)
  files<-paths[!grepl('[.]manifest[.]rds$',paths)]
  jobs<-sub('[.]rds$','',basename(files))
  if(anyDuplicated(jobs)||any(!jobs%in%plan$job)) stop('Unexpected or duplicate result jobs')
  if(any(!file.exists(sub('[.]manifest[.]rds$','',paths[grepl('[.]manifest[.]rds$',paths)])))) stop('Manifest without result')
  if(require_complete && !setequal(jobs,plan$job)) stop('Full plan is incomplete: ',nrow(plan)-length(jobs),' jobs missing')
  records<-list(); inputs<-list();active_case<-NULL;active_input<-NULL
  for(i in seq_along(files)) {
    row<-as.list(plan[match(jobs[i],plan$job),])
    if(!identical(active_case,row$case)) {
      input<-study_read_result(file.path(runroot,'inputs',paste0(row$case,'.rds')),
                             list(run_id=run_id,case=row$case))$value
      sim<-input$simulation
      hash<-study_hash(list(data=sim$data,labels=sim$group_labels,truth=sim$true_log_w_obs,
        latent=sim$data_u,loading=sim$loading,transformed=row$transformed))
      if(!identical(hash,input$hash)) stop('Input data hash mismatch')
      if(nrow(sim$data)!=row$n0+row$n1 || !identical(as.integer(table(factor(sim$group_labels,levels=0:1))),c(row$n0,row$n1)))
        stop('Input dimensions/group counts mismatch')
      active_case<-row$case;active_input<-input
      if(row$seed %in% run$identity$config$detail_seeds) inputs[[row$case]]<-input
    }
    input<-active_input;sim<-input$simulation
    expected<-list(run_id=run_id,job=row$job,input_hash=input$hash)
    value<-study_read_result(files[i],expected)$value
    variants<-switch(row$method,bat='primary',gb='primary',fs='primary',kliep='primary',ulsif='primary',
      ada=c('exponential_loss','classification_error','balancing_loss'),cdc=c('submitted','stable'),
      ada_gb_fixed=c('ada','gb'))
    if(!setequal(names(value$estimates),variants)||anyDuplicated(names(value$estimates))||
       !all(vapply(value$estimates,is.numeric,logical(1)))) stop('Unexpected estimate variants')
    if(!length(value$estimates)||any(lengths(value$estimates)!=nrow(sim$data))) stop('Estimate dimensions mismatch')
    metrics<-do.call(rbind,lapply(names(value$estimates),function(variant)
      boosting_metric_row(row$method,variant,'train',value$estimates[[variant]],as.numeric(sim$true_log_w_obs),as.integer(sim$group_labels))))
    if(!isTRUE(all.equal(value$metrics,metrics,tolerance=0))) stop('Stored metrics disagree with result body')
    if(row$method=='bat') {
      if(!identical(dim(value$draws),c(nrow(sim$data),run$identity$config$bat$size_backfitting)) ||
         !isTRUE(all.equal(rowMeans(value$draws),value$estimates$primary,tolerance=0))) stop('BAT draws mismatch')
      q<-t(apply(value$draws,1,quantile,probs=c(.025,.5,.975)))
      if(!identical(q,value$quantiles)) stop('Posterior quantiles disagree with draws')
      if(row$seed %in% run$identity$config$detail_seeds && !length(value$forests)) stop('Missing posterior forests')
      if(!length(value$omega)||!identical(1/value$omega,value$tau_inverse)) stop('Temperature draws mismatch')
      if(!identical(coverage_compute(value$draws,as.numeric(sim$true_log_w_obs)),value$coverage)) stop('Coverage mismatch')
    }
    if(row$method %in% c('gb','fs','ada')) {
      fold<-if(row$method=='ada') value$fold_id else value$diagnostics$fold_id
      expected_fold<-boosting_make_stratified_folds(as.integer(sim$group_labels),run$identity$config$boosting$folds,100000L+row$seed)
      if(!identical(fold,expected_fold)) stop('Method fold allocation mismatch')
    }
    if(row$method=='cdc') {
      dep<-file.path(runroot,'results',paste0(value$dependency$job,'.rds'))
      study_read_result(dep,list(run_id=run_id,job=paste0(row$case,'__ada'),input_hash=input$hash))
      if(!identical(value$dependency$sha256,study_hash_file(dep))) stop('CDC dependency hash mismatch')
    }
    if(row$method=='bat') {
      q<-value$quantiles;truth<-as.numeric(sim$true_log_w_obs)
      excluded<-q[,1]>0|q[,3]<0
      wrong<-(q[,1]>0 & truth<0)|(q[,3]<0 & truth>0)
      value$localization<-data.frame(exclusion_rate=mean(excluded),wrong_direction_rate=mean(wrong),
        exclusion_at_true_zero=if(any(truth==0)) mean(excluded[truth==0]) else NA_real_)
      if(!retain_draws) {value$draws<-NULL;value$forests<-NULL;value$coverage$is_included_mat<-NULL}
    }
    # Keep one large job in memory during validation; aggregation only needs
    # scalar metrics and coverage curves outside the designated figure seeds.
    if(!retain_draws && !row$seed %in% run$identity$config$detail_seeds)
      value<-value[intersect(names(value),c('metrics','coverage','localization','timing','warnings'))]
    records[[row$job]]<-list(row=row,value=value,sha256=study_hash_file(files[i]))
  }
  list(run=run,records=records,inputs=inputs,missing=setdiff(plan$job,jobs),
       complete=setequal(jobs,plan$job),run_id=run_id)
}
study_summarize <- function(checked) {
  records<-checked$records
  if(!length(records)) stop('No completed results to summarize')
  metric_rows<-lapply(records,function(rec) {
    m<-rec$value$metrics
    cbind(as.data.frame(rec$row)[rep(1,nrow(m)),c('case','job','family','scenario','n0','n1','transformed','seed')],m)
  })
  metrics<-do.call(rbind,metric_rows);rownames(metrics)<-NULL
  keys<-c('family','scenario','n0','n1','transformed','method','selection')
  groups<-split(seq_len(nrow(metrics)),interaction(metrics[keys],drop=TRUE))
  summary<-do.call(rbind,lapply(groups,function(idx) {
    x<-metrics$mse_symmetric[idx];finite<-is.finite(x);n<-sum(finite)
    cbind(metrics[idx[1],keys,drop=FALSE],data.frame(completed_seeds=length(x),
      expected_seeds=length(checked$run$identity$config$seeds),
      missing_seeds=length(checked$run$identity$config$seeds)-length(x),nonfinite_seeds=sum(!finite),
      mean_mse=if(all(finite)) mean(x) else NA_real_,
      mcse=if(all(finite)&&length(x)>1) sd(x)/sqrt(length(x)) else NA_real_,
      finite_only_mean=if(n) mean(x[finite]) else NA_real_,finite_seeds=n,
      finite_only_sd=if(n>1) sd(x[finite]) else NA_real_,
      finite_only_mcse=if(n>1) sd(x[finite])/sqrt(n) else NA_real_))
  }))
  rownames(summary)<-NULL
  list(metrics=metrics,summary=summary)
}
