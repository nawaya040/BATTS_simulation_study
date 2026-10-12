# Convert the final combined study results into the intermediate inputs read by
# the verbatim manuscript drawing scripts in draw/. Display-only: no estimator
# is refitted. Random numbers are used only to restore each displayed data
# set's saved post-data RNG state, as the original plots did after regenerating
# the data, so that scatter points are drawn in the original order.
# Example:
#   Rscript scripts/figures/paper/prepare_paper_figure_inputs.R
#     --summary-dir=SUMMARY --output-dir=NEW_DIR
args<-commandArgs(TRUE)
arg<-function(name) {
  hit<-grep(paste0('^--',name,'='),args,value=TRUE)
  if(length(hit)!=1L) stop('Missing --',name)
  sub(paste0('^--',name,'='),'',hit)
}
summary_dir<-normalizePath(arg('summary-dir'),winslash='/',mustWork=TRUE)
out<-arg('output-dir')
if(dir.exists(out)||file.exists(out)) stop('Output directory must be new')
dir.create(out,recursive=TRUE)
out<-normalizePath(out,winslash='/')
sha<-function(path) tolower(unname(tools::sha256sum(path)))
read_log<-list()
note_read<-function(path,kind) read_log[[length(read_log)+1L]]<<-data.frame(kind=kind,
  path=normalizePath(path,winslash='/'),sha256=sha(path),stringsAsFactors=FALSE)

# Combined summary: job-to-root map and verified result hashes.
manifest_path<-file.path(summary_dir,'summary-manifest.rds')
manifest<-readRDS(manifest_path); note_read(manifest_path,'summary_manifest')
if(!identical(manifest$status,'CANONICAL')||!isTRUE(manifest$full_grid_complete)) stop('Summary is not a complete canonical summary')
source_map<-manifest$combined$source; result_hashes<-manifest$input_hashes
summary_csv<-function(name) {
  path<-file.path(summary_dir,name)
  if(!identical(sha(path),manifest$output_hashes[[name]])) stop('Summary file hash mismatch: ',name)
  note_read(path,'summary_csv'); utils::read.csv(path,stringsAsFactors=FALSE)
}
case_id<-function(family,scenario,n0,n1,seed,transformed=FALSE)
  sprintf('%s_%s_n0-%d_n1-%d_t-%s_s-%03d',family,scenario,n0,n1,if(transformed) 'TRUE' else 'FALSE',seed)
read_job<-function(case,method) {
  job<-paste0(case,'__',method); root<-source_map[[job]]
  if(is.null(root)) stop('Job absent from combined summary: ',job)
  path<-file.path(root,'results',paste0(job,'.rds'))
  if(!identical(sha(path),result_hashes[[job]])) stop('Result hash mismatch: ',job)
  note_read(path,'result'); x<-readRDS(path)
  if(!identical(x$identity$job,job)) stop('Result identity mismatch: ',job)
  x$value$input_hash<-x$identity$input_hash; x$value$root<-root; x$value
}
read_input<-function(case,result) {
  path<-file.path(result$root,'inputs',paste0(case,'.rds'))
  recorded<-readRDS(paste0(path,'.manifest.rds'))
  if(!identical(sha(path),recorded$sha256)) stop('Input hash mismatch: ',case)
  note_read(path,'input'); x<-readRDS(path)
  if(!identical(x$identity$case,case)||!identical(x$value$hash,result$input_hash))
    stop('Input identity mismatch: ',case)
  x$value
}
finite_vector<-function(x,n,label) {
  x<-as.numeric(x)
  if(length(x)!=n||any(!is.finite(x))) stop('Invalid vector: ',label)
  x
}

# ---- Coverage summaries (main 20D calibration figure and S4) ----------------
coverage<-summary_csv('coverage-per-seed.csv')
coverage<-coverage[coverage$method=='bat',]
coverage$nominal_mass<-round(coverage$nominal,2L)
dir.create(file.path(out,'global_null')); dir.create(file.path(out,'coverage'))
gn<-coverage[coverage$family=='20d'&!coverage$transformed&coverage$scenario%in%c('global_shift','null'),]
utils::write.csv(data.frame(scenario=gn$scenario,n0=gn$n0,n1=gn$n1,seed=gn$seed,group='all',
  nominal_level=gn$nominal_mass,empirical_coverage=gn$coverage,n=gn$n0+gn$n1),
  file.path(out,'global_null','seed_calibration_curves.csv'),row.names=FALSE)
