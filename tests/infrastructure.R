# Run after a full smoke grid; all mutations below target an isolated fixture.
script<-sub('^--file=','',grep('^--file=',commandArgs(FALSE),value=TRUE)[1])
root<-normalizePath(file.path(dirname(script),'..'),winslash='/')
source(file.path(root,'scripts/study/common.R'));study_load(root)
source(file.path(root,'scripts/study/results.R'))
a<-study_args(commandArgs(TRUE))
runroot<-normalizePath(study_arg(a,'run-dir'),winslash='/')
out<-study_arg(a,'output-dir');if(dir.exists(out)) stop('Test output must be new')
dir.create(out,recursive=TRUE)
lib<-normalizePath(study_arg(a,'r-lib'),winslash='/');study_require_environment(root,lib)
checked<-study_validate(runroot,TRUE,retain_draws=TRUE)
stopifnot(checked$run$identity$config$profile=='smoke',length(checked$records)==160L)
passed<-character()
ok<-function(name){passed<<-c(passed,name);cat('PASS',name,'\n')}
fails<-function(f,name){stopifnot(inherits(tryCatch({f();NULL},error=identity),'error'));ok(name)}
ok('all 160 smoke jobs validate with result bodies, input hashes and dependencies')
compact<-study_validate(runroot,TRUE)
stopifnot(identical(study_summarize(compact),study_summarize(checked)),
  all(vapply(compact$records,function(z)is.null(z$value$draws)&&is.null(z$value$forests),logical(1))))
ok('streamed validation preserves summaries and releases posterior draws')
stopifnot(nrow(study_plan(study_config('paper')))==8100L)
ok('paper plan enumerates 8100 jobs without executing them')
# Every method of a case shares exactly one input cache; 20D remains 20D.
for(rec in checked$records) if(rec$row$family=='20d')
  stopifnot(ncol(checked$inputs[[rec$row$case]]$simulation$data)==20L)
ok('all 20D smoke inputs have 20 coordinates')
old<-new.env(parent=globalenv())
eval(parse(text=study_git(root,c('show','65e43e15fff25ae7c134d9fb3c141e95bf8680a9:scripts/coverage/models/section42_multi_models.R'))),envir=old)
for(scenario in c('latent_location_shift','latent_dispersion')) for(tr in c(FALSE,TRUE)) {
  set.seed(1);before_data<-old$simulation_multi_latent(40,40,20,scenario,unif_w=.2,transform=tr);rng_before<-.Random.seed
  set.seed(1);after_data<-simulation_multi_latent(40,40,20,scenario,unif_w=.2,transform=tr)
  stopifnot(identical(before_data,after_data[names(before_data)]),identical(rng_before,.Random.seed))
}
ok('additional latent fields leave original data, truth and RNG unchanged')
# Stable finite-only MCSE: sd(1,3)/sqrt(2)=1; failed seed stays visible.
r<-checked$records[[1]];fake<-checked
fake$records<-lapply(c(1,Inf,3),function(x){z<-r;z$value$metrics$mse_symmetric<-x;z})
s<-study_summarize(fake)$summary
stopifnot(s$finite_only_mean==2,s$finite_only_mcse==1,s$nonfinite_seeds==1,is.na(s$mean_mse))
fake$records<-list(r);stopifnot(is.na(study_summarize(fake)$summary$mcse))
ok('finite-only mean/SD/MCSE and one-seed undefined MCSE')
fixture<-file.path(out,'fixture');dir.create(fixture)
case<-names(checked$inputs)[grepl('^2d_local_shift_n0-40_',names(checked$inputs))][1]
files<-c('run.rds','run.rds.manifest.rds',
  file.path('inputs',paste0(case,c('.rds','.rds.manifest.rds'))),
  file.path('results',list.files(file.path(runroot,'results'),pattern=paste0('^',case))))
