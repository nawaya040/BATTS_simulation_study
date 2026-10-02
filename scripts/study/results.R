# Re-evaluate saved posterior trees in R, without fitting or consuming RNG.
# The serialized tree is preorder, d is zero-based and -1 denotes a leaf.
study_saved_tree_weights <- function(tree, points) {
  if(!is.list(tree) || !all(c('d','l','beta') %in% names(tree)) ||
     anyDuplicated(names(tree))) stop('Invalid posterior tree schema')
  d<-tree$d; cut<-tree$l; beta<-tree$beta; n<-length(d)
  if(!is.numeric(d)||!is.numeric(cut)||!is.numeric(beta)||n<1L||
     length(cut)!=n||length(beta)!=n||any(!is.finite(d))||
     any(d!=floor(d))||any(d < -1 | d >= ncol(points))) stop('Invalid posterior tree dimensions')
  split<-d>=0
  if(any(!is.finite(cut[split]))||any(cut[split]<=0|cut[split]>=1)||
     any(!is.finite(beta[!split]))||any(beta[!split]<=0)) stop('Invalid posterior tree parameters')
  stack<-list(list(rows=seq_len(nrow(points)),lo=rep(0,ncol(points)),hi=rep(1,ncol(points))))
  weight<-rep(NA_real_,nrow(points))
  for(i in seq_len(n)) {
    k<-length(stack)
    if(k==0L) stop('Extra posterior tree nodes')
    node<-stack[[k]];stack[[k]]<-NULL
    if(!split[i]) {weight[node$rows]<-sqrt(beta[i]);next}
    j<-d[i]+1L; location<-node$lo[j]+cut[i]*(node$hi[j]-node$lo[j])
    left<-node;right<-node
    left$hi[j]<-location;right$lo[j]<-location
    goes_left<-points[node$rows,j]<location
    left$rows<-node$rows[goes_left];right$rows<-node$rows[!goes_left]
    stack[[length(stack)+1L]]<-right
    stack[[length(stack)+1L]]<-left
  }
  if(length(stack)||anyNA(weight)) stop('Incomplete posterior tree')
  weight
}

# Log-ratio draws (points x saved draws) from a saved posterior forest.
# raw_points are on the data scale; they must lie inside value$domain.
study_bat_forest_predict <- function(value, raw_points) {
  domain<-value$domain
  points<-sweep(sweep(as.matrix(raw_points),2,domain[,1],'-'),2,domain[,2]-domain[,1],'/')
  out<-matrix(NA_real_,nrow(points),length(value$forests))
  for(s in seq_along(value$forests)) {
    w<-rep(1,nrow(points))
    for(tree in value$forests[[s]]) w<-w*study_saved_tree_weights(tree,points)
    out[,s]<-2*log(value$fit_c*w)
  }
  out
}
# Reconstruct the observed-point BAT draws of a saved result from its forest.
# Agrees with the draws of the fit to floating-point accuracy (not bitwise).
study_bat_draws <- function(value, sim) study_bat_forest_predict(value, sim$data)

