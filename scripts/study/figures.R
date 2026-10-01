# Scientific diagnostic figures from validated results only. No estimators run here.
study_figures <- function(checked,path) {
  if(file.exists(path)) stop('Refusing to overwrite figure')
  grDevices::pdf(path,width=11,height=8,onefile=TRUE)
  on.exit(grDevices::dev.off())
  status<-paste(checked$run$identity$config$status,if(checked$complete) 'complete grid' else 'partial grid')
  case<-''
  label_page<-function() {
    if(all(par('mfg')[1:2]==c(1,1))) mtext(paste(status,case),outer=TRUE,cex=.65)
  }
  draw_surface<-function(x,y,z,title,limits=NULL) {
    good<-is.finite(z)
    if(!any(good)) {plot.new();title(main=paste(title,'(no finite estimates)'));label_page();return()}
    if(is.null(limits)) limits<-range(z[good]); span<-diff(limits)
    col<-rep('grey80',length(z)); pal<-grDevices::hcl.colors(100,'Blue-Red 3')
    col[good]<-pal[pmax(1,pmin(100,1+floor(99*(z[good]-limits[1])/max(span,1e-12))))]
    plot(x,y,col=col,pch=16,cex=.5,xlab='coordinate 1',ylab='coordinate 2',main=title)
    legend('topright',legend=format(limits,digits=3),col=pal[c(1,100)],pch=16,bty='n')
    label_page()
  }
  for(case in names(checked$inputs)) {
    records<-Filter(function(z) z$row$case==case,checked$records)
    row<-records[[1]]$row
    if(!row$seed%in%checked$run$identity$config$detail_seeds) next
    sim<-checked$inputs[[case]]$simulation
    par(mfrow=c(2,3),oma=c(0,0,3,0),mar=c(4,4,3,1))
    if(startsWith(row$family,'1d')) {
      plot(sim$data,sim$true_log_w_obs,pch=16,cex=.5,xlab='x',ylab='log p/q',main='Truth at observations');label_page()
    } else {
      coords<-if(!is.null(sim$data_u)) sim$data_u else if(!is.null(sim$latent)) sim$latent else sim$data
      plot(coords[,1],coords[,2],col=sim$group_labels+1,pch=16,cex=.5,
           xlab='coordinate 1',ylab='coordinate 2',main='Generated groups');label_page()
      draw_surface(coords[,1],coords[,2],sim$true_log_w_obs,'True log density ratio')
    }
    for(rec in records) {
      z<-rec$value; estimate<-if(rec$row$method=='ada') z$estimates$exponential_loss else z$estimates[[1]]
      if(startsWith(row$family,'1d')) {
        orderx<-order(sim$data[,1]);plot(sim$data[,1],estimate,pch=16,cex=.4,
          xlab='x',ylab='log p/q',main=rec$row$method);label_page()
        lines(sim$data[orderx,1],sim$true_log_w_obs[orderx],col=2)
        if(!is.null(z$quantiles)) {
          lines(sim$data[orderx,1],z$quantiles[orderx,1],col=4,lty=2)
          lines(sim$data[orderx,1],z$quantiles[orderx,3],col=4,lty=2)
        }
        if(rec$row$method=='ada_gb_fixed') {
          plot(z$grid$points,z$grid$truth,type='l',xlab='x',ylab='log p/q',main='Fixed 100-tree comparison');label_page()
          lines(z$grid$points,z$grid$ada,col=2);lines(z$grid$points,z$grid$gb,col=4)
          legend('topright',c('Truth','Ada DRT','GB'),col=c(1,2,4),lty=1,bty='n')
        }
        if(!is.null(z$tau_inverse)) {
          hist(z$tau_inverse,main='Inverse temperature',xlab='1 / omega');label_page()
          # Bhattacharyya coefficient of N(0,1) and N(1,1.5^2).
          abline(v=sqrt(2*1*1.5/(1+1.5^2))*exp(-1/(4*(1+1.5^2))),col=2,lwd=2)
        }
      } else draw_surface(coords[,1],coords[,2],estimate,rec$row$method)
      if(!is.null(z$quantiles)&&!startsWith(row$family,'1d')) {
        draw_surface(coords[,1],coords[,2],z$quantiles[,1],'BAT lower 2.5%')
        draw_surface(coords[,1],coords[,2],z$quantiles[,3],'BAT upper 97.5%')
        direction<-ifelse(z$quantiles[,1]>0,1,ifelse(z$quantiles[,3]<0,-1,0))
        draw_surface(coords[,1],coords[,2],direction,'BAT 95% interval excludes zero',c(-1,1))
      }
    }
  }
  bats<-Filter(function(z)z$row$method=='bat',checked$records)
  groups<-split(bats,vapply(bats,function(z)sub('_s-[0-9]+$','',z$row$case),character(1)))
  par(mfrow=c(2,2),oma=c(0,0,3,0),mar=c(4,4,3,1))
  for(name in names(groups)) {
    case<-paste('Coverage',name)
    group<-groups[[name]];nominal<-group[[1]]$value$coverage$nominal_mass
    rate<-rowMeans(do.call(cbind,lapply(group,function(z)z$value$coverage$coverage_rate_BAT)))
    plot(nominal,rate,type='l',xlim=c(0,1),ylim=c(0,1),xlab='Nominal level',ylab='Coverage',main=name,cex.main=.65);label_page()
    abline(0,1,lty=2);mtext(paste(status,'; completed seeds',length(group)),cex=.6)
  }
}
