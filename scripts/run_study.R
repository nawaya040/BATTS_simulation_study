script<-sub('^--file=','',grep('^--file=',commandArgs(FALSE),value=TRUE)[1])
root<-normalizePath(file.path(dirname(script),'..'),winslash='/',mustWork=TRUE)
source(file.path(root,'scripts/study/common.R'));study_load(root)
source(file.path(root,'scripts/study/results.R'))
args<-study_args(commandArgs(TRUE))
allowed<-c('profile','family','scenario','methods','seeds','case','balance','transformed',
           'dry-run','output-dir','r-lib','workers','resume','confirm-canonical')
if(any(!names(args)%in%allowed)) stop('Unknown arguments: ',paste(setdiff(names(args),allowed),collapse=','))
profile<-study_arg(args,'profile','smoke');config<-study_config(profile)
plan<-study_plan(config);selected<-study_select(plan,args)
cat('Profile:',profile,'; selected jobs:',nrow(selected),'; full grid:',nrow(plan),'\n')
print(aggregate(job~family+method,selected,length),row.names=FALSE)
if(study_bool(study_arg(args,'dry-run','false'))) quit(save='no',status=0)
if(profile=='paper' && !identical(args[['confirm-canonical']],'YES')) stop('Paper execution requires --confirm-canonical=YES')
workers<-as.integer(study_arg(args,'workers','1'))
if(is.na(workers)||workers<1||as.character(workers)!=study_arg(args,'workers','1')) stop('workers must be a positive integer')
resume<-study_bool(study_arg(args,'resume','false'))
lib<-normalizePath(study_arg(args,'r-lib'),winslash='/',mustWork=TRUE)
environment<-study_require_environment(root,lib)
source_identity<-study_source_identity(root)
if(profile=='paper' && source_identity$dirty) stop('Paper execution requires a clean Git worktree')
identity<-list(config=config,source=source_identity,environment=environment,
               backend='PSOCK',workers=workers,rng=config$rng_kind)
run_id<-study_hash(identity)
runroot<-normalizePath(study_arg(args,'output-dir'),winslash='/',mustWork=FALSE)
dir.create(runroot,recursive=TRUE,showWarnings=FALSE)
lock<-file.path(runroot,'.run-lock')
if(!dir.create(lock,showWarnings=FALSE)) stop('Run directory is locked; inspect any interrupted run before removing .run-lock')
main<-function(){
  manifest_path<-file.path(runroot,'run.rds')
  if(file.exists(manifest_path)) {
    run<-study_read_result(manifest_path)$value
    if(!identical(run$identity,identity)||!identical(run$plan,plan)) stop('Run configuration/source/environment differs; use a new output directory')
    if(!resume) stop('Run already exists; use --resume=true')
    study_validate(runroot) # Validate result bodies and dependencies before skipping work.
  } else {
    other<-setdiff(list.files(runroot,all.files=TRUE,no..=TRUE),'.run-lock')
    if(length(other)) stop('New run requires an empty output directory')
    study_write_result(list(identity=identity,plan=plan,created_utc=format(Sys.time(),tz='UTC',usetz=TRUE)),manifest_path,list(run_id=run_id))
  }
  dir.create(file.path(runroot,'inputs'),showWarnings=FALSE)
  dir.create(file.path(runroot,'results'),showWarnings=FALSE)
  # Input generation runs once per case, before fitting or starting workers.
  cases<-selected[!duplicated(selected$case),,drop=FALSE]
  for(i in seq_len(nrow(cases))) {
    row<-as.list(cases[i,]);path<-file.path(runroot,'inputs',paste0(row$case,'.rds'))
    expected<-list(run_id=run_id,case=row$case)
    if(file.exists(path)||file.exists(paste0(path,'.manifest.rds'))) study_read_result(path,expected)
    else study_write_result(study_input(row,config),path,expected)
  }
  cl<-parallel::makePSOCKcluster(min(workers,nrow(selected)))
  on.exit(parallel::stopCluster(cl),add=TRUE)
  parallel::clusterCall(cl,function(root,lib,expected){
    Sys.setenv(OMP_NUM_THREADS='1',OPENBLAS_NUM_THREADS='1',MKL_NUM_THREADS='1')
    .libPaths(c(lib,.libPaths()))
    source(file.path(root,'scripts/study/common.R'),local=globalenv());study_load(root)
    if(!identical(study_require_environment(root,lib),expected)) stop('Worker environment mismatch')
    TRUE
  },root,lib,environment)
  work<-function(row,config,root,runroot,run_id,resume) {
    tryCatch({
      input<-study_read_result(file.path(runroot,'inputs',paste0(row$case,'.rds')),
                               list(run_id=run_id,case=row$case))$value
      expected<-list(run_id=run_id,job=row$job,input_hash=input$hash)
      path<-file.path(runroot,'results',paste0(row$job,'.rds'))
      if(file.exists(path)||file.exists(paste0(path,'.manifest.rds'))) {
        if(!resume) stop('Existing job; explicit resume required')
        study_read_result(path,expected)
        return(list(job=row$job,status='verified_existing'))
      }
      result<-study_fit(row,input,config,root,runroot,run_id)
      study_write_result(result,path,expected)
      list(job=row$job,status='completed')
    },error=function(e) list(job=row$job,status='failed',error=conditionMessage(e)))
  }
  status<-list()
  # CDC is a separate dependency wave so an Ada result is never read mid-write.
  for(wave in list(selected[selected$method!='cdc',,drop=FALSE],selected[selected$method=='cdc',,drop=FALSE])) {
    if(!nrow(wave)) next
    tasks<-lapply(seq_len(nrow(wave)),function(i) as.list(wave[i,]))
    # Bounded batches also provide progress on Windows PSOCK.
    for(begin in seq(1,length(tasks),by=workers)) {
      batch<-tasks[begin:min(length(tasks),begin+workers-1L)]
      results<-parallel::parLapply(cl,batch,work,config,root,runroot,run_id,resume)
      status<-c(status,results)
      for(z in results) {
        line<-paste(format(Sys.time(),tz='UTC',usetz=TRUE),z$job,z$status,
                    if(is.null(z$error)) '' else z$error)
        cat(line,'\n');cat(line,'\n',file=file.path(runroot,'progress.log'),append=TRUE)
      }
    }
  }
  if(any(vapply(status,function(x)x$status=='failed',logical(1)))) stop('Some jobs failed; see progress.log. Successful results are retained.')
  study_validate(runroot)
  cat('Selected jobs complete. Run validate_results.R and summarize_study.R.\n')
}
tryCatch(main(),finally=unlink(lock,recursive=TRUE))