for(f in files){dir.create(dirname(file.path(fixture,f)),recursive=TRUE,showWarnings=FALSE);stopifnot(file.copy(file.path(runroot,f),file.path(fixture,f)))}
invisible(study_validate(fixture));ok('a valid partial selection is accepted')
fails(function()study_validate(fixture,TRUE),'partial selection cannot claim full completion')
p<-file.path(fixture,'results',paste0(case,'__bat.rds'));side<-paste0(p,'.manifest.rds')
original<-readBin(p,'raw',file.info(p)$size);manifest<-readRDS(side)
restore<-function(){writeBin(original,p);saveRDS(manifest,side)}
writeBin(as.raw(c(1,2,3)),p)
fails(function()study_validate(fixture),'corrupted RDS is rejected');restore()
unlink(p);fails(function()study_validate(fixture),'sidecar without RDS is rejected');restore()
unlink(side);fails(function()study_validate(fixture),'RDS without sidecar is rejected');restore()
rewrite<-function(obj){saveRDS(obj,p);m<-manifest;m$bytes<-file.info(p)$size;m$sha256<-study_hash_file(p);saveRDS(m,side)}
z<-readRDS(p);z$value$metrics$mse_symmetric<-999;rewrite(z)
fails(function()study_validate(fixture),'incorrect metrics rejected even with updated checksum');restore()
z<-readRDS(p);z$value$quantiles[1,1]<-999;rewrite(z)
fails(function()study_validate(fixture),'incorrect posterior quantiles rejected');restore()
z<-readRDS(p);z$identity$input_hash<-'wrong';rewrite(z)
fails(function()study_validate(fixture),'mixed input identity rejected');restore()
fails(function()study_write_result(NULL,p,list()),'existing results cannot be overwritten')
# Numerically compare unified BAT output with the direct package call.
for(family in c('1d','2d')) {
  rec<-Filter(function(z)z$row$family==family&&z$row$method=='bat',checked$records)[[1]]
  input<-checked$inputs[[rec$row$case]];sim<-input$simulation
  do.call(RNGkind,as.list(checked$run$identity$config$rng_kind))
  if(family=='1d') assign('.Random.seed',input$rng_after_data,globalenv()) else set.seed(rec$row$seed)
  fit<-do.call(BATTS::batts,c(list(data=sim$data,group_labels=as.integer(sim$group_labels),quiet=TRUE,
    output_BART_ensembles=TRUE),checked$run$identity$config$bat))
  direct<-2*log(fit$balance_weight_BART_data)
  stopifnot(identical(rowMeans(direct),rec$value$estimates$primary),
            identical(t(apply(direct,1,quantile,probs=c(.025,.5,.975))),rec$value$quantiles),
            identical(fit$forest_list,rec$value$forests))
  if(!is.null(rec$value$draws)) stopifnot(identical(direct,rec$value$draws))
  stopifnot(isTRUE(all.equal(study_bat_draws(rec$value,sim),direct,tolerance=1e-10)))
}
ok('1D and 2D BAT summaries and forests exactly equal direct package calls')
# Numerical fit and RNG equivalence to existing GB/FS/Ada helpers on one case.
for(method in c('gb','fs','ada')) {
  rec<-checked$records[[paste0(case,'__',method)]]
  z<-study_fit(rec$row,checked$inputs[[case]],checked$run$identity$config,root,runroot,checked$run_id)
  stopifnot(identical(z$estimates,rec$value$estimates),identical(z$rng_final,rec$value$rng_final))
}
ok('GB/FS/Ada deterministic rerun including final RNG state')
# CLI tests exercise identity checks and explicit canonical acknowledgement.
rscript<-file.path(R.home('bin'),'Rscript.exe');if(!file.exists(rscript)) rscript<-file.path(R.home('bin'),'Rscript')
invoke<-function(args,name,success=TRUE){
 log<-file.path(out,paste0(name,'.log'))
 status<-system2(rscript,c(shQuote(file.path(root,'scripts/run_study.R')),vapply(args,shQuote,character(1))),stdout=log,stderr=log)
 stopifnot((status==0)==success);ok(name)
}
base<-c('--profile=smoke',paste0('--r-lib=',lib),paste0('--output-dir=',runroot),
  paste0('--workers=',checked$run$identity$workers),'--resume=true')
