args<-commandArgs(TRUE)
if(length(args)!=1L) stop('Supply a saved smoke run containing BAT grid results')
script<-sub('^--file=','',grep('^--file=',commandArgs(FALSE),value=TRUE)[1])
root<-normalizePath(file.path(dirname(script),'..'),winslash='/',mustWork=TRUE)
source(file.path(root,'scripts/study/common.R'));study_load(root)
source(file.path(root,'scripts/study/results.R'))
runroot<-normalizePath(args[1],winslash='/',mustWork=TRUE)
set.seed(24);before<-.Random.seed
checked<-study_validate(runroot,retain_draws=TRUE)
stopifnot(identical(before,.Random.seed))
cat('Normal saved results accepted:',length(checked$records),'\n')
rec<-Filter(function(r) r$row$method=='bat' && !is.null(r$value$grid),checked$records)[[1]]
sim<-checked$inputs[[rec$row$case]]$simulation
config<-checked$run$identity$config
check<-function(value) study_validate_bat_saved(value,sim,rec$row,config)
reject<-function(value,pattern) {
  before<-.Random.seed
  error<-tryCatch({check(value);NA_character_},error=conditionMessage)
  stopifnot(!is.na(error),grepl(pattern,error,fixed=TRUE),identical(before,.Random.seed))
}
v<-rec$value;v$omega<-v$omega[1];v$tau_inverse<-1/v$omega;reject(v,'Temperature')
for(bad in c(0,-1,Inf,NA_real_)) {
  v<-rec$value;v$omega[1]<-bad;v$tau_inverse<-1/v$omega;reject(v,'Temperature')
}
v<-rec$value;v$forests<-v$forests[-1];reject(v,'forest count')
v<-rec$value;v$forests[[1]][[1]]<-list();reject(v,'tree schema')
v<-rec$value;v$forests[[1]][[1]]$beta<-v$forests[[1]][[1]]$beta*4;reject(v,'disagree')
v<-rec$value;v$forests[[1]][[1]]$d[1]<-ncol(sim$data);reject(v,'tree dimensions')
v<-rec$value;v$forests[[1]][[1]]<-list(d=c(0L,-1L),l=c(.5,0),beta=c(1,1));reject(v,'Incomplete')
v<-rec$value;v$forests[[1]][[1]]<-list(d=c(-1L,-1L),l=c(0,0),beta=c(1,1));reject(v,'Extra')
v<-rec$value;v$grid$mean[1]<-999;reject(v,'grid summaries')
v<-rec$value;v$grid$quantiles[1,1]<-999;reject(v,'grid summaries')
v<-rec$value;v$grid$inside[1]<-!v$grid$inside[1];reject(v,'grid schema')
v<-rec$value;v$grid$truth[1]<-999;reject(v,'grid schema')
v<-rec$value;v$grid<-NULL;reject(v,'grid schema')
v<-rec$value;v$domain[1,1]<-v$domain[1,1]-1;reject(v,'metadata')
# Non-detail seeds keep forests (count-checked) and skip re-evaluation.
row2<-rec$row;row2$seed<-2L;v<-rec$value;v$grid<-NULL
study_validate_bat_saved(v,sim,row2,config)
v2<-v;v2$forests<-NULL
error<-tryCatch({study_validate_bat_saved(v2,sim,row2,config);NA_character_},error=conditionMessage)
stopifnot(!is.na(error),grepl('forest count',error,fixed=TRUE))
v2<-v;v2$forests[[1]]<-v2$forests[[1]][-1]
error<-tryCatch({study_validate_bat_saved(v2,sim,row2,config);NA_character_},error=conditionMessage)
stopifnot(!is.na(error),grepl('forest count',error,fixed=TRUE))
# Without saved draws, detail forests must reproduce the saved summaries.
stopifnot(is.null(rec$value$draws))
v<-rec$value;v$estimates$primary[1]<-v$estimates$primary[1]+1;reject(v,'estimates/quantiles')
v<-rec$value;v$quantiles[1,2]<-v$quantiles[1,2]+1;reject(v,'estimates/quantiles')
cfg<-config;cfg$save_draws<-TRUE
error<-tryCatch({study_validate_bat_saved(rec$value,sim,rec$row,cfg);NA_character_},error=conditionMessage)
stopifnot(!is.na(error),grepl('Missing BAT draws',error,fixed=TRUE))
# Route a rehashed inconsistent fixture through the complete validator.
base<-tempfile('batts-u24-');dir.create(base)
fixture<-file.path(base,'invalid-fixture');stopifnot(!dir.exists(fixture))
dir.create(fixture);stopifnot(all(file.copy(list.files(runroot,full.names=TRUE),fixture,recursive=TRUE)))
path<-file.path(fixture,'results',paste0(rec$row$job,'.rds'))
obj<-readRDS(path);obj$value$grid$mean[1]<-999
saveRDS(obj,path,version=3,compress='gzip')
saveRDS(list(identity=obj$identity,bytes=file.info(path)$size,sha256=study_hash_file(path)),paste0(path,'.manifest.rds'))
error<-tryCatch({study_validate(fixture);NA_character_},error=conditionMessage)
stopifnot(!is.na(error),grepl('grid summaries',error,fixed=TRUE))
# Byte corruption must continue to fail before semantic checks.
cat('corruption',file=path,append=TRUE)
error<-tryCatch({study_validate(fixture);NA_character_},error=conditionMessage)
stopifnot(!is.na(error),grepl('checksum/size',error,fixed=TRUE))
cat('U24 malformed temperatures, forests, metadata, grids and rehashed fixture rejected; RNG unchanged.\n')

rm(list='.Random.seed',envir=.GlobalEnv)
invisible(study_validate(runroot))
stopifnot(!exists('.Random.seed',envir=.GlobalEnv,inherits=FALSE))
cat('Validation also preserves absence of RNG state.\n')