keep<-(coverage$family=='2d')|(coverage$family=='20d'&!coverage$transformed&
  coverage$scenario%in%c('latent_location_shift','latent_dispersion'))
cs<-coverage[keep,]
cs<-data.frame(family=cs$family,scenario=cs$scenario,n0=cs$n0,n1=cs$n1,
  representation=ifelse(cs$family=='2d','not_applicable','raw'),seed=cs$seed,
  nominal_mass=cs$nominal_mass,group='all_pooled',coverage=cs$coverage,stringsAsFactors=FALSE)
utils::write.csv(cs,file.path(out,'coverage','coverage_by_seed.csv'),row.names=FALSE)
cm<-stats::aggregate(coverage~family+scenario+n0+n1+representation+group+nominal_mass,data=cs,
  FUN=function(x) c(n_seeds=length(x),mean_coverage=mean(x)))
cm<-data.frame(cm[c('family','scenario','n0','n1','representation','group','nominal_mass')],
  n_seeds=as.integer(cm$coverage[,'n_seeds']),mean_coverage=cm$coverage[,'mean_coverage'])
utils::write.csv(cm,file.path(out,'coverage','coverage_by_nominal_mass.csv'),row.names=FALSE)
writeLines(c(paste0('source=',normalizePath(file.path(summary_dir,'coverage-per-seed.csv'),winslash='/')),
  'all_pooled=unweighted mean across all observations (coverage_rate_BAT)',
  'seeds_per_cell=50','nominal_masses=0.01 through 0.99'),
  file.path(out,'coverage','summary_metadata.txt'))

# ---- One-dimensional BAT (main Figure 1 and the unbalanced supplement) ------
settings_1d<-list(c(500L,500L),c(100L,900L),c(2500L,2500L),c(500L,4500L))
quant_probs<-seq(0.005,0.995,by=0.005)
c_probs<-round(1-quant_probs[seq_len(99L)]*2,2L)
root_1d<-file.path(out,'one_dimensional'); dir.create(file.path(root_1d,'coverage'),recursive=TRUE)
dir.create(file.path(root_1d,'illustration'))
coverage_1d<-array(NA_real_,c(length(settings_1d),99L,50L))
for(k in seq_along(settings_1d)) {
  s<-settings_1d[[k]]
  for(seed in 1:50) {
    case<-case_id('1d','normal',s[1],s[2],seed); v<-read_job(case,'bat')
    nominal<-round(v$coverage$nominal_mass,2L)
    coverage_1d[k,,seed]<-v$coverage$coverage_rate_BAT[match(c_probs,nominal)]
    if(seed==1L) {
      g<-v$grid
      if(is.null(g)||!all(g$inside)) stop('Seed-1 1D grid is missing or partly outside the domain')
      input<-read_input(case,v)
      truth<-as.numeric(input$simulation$true_log_w_grid)
      if(max(abs(truth-as.numeric(g$truth)))>0) stop('1D grid truth mismatch')
      cis<-t(g$quantiles); rownames(cis)<-c('2.5%','50%','97.5%')
      saveRDS(list(log_ratio_grid_post_mean=as.numeric(g$mean),log_ratio_grid_true=truth,
        tau_inv_result=v$tau_inverse,CIs=cis,grid_points=as.numeric(g$points)),
        file.path(root_1d,'illustration',sprintf('illustration_%d_%d.rds',s[1],s[2])))
    }
  }
}
if(any(!is.finite(coverage_1d))) stop('1D coverage is incomplete')
for(seed in 1:50) saveRDS(coverage_1d[,,seed],file.path(root_1d,'coverage',sprintf('coverage_%d.rds',seed)))
writeLines(deparse(list(mode='full',mu0=0,mu1=1,sig20=1,sig21=2.25,quant_probs=quant_probs,
  n_repeat=50L,grid_points=seq(-2.5,3.5,length.out=100),settings=settings_1d)),
  file.path(root_1d,'config.dput'))

