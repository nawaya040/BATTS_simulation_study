script<-sub('^--file=','',grep('^--file=',commandArgs(FALSE),value=TRUE)[1])
root<-normalizePath(file.path(dirname(script),'..'),winslash='/',mustWork=TRUE)
source(file.path(root,'scripts/study/common.R'));study_load(root)
source(file.path(root,'scripts/study/results.R'))
a<-study_args(commandArgs(TRUE))
if(any(!names(a)%in%c('run-dir','require-complete'))) stop('Unknown validation argument')
x<-study_validate(normalizePath(study_arg(a,'run-dir'),winslash='/'),study_bool(study_arg(a,'require-complete','false')))
cat('Verified ',length(x$records),' results; missing ',length(x$missing),' of ',nrow(x$run$plan),
    '; status ',x$run$identity$config$status,'; full grid complete: ',x$complete,'\n',sep='')
