# Draw training-only diagnostics and planned contrasts from fitted objects.
source("scripts/09_fit_training_models.R")
if(!requireNamespace("ggplot2",quietly=TRUE)) stop("Install ggplot2 for diagnostics.")
library(ggplot2)
dir.create("figures/modeling",recursive=TRUE,showWarnings=FALSE)
model_theme<-theme_minimal(base_size=11)+theme(panel.grid.minor=element_blank(),
  plot.title=element_text(face="bold",size=15),plot.subtitle=element_text(size=10),
  plot.caption=element_text(hjust=0,size=8),plot.margin=margin(12,14,12,12),legend.position="top")
open_png<-function(path,w,h){
  if(requireNamespace("ragg",quietly=TRUE))ragg::agg_png(path,width=w,height=h,units="in",res=180)
  else png(path,width=w,height=h,units="in",res=180)
}
save_model_plot<-function(p,path,w=10,h=7){open_png(path,w,h);print(p);dev.off()}
save_grid<-function(plots,path,w=12,h=9){
  open_png(path,w,h);grid::grid.newpage();grid::pushViewport(grid::viewport(layout=grid::grid.layout(2,2)))
  for(i in seq_along(plots)) print(plots[[i]],vp=grid::viewport(layout.pos.row=ceiling(i/2),layout.pos.col=(i-1)%%2+1))
  dev.off()
}
diag_plots<-function(f,data,label,path){
  a<-data.frame(fitted=fitted(f),residual=resid(f),standardized=rstandard(f),
     leverage=hatvalues(f),Cook=cooks.distance(f),index=seq_len(nrow(data)))
  # Equal-frequency fitted-value bins show empirical residual centers, not a fitted model.
  a$bin<-pmin(20,ceiling(rank(a$fitted,ties.method="first")/nrow(a)*20))
  bin<-aggregate(cbind(fitted,residual)~bin,a,mean)
  p1<-ggplot(a,aes(fitted,residual))+geom_point(alpha=.10,size=.5,color="#287B85")+
    geom_hline(yintercept=0,lty=2,color="#666666")+geom_line(data=bin,color="#B56830",linewidth=.9)+
    labs(title=paste(label,"Residuals versus fitted"),x="Fitted natural-log price",y="Residual (log-price units)",
      caption="Inside Airbnb NYC 2026-09-14; training only.\nOrange line: means in 20 fitted-value bins.")+model_theme
  probs<-ppoints(nrow(a));q<-data.frame(theoretical=qnorm(probs),observed=sort(a$standardized))
  qr<-quantile(a$standardized,c(.25,.75));slope<-diff(qr)/diff(qnorm(c(.25,.75)));intercept<-qr[1]-slope*qnorm(.25)
  p2<-ggplot(q,aes(theoretical,observed))+geom_point(alpha=.4,size=.6,color="#287B85")+
    geom_abline(slope=slope,intercept=intercept,color="#B56830")+
    labs(title="Normal Q-Q diagnostic",x="Standard normal quantile",y="Standardized residual quantile",
      caption="Line through first and third quartiles. Training residuals.")+model_theme
  a$root_abs_std<-sqrt(abs(a$standardized));sc<-aggregate(cbind(fitted,root_abs_std)~bin,a,mean)
  p3<-ggplot(a,aes(fitted,root_abs_std))+geom_point(alpha=.10,size=.5,color="#287B85")+
    geom_line(data=sc,color="#B56830",linewidth=.9)+labs(title="Scale-location diagnostic",x="Fitted natural-log price",
      y="Square root of absolute standardized residual",caption="Orange line: binned means; uneven scale can indicate heteroskedasticity.")+model_theme
  p4<-ggplot(a,aes(index,Cook))+geom_segment(aes(xend=index,yend=0),linewidth=.2,color="#287B85")+
    geom_hline(yintercept=4/nrow(a),lty=2,color="#B56830")+labs(title="Case influence",x="Training observation index",y="Cook's distance",
      caption="Dashed line: 4/n review threshold, not an automatic deletion rule.")+model_theme
  save_grid(list(p1,p2,p3,p4),path)
  invisible(a)
}
diag_plots(focal,train,"M2", "figures/modeling/01_M2_diagnostics.png")
group_bin<-function(variable){
  g<-diagnostic_rows;g$value<-g[[variable]]
  z<-aggregate(cbind(residual,standardized_residual)~borough+room_type+value,g,mean)
  n<-aggregate(residual~borough+room_type+value,g,length);names(n)[4]<-"n"
  merge(z,n,by=c("borough","room_type","value"))
}
cap_res<-group_bin("accommodates")
write_model_csv(cap_res,"M2_residual_by_capacity.csv")
p_cap<-ggplot(subset(cap_res,n>=20),aes(value,residual,color=room_type))+geom_hline(yintercept=0,lty=2)+
  geom_line()+geom_point(aes(size=n),alpha=.8)+facet_wrap(~borough)+
  scale_color_manual(values=c("Private room"="#B56830","Entire home/apt"="#287B85"))+
  labs(title="M2 mean residuals across guest capacities",subtitle="Each point is a training-group mean; only cells with at least 20 records are connected",
    x="Guest capacity (persons)",y="Mean residual (log-price units)",color=NULL,size="Cell n",
    caption="Source: fixed Inside Airbnb NYC snapshot; saved training partition only. A systematic pattern suggests remaining mean-form error.")+model_theme
save_model_plot(p_cap,"figures/modeling/02_M2_residual_capacity.png")
f<-contrasts;f$contrast<-factor(f$contrast,levels=rev(unique(f$contrast)))
p_effect<-ggplot(f,aes(pct_difference,contrast,color=analysis))+
  geom_vline(xintercept=0,lty=2,color="#888888")+
  geom_errorbar(aes(xmin=pct_ci_lower,xmax=pct_ci_upper),orientation="y",width=.18,position=position_dodge(width=.5))+
  geom_point(position=position_dodge(width=.5),size=2.4)+
  scale_color_manual(values=c("Primary M2"="#287B85","M2 without hotel labels"="#B56830"))+
  labs(title="Adjusted price associations under the starting M2 specification",
    subtitle="Training-only estimates; pointwise 95% intervals use host-cluster HC1 covariance",
    x="Difference in conditional geometric-mean price (%)",y=NULL,color=NULL,
    caption="Inside Airbnb NYC 2026-09-14; training only. Associations, not causal effects or arithmetic-mean price changes.\nThe sensitivity subset changes the target population; intervals are not simultaneous. Final specification remains under review.")+model_theme
save_model_plot(p_effect,"figures/modeling/03_M2_adjusted_contrasts.png",12,6)
message("Generated starting-model training diagnostics; inspect before freezing a final model.")