# ---- One-dimensional fixed-tree DRT/GB comparison (S1) ----------------------
root_s1<-file.path(out,'supplement_s1'); dir.create(root_s1)
grid_s1<-seq(-2.5,3.5,length.out=100L)
for(s in list(c(500L,500L),c(300L,700L),c(200L,800L),c(100L,900L))) for(seed in 1:50) {
  v<-read_job(case_id('1d_fixed','normal',s[1],s[2],seed),'ada_gb_fixed')
  g<-v$grid
  if(max(abs(as.numeric(g$points)-grid_s1))>1e-12||!all(g$inside)||v$fixed_settings$num_trees!=100L)
    stop('Unexpected S1 grid or settings')
  # grid ada = log(p0/p1*n1/n0), so p0 is recovered exactly up to rounding.
  p0<-stats::plogis(as.numeric(g$ada)+log(s[1]/s[2]))
  saveRDS(list(num_trees_selected=100,log_w_hat_ada_grid=as.numeric(g$ada),prob_pred_grid=cbind(p0,1-p0)),
    file.path(root_s1,sprintf('Adaboost_%d_%d_%d.rds',s[1],s[2],seed)))
  saveRDS(as.numeric(g$gb),file.path(root_s1,sprintf('Proposed_%d_%d_%d.rds',s[1],s[2],seed)))
}

# ---- 2D/20D estimated surfaces (Figure 3, S2/S3, S5) ------------------------
palette_colours<-c('darkblue','blue','blue','deepskyblue','cyan','#7FFFFF',
  'white','white','white','#FFFF99','yellow','orange','red','red','darkred')
surface<-function(family,scenario,n0,n1,seed,threshold,latent) {
  case<-case_id(family,scenario,n0,n1,seed); n<-n0+n1
  bat<-read_job(case,'bat'); input<-read_input(case,bat); sim<-input$simulation
  est<-function(method,field='primary') {
    v<-read_job(case,method)
    if(!identical(v$input_hash,bat$input_hash)) stop('Input hash differs between methods: ',case)
    finite_vector(v$estimates[[field]],n,paste(case,method))
  }
  truth<-finite_vector(sim$true_log_w_obs,n,'truth')
  values<-list('Truth'=truth,'DRT (AdaBoost)'=est('ada','exponential_loss'),
    'KLIEP'=est('kliep'),'uLSIF'=est('ulsif'),'GB'=est('gb'),
    'Bayesian additive trees'=finite_vector(bat$estimates$primary,n,'BAT mean'),
    'Lower (2.5%)'=finite_vector(bat$quantiles[,1L],n,'BAT lower'),
    'Upper (97.5%)'=finite_vector(bat$quantiles[,3L],n,'BAT upper'))
  if(any(values[[7L]]>values[[8L]])) stop('BAT quantile order failure: ',case)
  # Same display rule as the original scripts; the GB estimate on display is
  # now also the scale reference (previously the Round 1 GB estimate).
  min_true<-min(truth); max_true<-max(truth); min_est<-min(values$GB); max_est<-max(values$GB)
  min_display<-min((min_true+min_est)/2,-threshold); max_display<-max((max_true+max_est)/2,threshold)
  min_palette<-min(min_true,min_est,-threshold)-1e-10; max_palette<-max(max_true,max_est,threshold)+1e-10
  positions<-scales::rescale(c(min_palette,min_display,min_display*8/10,min_display*6/10,
    min_display*4/10,min_display*2/10,min_display*1/10,0,max_display*1/10,max_display*2/10,
    max_display*4/10,max_display*6/10,max_display*8/10,max_display,max_palette))
  coordinates<-if(latent) as.matrix(sim$data_u) else as.matrix(sim$data)
  axes<-if(latent) c('z1','z2') else c('x1','x2')
  plot_data<-do.call(rbind,lapply(names(values),function(method) {
    d<-data.frame(coordinates[,1L],coordinates[,2L],log_weight=values[[method]],method=method)
    names(d)[1:2]<-axes; d
  }))
  plot_data$method<-factor(plot_data$method,levels=names(values))
  assign('.Random.seed',input$rng_after_data,envir=globalenv())
  plot_data<-plot_data[sample.int(nrow(plot_data)),,drop=FALSE]
  pad<-function(x) { r<-range(x); r+c(-1,1)*diff(r)*.04 }
  list(data=plot_data,xlim=pad(coordinates[,1L]),ylim=pad(coordinates[,2L]),colours=palette_colours,
    positions=positions,limits=c(min_display,max_display),axes=axes,
    xlab=if(latent) expression(z[1]) else expression(x[1]),
    ylab=if(latent) expression(z[2]) else expression(x[2]),case=case)
}
RNGkind('Mersenne-Twister','Inversion','Rejection')
root_surface<-file.path(out,'surfaces'); dir.create(root_surface)
fig3<-surface('2d','local_shift',5000L,5000L,1L,.55,FALSE)
saveRDS(list(plot_data=fig3$data,axis_limits=list(x=fig3$xlim,y=fig3$ylim),palette_colours=fig3$colours,
  palette_locations=fig3$positions,limits=fig3$limits,case=fig3$case),file.path(root_surface,'figure3_plotted_data.rds'))
