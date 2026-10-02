# Common infrastructure: no fitting occurs when this file is sourced.
study_args <- function(x) {
  out <- list()
  for(a in x) {
    if(!grepl('^--[^=]+=.+$',a)) stop('Use --name=value arguments')
    key <- sub('^--([^=]+)=.*','\\1',a)
    if(!is.null(out[[key]])) stop('Duplicate argument: ',key)
    out[[key]] <- sub('^--[^=]+=','',a)
  }
  out
}
study_bool <- function(x) {
  if(!x %in% c('true','false')) stop('Boolean arguments must be true or false')
  x=='true'
}
study_arg <- function(a,k,default=NULL) {
  if(!is.null(a[[k]])) return(a[[k]])
  if(is.null(default)) stop('Required: --',k,'=...')
  default
}
study_root <- function() {
  f <- sub('^--file=','',grep('^--file=',commandArgs(FALSE),value=TRUE)[1])
  normalizePath(file.path(dirname(f),'..'),winslash='/',mustWork=TRUE)
}
study_hash_file <- function(f) unname(tools::sha256sum(f))
study_hash <- function(x) {
  f <- tempfile(); on.exit(unlink(f)); saveRDS(x,f,version=3,compress=FALSE)
  study_hash_file(f)
}
study_git <- function(root,args) {
  out <- system2('git',c('-c',shQuote(paste0('safe.directory=',root)),
                        '-C',shQuote(root),args),stdout=TRUE,stderr=FALSE)
  if(!is.null(attr(out,'status')) && attr(out,'status')!=0) stop('Git inspection failed')
  out
}
study_files_hash <- function(root,files) {
  files <- sort(files)
  setNames(as.list(unname(tools::sha256sum(file.path(root,files)))),files)
}
study_source_identity <- function(root) {
  files <- c(list.files(file.path(root,'config'),recursive=TRUE,full.names=FALSE),
             character())
  paths <- c(paste0('config/',files),
    paste0('scripts/',list.files(file.path(root,'scripts'),pattern='[.]R$',recursive=TRUE)),
    paste0('vendor/densratio/',list.files(file.path(root,'vendor/densratio'),recursive=TRUE)))
  list(commit=study_git(root,'rev-parse HEAD')[[1]],
       source_hashes=study_files_hash(root,paths),
       dirty=length(study_git(root,c('status','--porcelain')))>0L)
}
study_load <- function(root) {
  source(file.path(root,'config/study.R'),local=globalenv())
  for(f in c('coverage/coverage_common.R','boosting/boosting_selection_common.R',
             'coverage/models/section41_2d_models.R','coverage/models/section42_multi_models.R',
             'revision/20d_global_shift/20d_global_shift_common.R',
             'revision/20d_global_shift/20d_global_null_transform.R',
             'revision/20d_global_shift/global_null_comparator_common.R'))
    sys.source(file.path(root,'scripts',f),envir=globalenv())
}
study_package_hash <- function(pkg) {
  root <- find.package(pkg)
  f <- sort(list.files(root,recursive=TRUE))
  study_files_hash(root,f)
}
study_environment <- function(lib) {
  lib <- normalizePath(lib,winslash='/',mustWork=TRUE)
  .libPaths(c(lib,.libPaths()))
  pkgs <- c('BATTS','densratio','ada','rpart','mvtnorm','pracma','digest','matrixStats')
  for(p in pkgs) if(!requireNamespace(p,quietly=TRUE)) stop('Missing dependency: ',p)
  deps <- tools::package_dependencies(pkgs,installed.packages(),recursive=TRUE)
  pkgs <- sort(unique(c(pkgs,unlist(deps))))
  versions <- setNames(lapply(pkgs,function(p) as.character(packageVersion(p))),pkgs)
  hashes <- setNames(lapply(pkgs,study_package_hash),pkgs)
  list(r=R.version.string,platform=R.version$platform,os=Sys.info()[c('sysname','release','machine')],
       compiler=coverage_makeconf(),versions=versions,installed_hashes=hashes)
}
study_require_environment <- function(root,lib) {
  path <- file.path(lib,'study-environment.rds')
  if(!file.exists(path)) stop('Run scripts/prepare_environment.R for this library first')
  receipt <- readRDS(path)
  observed <- study_environment(lib)
  if(!identical(receipt$environment,observed)) stop('Environment lock mismatch; use a new run root after explicit revalidation')
  if(!identical(receipt$batts_sha,study_config('smoke')$batts_sha) ||
     !identical(receipt$densratio_source,study_files_hash(file.path(root,'vendor/densratio'),
       sort(list.files(file.path(root,'vendor/densratio'),recursive=TRUE)))))
    stop('Dependency source lock mismatch')
  observed
}
study_plan <- function(config) {
  rows <- list(); i<-0L
  add <- function(family,scenario,n0,n1,transformed,methods) {
    for(seed in config$seeds) for(method in methods) {
      i<<-i+1L
      case <- sprintf('%s_%s_n0-%d_n1-%d_t-%s_s-%03d',family,scenario,n0,n1,transformed,seed)
      rows[[i]] <<- data.frame(case=case,job=paste(case,method,sep='__'),family=family,
        scenario=scenario,n0=as.integer(n0),n1=as.integer(n1),transformed=transformed,
        seed=as.integer(seed),method=method,stringsAsFactors=FALSE)
    }
  }
  sizes1 <- if(config$profile=='smoke') list(c(40,40),c(16,64)) else
    list(c(500,500),c(100,900),c(2500,2500),c(500,4500))
  for(s in sizes1) add('1d','normal',s[1],s[2],FALSE,'bat')
  sizes_fixed <- if(config$profile=='smoke') list(c(40,40),c(24,56),c(16,64),c(8,72)) else
    list(c(500,500),c(300,700),c(200,800),c(100,900))
  for(s in sizes_fixed) add('1d_fixed','normal',s[1],s[2],FALSE,'ada_gb_fixed')
  sizes <- if(config$profile=='smoke') list(c(40,40),c(72,8)) else list(c(5000,5000),c(9000,1000))
  methods<-c('bat','gb','fs','ada','kliep','ulsif','cdc')
  for(scenario in c('global_shift','local_shift','local_dispersion')) for(s in sizes)
    add('2d',scenario,s[1],s[2],FALSE,methods)
  for(scenario in c('global_shift','null','latent_location_shift','latent_dispersion'))
    for(s in sizes) for(tr in c(FALSE,TRUE)) add('20d',scenario,s[1],s[2],tr,methods)
  do.call(rbind,rows)
}
study_select <- function(plan,args) {
  selected <- plan
  for(key in c('family','scenario','methods','seeds','case')) {
    if(is.null(args[[key]]) || args[[key]]=='all') next
    values <- strsplit(args[[key]],',',fixed=TRUE)[[1]]
    col <- switch(key,methods='method',seeds='seed',key)
    if(any(!values %in% as.character(plan[[col]]))) stop('Unknown ',key,' selection')
    selected <- selected[as.character(selected[[col]]) %in% values,,drop=FALSE]
  }
  if(!is.null(args$balance)) {
    if(!args$balance %in% c('balanced','unbalanced')) stop('Invalid balance')
    selected<-selected[(selected$n0==selected$n1)==(args$balance=='balanced'),,drop=FALSE]
  }
  if(!is.null(args$transformed)) selected<-selected[selected$transformed==study_bool(args$transformed),,drop=FALSE]
  if(!nrow(selected)) stop('Selection has no jobs')
  # CDC depends on the same saved Ada fit; include it explicitly in the plan.
  needed <- selected$case[selected$method=='cdc']
  extra <- plan[plan$case %in% needed & plan$method=='ada',,drop=FALSE]
  selected<-unique(rbind(selected,extra))
  selected[order(match(selected$job,plan$job)),,drop=FALSE]
}
study_save <- function(object,path) {
  if(file.exists(path)) stop('Refusing overwrite: ',path)
  dir.create(dirname(path),recursive=TRUE,showWarnings=FALSE)
  temp<-tempfile(tmpdir=dirname(path));on.exit(unlink(temp))
  saveRDS(object,temp,version=3,compress='gzip')
  if(!file.rename(temp,path)) stop('Atomic save failed: ',path)
}
study_write_result <- function(value,path,identity) {
  side<-paste0(path,'.manifest.rds')
  if(file.exists(path)||file.exists(side)) stop('Output already exists or is incomplete: ',path)
  study_save(list(identity=identity,value=value),path)
  study_save(list(identity=identity,bytes=file.info(path)$size,sha256=study_hash_file(path)),side)
}
study_read_result <- function(path,expected=NULL) {
  side<-paste0(path,'.manifest.rds')
  if(!file.exists(path)||!file.exists(side)) stop('Missing result or manifest: ',path)
  manifest<-readRDS(side)
  if(!identical(manifest$bytes,file.info(path)$size)||!identical(manifest$sha256,study_hash_file(path)))
    stop('Result checksum/size mismatch: ',path)
  obj<-readRDS(path)
  if(!identical(obj$identity,manifest$identity)||(!is.null(expected)&&!identical(obj$identity,expected)))
    stop('Result identity mismatch: ',path)
  obj
}
study_input <- function(row,config) {
  do.call(RNGkind,as.list(config$rng_kind));set.seed(row$seed)
  if(startsWith(row$family,'1d')) {
    x<-matrix(c(rnorm(row$n0),rnorm(row$n1,1,1.5)),ncol=1)
    sim<-list(data=x,group_labels=rep(0:1,c(row$n0,row$n1)),
      true_log_w_obs=as.numeric(dnorm(x,log=TRUE)-dnorm(x,1,1.5,log=TRUE)),
      grid_points=matrix(seq(-2.5,3.5,length.out=100),ncol=1))
    sim$true_log_w_grid<-dnorm(sim$grid_points,log=TRUE)-dnorm(sim$grid_points,1,1.5,log=TRUE)
  } else if(row$family=='2d') sim<-simulation_2d(row$n0,row$n1,row$scenario,config$grid_2d)
  else if(startsWith(row$scenario,'latent')) sim<-simulation_multi_latent(row$n0,row$n1,20L,
    row$scenario,unif_w=.2,transform=row$transformed)
  else {
    sim<-generate_global_null_20d(list(scenario=row$scenario,n0=row$n0,n1=row$n1,
      seed=row$seed,d=20L,latent_dim=4L,noise_sd=.1,transformed=row$transformed,
      beta_shape1=.5,beta_shape2=10))
    validate_global_null_simulation(sim)
    sim$true_log_w_obs<-sim$true_log_ratio
  }
  rng<-.Random.seed
  if(any(!is.finite(sim$data))||any(!is.finite(sim$true_log_w_obs))) stop('Nonfinite generated data/truth')
  list(simulation=sim,rng_after_data=rng,
       hash=study_hash(list(data=sim$data,labels=sim$group_labels,truth=sim$true_log_w_obs,
         latent=sim$data_u,loading=sim$loading,transformed=row$transformed)))
}
study_fit <- function(row,input,config,root,runroot,run_id) {
  sim<-input$simulation; x<-sim$data; g<-as.integer(sim$group_labels); truth<-as.numeric(sim$true_log_w_obs)
  method<-row$method; settings<-config$boosting; seed_map<-boosting_seed_map(row$seed)
  warnings<-character(); start<-proc.time(); do.call(RNGkind,as.list(config$rng_kind))
  out<-withCallingHandlers({
    if(method=='ada_gb_fixed') {
      # Supplement S1: preserve the submitted sequential RNG (data -> Ada -> GB).
      assign('.Random.seed',input$rng_after_data,globalenv())
      s<-config$fixed_1d
      frame<-boosting_make_ada_frame(x,g)
      model<-ada::ada(y~.,data=frame,type='real',iter=s$num_trees,nu=s$learn_rate,
        bag.frac=.5,control=rpart::rpart.control(maxdepth=s$depth,cp=-1,minsplit=0))
      probability<-predict(model,frame,type='prob')
      gridframe<-boosting_make_ada_frame(sim$grid_points,rep(0L,nrow(sim$grid_points)))
      gridprob<-predict(model,gridframe,type='prob')
      drt<-log(probability[,1]/probability[,2]*row$n1/row$n0)
      grid_drt<-log(gridprob[,1]/gridprob[,2]*row$n1/row$n0)
      fit<-BATTS::boots(data=x,group_labels=g,num_trees=s$num_trees,K_CV=0L,
        max_resol=s$depth,learn_rate=s$learn_rate,n_bins=s$n_bins,use_gradient=TRUE,quiet=TRUE,
        subsample_fraction=s$subsample_fraction)
      gb<-2*log(fit$balance_weight_boosting_data)
      points<-sim$grid_points
      inside<-apply(sweep(points,2,fit$Omega[,1],'>=') & sweep(points,2,fit$Omega[,2],'<='),1,all)
      grid_gb<-rep(NA_real_,nrow(points))
      grid_gb[inside]<-2*log(BATTS::eval_balance_weight(fit,points[inside,,drop=FALSE],FALSE)$balancing_weight_boosting)
      list(estimates=list(ada=as.numeric(drt),gb=as.numeric(gb)),
        fixed_settings=s,grid=list(points=points,truth=as.numeric(sim$true_log_w_grid),
          ada=grid_drt,gb=grid_gb,inside=inside),probability=probability)
    } else if(method=='bat') {
      if(row$family=='1d') assign('.Random.seed',input$rng_after_data,globalenv()) else set.seed(row$seed)
      # Saving forests does not change the draws; they replace saved draws
      # (study_bat_draws() reconstructs draws from a saved forest).
      keep_forests<-isTRUE(config$save_forests) || row$seed %in% config$detail_seeds
      fit<-do.call(BATTS::batts,c(list(data=x,group_labels=g,quiet=TRUE,
        output_BART_ensembles=keep_forests),config$bat))
      draws<-2*log(fit$balance_weight_BART_data)
      if(any(!is.finite(draws))) stop('Nonfinite BAT draws')
      estimate<-rowMeans(draws)
      quantiles<-t(apply(draws,1,quantile,probs=c(.025,.5,.975)))
      grid<-NULL
      if(row$seed %in% config$detail_seeds && !is.null(sim$grid_points)) {
        points<-as.matrix(sim$grid_points)
        inside<-apply(sweep(points,2,fit$Omega[,1],'>=') & sweep(points,2,fit$Omega[,2],'<='),1,all)
        if(any(inside)) {
          prediction<-2*log(BATTS::eval_balance_weight(fit,points[inside,,drop=FALSE],TRUE)$balancing_weight_BART)
          grid<-list(points=points,inside=inside,mean=rowMeans(prediction),
            quantiles=t(apply(prediction,1,quantile,probs=c(.025,.5,.975))),truth=sim$true_log_w_grid)
        }
      }
      list(estimates=list(primary=estimate),coverage=coverage_compute(draws,truth),
        quantiles=quantiles,omega=fit$omega_store,tau_inverse=1/fit$omega_store,
        draws=if(config$save_draws) draws else NULL,grid=grid,
        forests=if(keep_forests) fit$forest_list else NULL,
        fit_c=fit$c,domain=fit$Omega,data_info=fit$data_info)
    } else if(method %in% c('gb','fs')) {
      z<-boosting_run_proposed(x,g,truth,settings,method=='gb',seed_map$folds,method)
      list(estimates=list(primary=z$estimates$train),diagnostics=z$diagnostics)
    } else if(method=='ada') {
      folds<-boosting_make_stratified_folds(g,settings$folds,seed_map$folds)
      cv<-boosting_compute_ada_cv(x,g,folds,settings,seed_map$ada_cv_base)
      selections<-boosting_select_ada_trees(cv,settings$min_trees_classification,settings$max_trees)
      fit<-boosting_fit_ada_final(x,g,max(selections$final_selected_trees),settings,seed_map$ada_final)
      estimates<-setNames(lapply(selections$final_selected_trees,function(n)
        boosting_ada_log_ratio(fit,x,n,row$n0,row$n1)),selections$criterion)
      list(estimates=estimates,cv=cv,selections=selections,fold_id=folds,
        nodes=boosting_ada_node_summary(fit,selections))
    } else if(method %in% c('kliep','ulsif')) {
      set.seed(700000L+row$seed+if(method=='ulsif') 10000L else 0L)
      fit<-if(method=='kliep') densratio::KLIEP(x[g==0,,drop=FALSE],x[g==1,,drop=FALSE],verbose=FALSE) else
        densratio::uLSIF(x[g==0,,drop=FALSE],x[g==1,,drop=FALSE],verbose=FALSE)
      ratio<-fit$compute_density_ratio(x)
      list(estimates=list(primary=suppressWarnings(log(ratio))),
        nonpositive_ratio=sum(!is.finite(ratio)|ratio<=0))
    } else if(method=='cdc') {
      ada_path<-file.path(runroot,'results',paste0(row$case,'__ada.rds'))
      expected<-list(run_id=run_id,job=paste0(row$case,'__ada'),input_hash=input$hash)
      ada<-study_read_result(ada_path,expected)$value
      score<-ada$estimates$exponential_loss-log(row$n1/row$n0)
      z<-global_null_predict_cdc(global_null_fit_cdc(score,g),score)
      list(estimates=list(submitted=z$submitted,stable=z$stable),diagnostics=z$diagnostics,
        dependency=list(job=paste0(row$case,'__ada'),sha256=study_hash_file(ada_path)))
    } else stop('Unknown method')
  },warning=function(w){warnings<<-c(warnings,conditionMessage(w));invokeRestart('muffleWarning')})
  out$metrics<-do.call(rbind,lapply(names(out$estimates),function(variant)
    boosting_metric_row(method,variant,'train',out$estimates[[variant]],truth,g)))
  out$timing<-unclass(proc.time()-start);out$warnings<-unique(warnings)
  out$rng_final<-.Random.seed;out$seed_map<-seed_map
  out$rng_policy<-if(method=='ada_gb_fixed'||(method=='bat'&&row$family=='1d'))
    'continue saved post-data RNG' else if(method=='bat') paste('reset seed',row$seed) else
    if(method %in% c('kliep','ulsif')) paste('reset seed',700000L+row$seed+if(method=='ulsif')10000L else 0L) else
    if(method=='cdc') 'deterministic from saved Ada scores' else 'boosting_seed_map; shared folds'
  out
}
