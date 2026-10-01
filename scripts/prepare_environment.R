script<-sub('^--file=','',grep('^--file=',commandArgs(FALSE),value=TRUE)[1])
root<-normalizePath(file.path(dirname(script),'..'),winslash='/',mustWork=TRUE)
source(file.path(root,'scripts/study/common.R'));study_load(root)
a<-study_args(commandArgs(TRUE))
if(any(!names(a)%in%c('r-lib','install','batts-source'))) stop('Unknown environment argument')
lib<-normalizePath(study_arg(a,'r-lib'),winslash='/',mustWork=FALSE)
if(!study_bool(study_arg(a,'install','false'))) stop('Explicit --install=true required; use a fresh isolated library')
if(dir.exists(lib)&&length(list.files(lib,all.files=TRUE,no..=TRUE))) stop('Library must be empty to avoid replacing an installation')
dir.create(lib,recursive=TRUE,showWarnings=FALSE);.libPaths(c(lib,.libPaths()))
sha<-study_config('smoke')$batts_sha
if(!is.null(a[['batts-source']])) {
  source_root<-normalizePath(a[['batts-source']],winslash='/',mustWork=TRUE)
  if(!identical(study_git(source_root,'rev-parse HEAD')[[1]],sha)||length(study_git(source_root,c('status','--porcelain'))))
    stop('BATTS source must be the clean pinned commit')
  temp<-tempfile();dir.create(temp);archive<-file.path(temp,'source.tar')
  study_git(source_root,c('archive','--format=tar',paste0('--output=',shQuote(archive)),sha))
  utils::untar(archive,exdir=file.path(temp,'BATTS'))
  install.packages(file.path(temp,'BATTS'),lib=lib,repos=NULL,type='source')
} else {
  if(!requireNamespace('remotes',quietly=TRUE)) stop('Install remotes first or supply --batts-source')
  remotes::install_github(paste0('nawaya040/BATTS@',sha),lib=lib,dependencies=FALSE,upgrade='never')
}
install.packages(file.path(root,'vendor/densratio'),lib=lib,repos=NULL,type='source')
if(as.character(packageVersion('BATTS',lib.loc=lib))!='0.2.0' ||
   as.character(packageVersion('densratio',lib.loc=lib))!='0.2.1') stop('Source installation failed')
receipt<-list(schema=1L,batts_sha=sha,
  densratio_source=study_files_hash(file.path(root,'vendor/densratio'),sort(list.files(file.path(root,'vendor/densratio'),recursive=TRUE))),
  environment=study_environment(lib),created_utc=format(Sys.time(),tz='UTC',usetz=TRUE))
study_save(receipt,file.path(lib,'study-environment.rds'))
cat('Verified source installs and environment lock written to ',lib,'\n',sep='')