supplement<-list(
  s2_global_shift_balanced=list('2d','global_shift',5000L,5000L,1L,.55,FALSE),
  s2_local_dispersion_balanced=list('2d','local_dispersion',5000L,5000L,21L,.55,FALSE),
  s3_global_shift_unbalanced=list('2d','global_shift',9000L,1000L,1L,.55,FALSE),
  s3_local_shift_unbalanced=list('2d','local_shift',9000L,1000L,16L,.55,FALSE),
  s3_local_dispersion_unbalanced=list('2d','local_dispersion',9000L,1000L,16L,.55,FALSE),
  s5_latent_location_balanced=list('20d','latent_location_shift',5000L,5000L,21L,.5,TRUE))
for(id in names(supplement))
  saveRDS(do.call(surface,supplement[[id]]),file.path(root_surface,paste0(id,'_plotted_data.rds')))

# ---- 20D pointwise evaluation (all 50 repeats) -----------------------------
bin_plot_values<-seq(0,2.5,by=.25)
bin_breaks<-c(0,(head(bin_plot_values,-1L)+tail(bin_plot_values,-1L))/2,Inf)
bin_labels<-c(sprintf('[%.3f,%.3f)',head(bin_breaks,-2L),bin_breaks[2:(length(bin_breaks)-1L)]),
  sprintf('[%.3f,Inf)',bin_breaks[[length(bin_breaks)-1L]]))
settings_20d<-list(
  list(id='global_balanced',scenario='global_shift',label='Global Shift',balance='balanced',n0=5000L,n1=5000L),
  list(id='location_balanced',scenario='latent_location_shift',label='Location Shift',balance='balanced',n0=5000L,n1=5000L),
  list(id='dispersion_balanced',scenario='latent_dispersion',label='Dispersion',balance='balanced',n0=5000L,n1=5000L),
  list(id='global_unbalanced',scenario='global_shift',label='Global Shift',balance='unbalanced',n0=9000L,n1=1000L),
  list(id='location_unbalanced',scenario='latent_location_shift',label='Location Shift',balance='unbalanced',n0=9000L,n1=1000L),
  list(id='dispersion_unbalanced',scenario='latent_dispersion',label='Dispersion',balance='unbalanced',n0=9000L,n1=1000L))