before<-tools::sha256sum(list.files(file.path(runroot,'results'),full.names=TRUE))
invoke(base,'resume verified existing results')
stopifnot(identical(before,tools::sha256sum(names(before))))
ok('resume leaves every result byte unchanged')
wrong<-base;wrong[grepl('^--workers=',wrong)]<-'--workers=1'
invoke(wrong,'changed worker configuration rejected',FALSE)
invoke(c('--profile=paper',paste0('--output-dir=',file.path(out,'forbidden'))),'paper requires explicit acknowledgement',FALSE)
stopifnot(!dir.exists(file.path(out,'forbidden')))
invoke(c('--dry-run=true'),'default dry run is smoke')
# A cloned partial run permits identity mutation without touching actual results.
rp<-file.path(fixture,'run.rds');original_run<-readRDS(rp);original_side<-readRDS(paste0(rp,'.manifest.rds'))
changed<-original_run;changed$value$identity$source$commit<-paste(rep('0',40),collapse='')
saveRDS(changed,rp);ms<-original_side;ms$bytes<-file.info(rp)$size;ms$sha256<-study_hash_file(rp);saveRDS(ms,paste0(rp,'.manifest.rds'))
changed_args<-base;changed_args[grepl('^--output-dir=',changed_args)]<-paste0('--output-dir=',fixture)
invoke(changed_args,'changed source commit rejected',FALSE)
saveRDS(original_run,rp);ms<-original_side;ms$bytes<-file.info(rp)$size;ms$sha256<-study_hash_file(rp);saveRDS(ms,paste0(rp,'.manifest.rds'))
# Remove one synthetic-fixture job, then confirm that resume recomputes only it.
gp<-file.path(fixture,'results',paste0(case,'__gb.rds'))
unlink(c(gp,paste0(gp,'.manifest.rds')))
invoke(c(changed_args,paste0('--case=',case)),'partial selection expands on resume')
after<-study_validate(fixture);stopifnot(length(after$records)==7L)
ok('expanded partial selection validates all seven methods')
badlib<-file.path(out,'environment-fixture');dir.create(badlib)
for(pkg in c('BATTS','densratio')) stopifnot(file.copy(file.path(lib,pkg),badlib,recursive=TRUE))
receipt<-readRDS(file.path(lib,'study-environment.rds'))
saveRDS(receipt,file.path(badlib,'study-environment.rds'))
stopifnot(identical(study_require_environment(root,badlib),study_require_environment(root,lib)))
ok('identical copied dependency files verify')
badreceipt<-receipt;badreceipt$environment$r<-'modified'
saveRDS(badreceipt,file.path(badlib,'study-environment.rds'))
fails(function()study_require_environment(root,badlib),'changed environment receipt rejected')
badreceipt<-receipt;badreceipt$batts_sha<-'wrong-source'
saveRDS(badreceipt,file.path(badlib,'study-environment.rds'))
fails(function()study_require_environment(root,badlib),'wrong BATTS source receipt rejected')
.libPaths(c(lib,.libPaths()))
# Synthetic fixture exercises non-detail seeds without running another experiment.
save_pair<-function(path,obj){saveRDS(obj,path);saveRDS(list(identity=obj$identity,
  bytes=file.info(path)$size,sha256=study_hash_file(path)),paste0(path,'.manifest.rds'))}
runobj<-readRDS(file.path(fixture,'run.rds'))
runobj$value$identity$config$detail_seeds<-integer()
newid<-study_hash(runobj$value$identity);runobj$identity$run_id<-newid
save_pair(file.path(fixture,'run.rds'),runobj)
paths<-list.files(fixture,recursive=TRUE,pattern='[.]rds$',full.names=TRUE)
paths<-paths[!grepl('[.]manifest[.]rds$|/run[.]rds$',paths)]
paths<-c(paths[!grepl('__cdc[.]rds$',paths)],paths[grepl('__cdc[.]rds$',paths)])
for(path in paths){z<-readRDS(path);z$identity$run_id<-newid
  if(grepl('__cdc[.]rds$',path)) z$value$dependency$sha256<-study_hash_file(file.path(fixture,'results',paste0(case,'__ada.rds')))
  save_pair(path,z)}
compact<-study_validate(fixture)
stopifnot(length(compact$inputs)==0L,all(vapply(compact$records,function(z)is.null(z$value$estimates),logical(1))))
source(file.path(root,'scripts/study/posterior_tables.R'))
stopifnot(nrow(study_posterior_tables(compact)$localization_per_seed)==1L)
ok('non-detail replicates retain compact coverage/localization summaries only')
writeLines(passed,file.path(out,'passed.txt'))
cat(length(passed),'checks passed\n')
