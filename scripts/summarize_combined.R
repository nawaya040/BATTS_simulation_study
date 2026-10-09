# Summarize several run roots of one canonical plan (see study_combine()).
# Example:
#   Rscript scripts/summarize_combined.R --run-dirs=A,B,C --output-dir=OUT
#     --expected-missing-methods=ulsif
script<-sub('^--file=','',grep('^--file=',commandArgs(FALSE),value=TRUE)[1])
root<-normalizePath(file.path(dirname(script),'..'),winslash='/',mustWork=TRUE)
source(file.path(root,'scripts/study/common.R'));study_load(root)
source(file.path(root,'scripts/study/results.R'))
source(file.path(root,'scripts/study/summary_output.R'))
a<-study_args(commandArgs(TRUE))
if(any(!names(a)%in%c('run-dirs','output-dir','expected-missing-methods'))) stop('Unknown combined-summary argument')
roots<-normalizePath(strsplit(study_arg(a,'run-dirs'),',',fixed=TRUE)[[1]],winslash='/',mustWork=TRUE)
expected<-study_arg(a,'expected-missing-methods','')
expected<-if(nzchar(expected)) strsplit(expected,',',fixed=TRUE)[[1]] else character()
out<-study_arg(a,'output-dir')
if(dir.exists(out)||file.exists(out)) stop('Summary output directory must be new')
checked<-study_combine(roots,expected)
study_write_summary(checked,out,root,list(combined=checked$combined),
  list(`combined-roots`=checked$combined$roots,`combined-duplicates`=checked$combined$duplicates))
cat('Combined summary written from',length(roots),'roots;',length(checked$records),'results;',
    nrow(checked$combined$duplicates),'identical duplicates;',length(checked$missing),'expected missing (',
    paste(names(checked$combined$missing_by_method),checked$combined$missing_by_method,collapse=', '),')\n')