weighted_rate<-function(indicator,weights,indices) {
  if(!length(indices)) return(NA_real_)
  sum(weights[indices]*indicator[indices])/sum(weights[indices])
}
repeat_rows<-list(); coverage_check<-list()
for(setting in settings_20d) {
  weights<-c(rep(.5/setting$n0,setting$n0),rep(.5/setting$n1,setting$n1))
  for(seed in 1:50) {
    case<-case_id('20d',setting$scenario,setting$n0,setting$n1,seed)
    bat<-read_job(case,'bat'); sim<-read_input(case,bat)$simulation
    n<-setting$n0+setting$n1
    if(!identical(as.integer(sim$group_labels),c(rep(0L,setting$n0),rep(1L,setting$n1)))) stop('Unexpected group order: ',case)
    truth<-finite_vector(sim$true_log_w_obs,n,'truth')
    lower<-finite_vector(bat$quantiles[,1L],n,'lower'); upper<-finite_vector(bat$quantiles[,3L],n,'upper')
    if(any(lower>upper)) stop('Invalid interval: ',case)
    covered<-lower<truth&truth<upper
    correct<-(truth>0&lower>0)|(truth<0&upper<0)
    wrong<-(truth>0&upper<0)|(truth<0&lower>0)
    bins<-cut(abs(truth),breaks=bin_breaks,labels=FALSE,right=FALSE,include.lowest=TRUE)
    if(anyNA(bins)) stop('Failed to assign an absolute-effect bin')
    k95<-which(abs(bat$coverage$nominal_mass-.95)<1e-9)
    coverage_check[[length(coverage_check)+1L]]<-c(saved=unname(bat$coverage$coverage_rate_BAT[k95]),
      recomputed=mean(bat$coverage$is_included_mat[k95,]))
    for(bin_id in seq_along(bin_plot_values)) {
      indices<-which(bins==bin_id)
      repeat_rows[[length(repeat_rows)+1L]]<-data.frame(setting_id=setting$id,scenario=setting$label,
        balance=setting$balance,n0=setting$n0,n1=setting$n1,simulation_repeat=seed,bin_id=bin_id,
        bin_label=bin_labels[[bin_id]],plot_value=bin_plot_values[[bin_id]],n_points=length(indices),
        coverage_rate=weighted_rate(covered,weights,indices),
        correct_detection_rate=weighted_rate(correct,weights,indices),
        wrong_direction_rate=weighted_rate(wrong,weights,indices),stringsAsFactors=FALSE)
    }
  }
}
coverage_check<-do.call(rbind,coverage_check)
if(max(abs(coverage_check[,'saved']-coverage_check[,'recomputed']))>1e-12) stop('Saved 95% coverage differs from its inclusion matrix')
repeat_data<-do.call(rbind,repeat_rows)
summarize_metric<-function(values) {
  values<-values[is.finite(values)]
  if(!length(values)) return(c(mean=NA_real_,q10=NA_real_,q90=NA_real_,n=0))
  c(mean=mean(values),q10=unname(stats::quantile(values,.10,type=7)),
    q90=unname(stats::quantile(values,.90,type=7)),n=length(values))
}
summary_rows<-lapply(split(repeat_data,interaction(repeat_data$setting_id,repeat_data$bin_id,drop=TRUE)),function(cell) {
  cov<-summarize_metric(cell$coverage_rate); cor<-summarize_metric(cell$correct_detection_rate)
  wro<-summarize_metric(cell$wrong_direction_rate)
  data.frame(cell[1L,c('setting_id','scenario','balance','n0','n1','bin_id','bin_label','plot_value')],
    mean_coverage_rate=cov[['mean']],q10_coverage_rate=cov[['q10']],q90_coverage_rate=cov[['q90']],
    n_coverage_repeats=as.integer(cov[['n']]),mean_correct_detection_rate=cor[['mean']],
    q10_correct_detection_rate=cor[['q10']],q90_correct_detection_rate=cor[['q90']],
    n_correct_repeats=as.integer(cor[['n']]),mean_wrong_direction_rate=wro[['mean']],
    q10_wrong_direction_rate=wro[['q10']],q90_wrong_direction_rate=wro[['q90']],
    n_wrong_repeats=as.integer(wro[['n']]),stringsAsFactors=FALSE)
})
summary_data<-do.call(rbind,summary_rows)
summary_data<-summary_data[order(match(summary_data$setting_id,vapply(settings_20d,`[[`,'','id')),summary_data$bin_id),,drop=FALSE]
rownames(summary_data)<-NULL
dir.create(file.path(out,'pointwise_20d'))
utils::write.csv(repeat_data,file.path(out,'pointwise_20d','repeat_rates.csv'),row.names=FALSE)
utils::write.csv(summary_data,file.path(out,'pointwise_20d','figure_20d_pointwise_summary.csv'),row.names=FALSE)

# ---- Record what was read ---------------------------------------------------
reads<-unique(do.call(rbind,read_log))
utils::write.csv(reads,file.path(out,'read_manifest.csv'),row.names=FALSE)
cat('Prepared figure inputs in',out,'from',nrow(reads),'verified files\n')
