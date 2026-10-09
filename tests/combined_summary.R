# Combined summaries across run roots (study_combine). Usage:
#   Rscript tests/combined_summary.R <smoke root A> <smoke root B> <single-root smoke reference> <other-profile root> <output dir>
# A and B split the smoke grid between them (B repeats some A jobs) without uLSIF;
# the reference runs the whole smoke grid in one root with the same code.
args<-commandArgs(TRUE)
if(length(args)!=5L) stop('Supply roots A, B, reference, an other-profile root and a new output directory')
script<-sub('^--file=','',grep('^--file=',commandArgs(FALSE),value=TRUE)[1])
root<-normalizePath(file.path(dirname(script),'..'),winslash='/',mustWork=TRUE)
source(file.path(root,'scripts/study/common.R'));study_load(root)
source(file.path(root,'scripts/study/results.R'))
source(file.path(root,'scripts/study/summary_output.R'))
A<-args[1];B<-args[2];ref<-args[3];other<-args[4];out<-args[5]
if(dir.exists(out)) stop('Test output must be new')
dir.create(out,recursive=TRUE)
ok<-function(name) cat('PASS',name,'\n')
fails<-function(expr,pattern,name) {
  e<-tryCatch({force(expr);NA_character_},error=conditionMessage)
  if(is.na(e)||!grepl(pattern,e,fixed=TRUE)) stop('Expected failure not raised: ',name,' (',e,')')
  ok(name)
}
set.seed(5);rng<-.Random.seed
x<-study_combine(c(A,B),'ulsif')
stopifnot(identical(rng,.Random.seed))
dups<-x$combined$duplicates
stopifnot(nrow(dups)>0,all(dups$identical),all(dups$used_root==normalizePath(A,winslash='/')))
ok(sprintf('combine A+B: %d results, %d identical duplicates, RNG unchanged',length(x$records),nrow(dups)))
plan<-x$run$plan
stopifnot(setequal(x$missing,plan$job[plan$method=='ulsif']),!x$complete)
ok('only expected uLSIF jobs missing')
r<-study_validate(ref)
keep<-setdiff(names(r$records),plan$job[plan$method=='ulsif'])
stopifnot(setequal(names(x$records),keep))
same_metrics<-vapply(keep,function(j) isTRUE(all.equal(x$records[[j]]$value$metrics,r$records[[j]]$value$metrics,tolerance=0)),logical(1))
same_cov<-vapply(keep,function(j) identical(x$records[[j]]$value$coverage$coverage_rate_BAT,r$records[[j]]$value$coverage$coverage_rate_BAT),logical(1))
stopifnot(all(same_metrics),all(same_cov))
ok('per-job metrics and BAT coverage equal the single-root reference')
sx<-study_summarize(x)$summary; rx<-study_summarize(r)$summary
rx<-rx[rx$method!='ulsif',]
key<-function(d) do.call(paste,d[c('family','scenario','n0','n1','transformed','method','selection')])
stopifnot(setequal(key(sx),key(rx)))
sx<-sx[order(key(sx)),];rx<-rx[order(key(rx)),]
stopifnot(isTRUE(all.equal(sx[setdiff(names(sx),'expected_seeds')],rx[setdiff(names(rx),'expected_seeds')],check.attributes=FALSE,tolerance=0)))
ok('MSE summary equals the single-root reference (uLSIF excluded)')
study_write_summary(x,file.path(out,'summary'),root,list(combined=x$combined),list(`combined-roots`=x$combined$roots))
stopifnot(file.exists(file.path(out,'summary',c('mse-summary.csv','coverage-summary.csv','combined-roots.csv','summary-manifest.rds','simulation-diagnostics.pdf'))))
m<-readRDS(file.path(out,'summary','summary-manifest.rds'))
stopifnot(identical(m$combined$roots,x$combined$roots),
          identical(m$output_hashes,study_files_hash(file.path(out,'summary'),
            setdiff(list.files(file.path(out,'summary')),'summary-manifest.rds'))))
ok('combined summary files written')
fails(study_combine(c(A,B)),'planned jobs are missing','unexpected missing jobs rejected')
fails(study_combine(c(A,A),'ulsif'),'two distinct','repeated root rejected')
fails(study_combine(c(A,other),'ulsif'),'Run plans differ','different profile rejected')
fails(study_merge_input_hashes(list(list(c1='h1',c2='h2'),list(c2='hX'))),'Input data differ','input-hash mismatch rejected')
stopifnot(identical(study_merge_input_hashes(list(list(c1='h1'),list(c1='h1',c2='h2'))),list(c1='h1',c2='h2')))
ok('matching input hashes merged')
# A duplicate that differs must stop the merge: copy B, alter one duplicated 2D Ada
# result consistently (rehash its manifest), then combine.
fixture<-file.path(out,'B-altered');dir.create(fixture)
stopifnot(all(file.copy(list.files(B,full.names=TRUE),fixture,recursive=TRUE)))
job<-dups$job[1];path<-file.path(fixture,'results',paste0(job,'.rds'))
obj<-readRDS(path);obj$value$rng_final[3]<-obj$value$rng_final[3]+1L
saveRDS(obj,path,version=3,compress='gzip')
saveRDS(list(identity=obj$identity,bytes=file.info(path)$size,sha256=study_hash_file(path)),paste0(path,'.manifest.rds'))
fails(study_combine(c(A,fixture),'ulsif'),'Duplicate job differs','differing duplicate rejected')
cat('Combined-summary checks passed.\n')