study_validate_bat_saved <- function(value, sim, row, config) {
  count<-config$bat$size_backfitting
  if(!is.numeric(value$omega)||length(value$omega)!=count||
     any(!is.finite(value$omega))||any(value$omega<=0)||
     !identical(1/value$omega,value$tau_inverse)) stop('Temperature draws mismatch')
  if(is.null(value$draws)) {
    if(isTRUE(config$save_draws)) stop('Missing BAT draws')
  } else if(!is.matrix(value$draws)||!is.numeric(value$draws)||any(!is.finite(value$draws)))
    stop('Invalid BAT draws')
  detail<-row$seed %in% config$detail_seeds
  if(detail || isTRUE(config$save_forests)) {
    if(!is.list(value$forests)||length(value$forests)!=count||
       any(!vapply(value$forests,is.list,logical(1)))||
       any(lengths(value$forests)!=config$bat$num_trees)) stop('Posterior forest count mismatch')
  }
  # Re-evaluating every forest is costly; it is done for the detail seeds.
  if(!detail) return(invisible(TRUE))
  x<-as.matrix(sim$data); domain<-value$domain
  if(!is.matrix(domain)||!is.numeric(domain)||!identical(dim(domain),c(ncol(x),2L))||
     any(!is.finite(domain))||any(domain[,2]<=domain[,1])||
     !is.list(value$data_info)||!identical(value$data_info$min_max_values,domain)||
     !identical(as.integer(value$data_info$d),as.integer(ncol(x)))||
     !is.numeric(value$fit_c)||length(value$fit_c)!=1L||
     !is.finite(value$fit_c)||value$fit_c<=0) stop('Invalid posterior prediction metadata')
  within<-function(p) apply(sweep(p,2,domain[,1],'>=') & sweep(p,2,domain[,2],'<='),1,all)
  if(any(!is.finite(x))||!all(within(x))) stop('Observed points outside posterior domain')
  points<-x; nobs<-nrow(x); ngrid<-0L
  if(!is.null(sim$grid_points)) {
    gp<-as.matrix(sim$grid_points); inside<-within(gp)
    if(any(inside)) {
      grid<-value$grid
      if(!is.list(grid)||!identical(grid$points,gp)||!identical(grid$inside,inside)||
         !identical(grid$truth,sim$true_log_w_grid)||
         !is.numeric(grid$mean)||length(grid$mean)!=sum(inside)||
         !is.matrix(grid$quantiles)||!identical(dim(grid$quantiles),c(sum(inside),3L)))
        stop('Saved grid schema mismatch')
      ngrid<-sum(inside);points<-rbind(points,gp[inside,,drop=FALSE])
    } else if(!is.null(value$grid)) stop('Unexpected saved grid')
  } else if(!is.null(value$grid)) stop('Unexpected saved grid')
  pred<-study_bat_forest_predict(value,points)
  if(any(!is.finite(pred))) stop('Posterior forests give nonfinite predictions')
  obs_draws<-pred[seq_len(nobs),,drop=FALSE]
  if(!is.null(value$draws)) {
    if(!isTRUE(all.equal(as.numeric(obs_draws),as.numeric(value$draws),
                         tolerance=1e-10,check.attributes=FALSE)))
      stop('Posterior forests disagree with observed draws')
  } else {
    # Without saved draws, the forests must reproduce the saved summaries.
    q_obs<-t(apply(obs_draws,1,quantile,probs=c(.025,.5,.975)))
    if(!isTRUE(all.equal(rowMeans(obs_draws),as.numeric(value$estimates$primary),tolerance=1e-10,check.attributes=FALSE))||
       !isTRUE(all.equal(q_obs,value$quantiles,tolerance=1e-10,check.attributes=FALSE)))
      stop('Posterior forests disagree with saved estimates/quantiles')
    if(!identical(coverage_compute(obs_draws,as.numeric(sim$true_log_w_obs)),value$coverage))
      stop('Posterior forests disagree with saved coverage')
  }
  grid_draws<-pred[nobs+seq_len(ngrid),,drop=FALSE]
  if(ngrid) {
    q<-t(apply(grid_draws,1,quantile,probs=c(.025,.5,.975)))
    if(!isTRUE(all.equal(rowMeans(grid_draws),value$grid$mean,tolerance=1e-10,check.attributes=FALSE))||
       !isTRUE(all.equal(q,value$grid$quantiles,tolerance=1e-10,check.attributes=FALSE)))
      stop('Saved grid summaries disagree with posterior forests')
  }
  invisible(TRUE)
}

study_validate <- function(runroot,require_complete=FALSE,retain_draws=FALSE) {
  # Fold verification can seed R internally; validation must leave the caller's
  # RNG state unchanged, including on failure or when no seed existed.
  had_seed<-exists('.Random.seed',envir=.GlobalEnv,inherits=FALSE)
  if(had_seed) saved_seed<-get('.Random.seed',envir=.GlobalEnv,inherits=FALSE)
  on.exit({
    if(had_seed) assign('.Random.seed',saved_seed,envir=.GlobalEnv)
    else if(exists('.Random.seed',envir=.GlobalEnv,inherits=FALSE))
      rm(list='.Random.seed',envir=.GlobalEnv)
  },add=TRUE)
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
      if(!is.null(value$draws)) {
        if(!identical(dim(value$draws),c(nrow(sim$data),run$identity$config$bat$size_backfitting)) ||
           !isTRUE(all.equal(rowMeans(value$draws),value$estimates$primary,tolerance=0))) stop('BAT draws mismatch')
        q<-t(apply(value$draws,1,quantile,probs=c(.025,.5,.975)))
        if(!identical(q,value$quantiles)) stop('Posterior quantiles disagree with draws')
      } else if(!is.matrix(value$quantiles)||!identical(dim(value$quantiles),c(nrow(sim$data),3L))||
                any(!is.finite(value$quantiles))||!is.list(value$coverage)) stop('BAT summary dimensions mismatch')
      study_validate_bat_saved(value,sim,row,run$identity$config)
      if(!is.null(value$draws) &&
         !identical(coverage_compute(value$draws,as.numeric(sim$true_log_w_obs)),value$coverage)) stop('Coverage mismatch')
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
