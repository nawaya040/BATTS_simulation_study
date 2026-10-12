# Rebuild the manuscript simulation figures from the final combined summary.
# Step 1 converts verified results into the original drawing inputs; step 2
# runs the drawing scripts in draw/, copied verbatim from the Round 2 package,
# so typography, colours and geometry are unchanged. Final PDFs are copied to
# final/ under the manuscript file names.
# Example (library with ggplot2 4.0.3 and patchwork 1.3.2 first on the path):
#   Rscript scripts/figures/paper/make_paper_figures.R
#     --summary-dir=SUMMARY --output-dir=NEW_DIR
args<-commandArgs(TRUE)
arg<-function(name) {
  hit<-grep(paste0('^--',name,'='),args,value=TRUE)
  if(length(hit)!=1L) stop('Missing --',name)
  sub(paste0('^--',name,'='),'',hit)
}
script<-normalizePath(sub('^--file=','',grep('^--file=',commandArgs(FALSE),value=TRUE)[1]),winslash='/')
here<-dirname(script); repo<-normalizePath(file.path(here,'../../..'),winslash='/')
summary_dir<-normalizePath(arg('summary-dir'),winslash='/',mustWork=TRUE)
out<-arg('output-dir')
if(dir.exists(out)||file.exists(out)) stop('Output directory must be new')
# The drawing scripts reproduce the submitted figures pixel for pixel with these versions.
expected<-c(ggplot2='4.0.3',patchwork='1.3.2')
found<-vapply(names(expected),function(p) as.character(utils::packageVersion(p)),'')
if(!identical(unname(found),unname(expected))) stop('Drawing package versions differ: ',paste(names(found),found,collapse=', '))
dir.create(out,recursive=TRUE); out<-normalizePath(out,winslash='/')
started<-Sys.time()
rscript<-file.path(R.home('bin'),'Rscript')
run<-function(...) {
  status<-system2(rscript,c('--vanilla',...))
  if(!identical(status,0L)) stop('Step failed: ',paste(...,collapse=' '))
}
draw<-function(name) file.path(here,'draw',name)
inputs<-file.path(out,'inputs')
run(file.path(here,'prepare_paper_figure_inputs.R'),paste0('--summary-dir=',summary_dir),paste0('--output-dir=',inputs))
for(preset in c('balanced-sample-size','unbalanced-sample-size')) {
  d<-file.path(out,paste0('figure1_',preset)); dir.create(d)
  run(draw('plot_figure1_r2_preview.R'),paste0('--results-root=',file.path(inputs,'one_dimensional')),
    paste0('--png-output=',file.path(d,'figure1.png')),paste0('--pdf-output=',file.path(d,'figure1.pdf')),
    paste0('--setting-preset=',preset))
}
run(draw('plot_figure4_compact_preview.R'),file.path(inputs,'global_null'),file.path(inputs,'coverage'),file.path(out,'figure20d_calibration'))
run(draw('plot_figure5.R'),file.path(inputs,'pointwise_20d','figure_20d_pointwise_summary.csv'),file.path(out,'figure20d_pointwise'))
run(draw('plot_supplement_s1.R'),paste0('--input-root=',file.path(inputs,'supplement_s1')),paste0('--output-dir=',file.path(out,'supplement_s1')))
run(draw('plot_eight_panel_equal_size_release.R'),file.path(inputs,'surfaces','figure3_plotted_data.rds'),
  file.path(inputs,'surfaces'),file.path(out,'surfaces'))
run(draw('plot_supplement_s4.R'),file.path(inputs,'coverage'),file.path(out,'supplement_s4'))

final<-c(
  figure1_r2_balanced_sample_size.pdf='figure1_balanced-sample-size/figure1.pdf',
  figureS6_1d_unbalanced_sample_size_r2.pdf='figure1_unbalanced-sample-size/figure1.pdf',
  figure3_compact_r2.pdf='surfaces/figure3.pdf',
  figure20d_calibration_compact_r2.pdf='figure20d_calibration/figure4_compact.pdf',
  figure20d_pointwise_evaluation_compact_r2.pdf='figure20d_pointwise/figure5_compact.pdf',
  figureS1_r2.pdf='supplement_s1/supplement_s1.pdf',
  figureS2_global_shift_balanced_compact_r2.pdf='surfaces/s2_global_shift_balanced.pdf',
  figureS2_local_dispersion_balanced_compact_r2.pdf='surfaces/s2_local_dispersion_balanced.pdf',
  figureS3_global_shift_unbalanced_compact_r2.pdf='surfaces/s3_global_shift_unbalanced.pdf',
  figureS3_local_shift_unbalanced_compact_r2.pdf='surfaces/s3_local_shift_unbalanced.pdf',
  figureS3_local_dispersion_unbalanced_compact_r2.pdf='surfaces/s3_local_dispersion_unbalanced.pdf',
  figureS4_compact_r2.pdf='supplement_s4/figureS4_compact.pdf',
  figureS5_latent_location_compact_r2.pdf='surfaces/s5_latent_location_balanced.pdf')
dir.create(file.path(out,'final'))
stopifnot(all(file.copy(file.path(out,final),file.path(out,'final',names(final)))))
sha<-function(path) tolower(unname(tools::sha256sum(path)))
git<-function(...) tryCatch(system2('git',c('-C',repo,...),stdout=TRUE),error=function(e) NA_character_)
packages<-c('ggplot2','patchwork','scales','gtable','grid')
writeLines(c(paste0('created_utc=',format(Sys.time(),tz='UTC')),
  paste0('elapsed_seconds=',round(as.numeric(difftime(Sys.time(),started,units='secs')),1)),
  paste0('summary_dir=',summary_dir),paste0('summary_manifest_sha256=',sha(file.path(summary_dir,'summary-manifest.rds'))),
  paste0('repository_commit=',git('rev-parse','HEAD')),
  paste0('repository_dirty=',length(git('status','--porcelain'))>0L),
  paste0('R=',R.version.string),paste0('platform=',R.version$platform),
  paste0('package_',packages,'=',vapply(packages,function(p) as.character(utils::packageVersion(p)),'')),
  paste0('library_paths=',paste(.libPaths(),collapse=';')),
  paste0('script_sha256_',basename(c(script,file.path(here,'prepare_paper_figure_inputs.R'),list.files(file.path(here,'draw'),full.names=TRUE))),'=',
    sha(c(script,file.path(here,'prepare_paper_figure_inputs.R'),list.files(file.path(here,'draw'),full.names=TRUE)))),
  paste0('output_sha256_',names(final),'=',sha(file.path(out,'final',names(final))))),
  file.path(out,'manifest.txt'))
cat('Paper figures written to',file.path(out,'final'),'\n')
