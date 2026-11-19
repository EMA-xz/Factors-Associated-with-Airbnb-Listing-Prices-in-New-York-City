source("scripts/12_training_report.R")
source("config/completion_review.R")
dir.create("reports/final_analysis",recursive=TRUE,showWarnings=FALSE)
dir.create("figures/final",recursive=TRUE,showWarnings=FALSE)
out_csv<-function(x,name)write.csv(x,file.path("reports/final_analysis",name),row.names=FALSE,na="")
prep4<-function(d){d$log_capacity_2<-log(d$accommodates/capacity_reference);d}
train4<-prep4(train3)
fit4<-lm(as.formula(completion_candidate_formula),train4,na.action=na.fail)
stopifnot(fit4$rank==length(coef(fit4)))
folds<-read.csv("data/processed/training_host_cv_folds.csv",colClasses=c("character","integer"))
fold_id<-folds$fold[match(train$host_id,folds$host_id)]
cv4<-do.call(rbind,lapply(seq_len(training_cv_folds),function(k){
  aa<-train[fold_id!=k,];bb<-train[fold_id==k,]
  stopifnot(!length(intersect(aa$host_id,bb$host_id)))
  z<-center_by_stay(aa,bb)
  ff<-lm(as.formula(completion_candidate_formula),prep4(z$training),na.action=na.fail)
  stopifnot(ff$rank==length(coef(ff)))
  pp<-predict(ff,prep4(z$other));stopifnot(all(is.finite(pp)))
  data.frame(model="M4",fold=k,id=bb$id,host_id=bb$host_id,squared_error=(bb$log_price-pp)^2)
}))
write.csv(cv4,"data/processed/M4_training_CV_errors.csv",row.names=FALSE)
cv4_summary<-data.frame(model="M4",pooled_listing_MSE=mean(cv4$squared_error),
  equal_host_MSE=mean(aggregate(squared_error~host_id,cv4,mean)$squared_error))
cv_all<-rbind(cv_summary,cv4_summary)
out_csv(cv_all,"training_CV_comparison.csv")
out_csv(aggregate(squared_error~model+fold,rbind(cv_records,cv4),mean),"training_CV_by_fold.csv")
improvements<-1-unlist(cv4_summary[1,2:3])/unlist(cv_summary[cv_summary$model=="M3",2:3])
selected_name<-if(all(improvements>=minimum_relative_CV_improvement))"M4" else "M3"
final_fit<-if(selected_name=="M4")fit4 else fit3
final_train<-if(selected_name=="M4")train4 else train3
final_formula<-if(selected_name=="M4")completion_candidate_formula else refinement_formula
final_sensitivity_train<-prep4(centered_sensitivity$training)
final_sensitivity_fit<-lm(as.formula(final_formula),final_sensitivity_train,na.action=na.fail)
out_csv(data.frame(candidate="M4",listing_CV_improvement=improvements[1],equal_host_CV_improvement=improvements[2],
  required_improvement=minimum_relative_CV_improvement,selected_model=selected_name),"training_selection_decision.csv")
sm4<-summary(fit4)
metrics4<-data.frame(model="M4",n=nobs(fit4),parameters=fit4$rank,residual_df=df.residual(fit4),R_squared=sm4$r.squared,
  adjusted_R_squared=sm4$adj.r.squared,training_residual_MSE=deviance(fit4)/df.residual(fit4),AIC=AIC(fit4),BIC=BIC(fit4))
all_metrics<-rbind(metrics,metrics3,metrics4)
out_csv(all_metrics,"candidate_metrics.csv")
writeLines(trim_model_output(capture.output(summary(final_fit))),"reports/final_analysis/final_R_summary.txt")
out_csv(coef_table(final_fit,final_train,selected_name),"final_coefficients.csv")

# Check actual joint capacity-bedroom-stay support, not only overlapping ranges.
support<-as.data.frame(table(train3$borough,train3$room_type,train3$accommodates,train3$bedrooms,train3$long_stay))
names(support)<-c("borough","room_type","accommodates","bedrooms","long_stay","n")
support<-support[support$n>0,]
out_csv(support,"training_joint_support.csv")
reference_support<-subset(support,accommodates %in% c("2","4") & bedrooms=="1")
out_csv(reference_support,"reference_profile_support.csv")
key<-paste(train3$accommodates,train3$bedrooms,train3$long_stay,sep="|")
cellgroup<-table(key,interaction(train3$borough,train3$room_type,drop=TRUE))
supported_keys<-rownames(cellgroup)[apply(cellgroup,1,min)>=20]
support_summary<-data.frame(training_n=nrow(train3),joint_cells_all_four_groups_at_least20=length(supported_keys),
  listings_in_those_cells=sum(key %in% supported_keys),pct_in_those_cells=100*mean(key %in% supported_keys))
out_csv(support_summary,"joint_support_summary.csv")

profile_contrasts<-function(f,d,label,capacity=2){
  nd<-d[rep(1,4),]
  nd$borough<-factor(c("Brooklyn","Manhattan","Brooklyn","Manhattan"),levels=levels(d$borough))
  nd$room_type<-factor(c("Private room","Private room","Entire home/apt","Entire home/apt"),levels=levels(d$room_type))
  nd$accommodates<-capacity;nd$log_accommodates<-log(capacity);nd$log_capacity_2<-log(capacity/capacity_reference)
  nd$bedrooms<-1;nd$long_stay<-1;nd$within_stay_log_min<-0
  xx<-model.matrix(delete.response(terms(f)),nd,contrasts.arg=f$contrasts)
  LL<-rbind(xx[2,]-xx[1,],xx[4,]-xx[3,],xx[3,]-xx[1,],xx[4,]-xx[2,])
  rownames(LL)<-c("Manhattan vs Brooklyn | Private room","Manhattan vs Brooklyn | Entire home/apt",
    "Entire home vs Private room | Brooklyn","Entire home vs Private room | Manhattan")
  vv<-cluster_vcov(f,d);df<-length(unique(d$host_id))-1
  est<-as.vector(LL%*%coef(f));se<-sqrt(diag(LL%*%vv%*%t(LL)));ci<-qt(.975,df)*se;p<-2*pt(-abs(est/se),df)
  data.frame(analysis=label,capacity=capacity,contrast=rownames(LL),log_difference=est,cluster_SE=se,
    pct_difference=100*expm1(est),pct_ci_lower=100*expm1(est-ci),pct_ci_upper=100*expm1(est+ci),
    p=p,p_Holm_four=p.adjust(p,"holm"),reference_df=df)
}
final_contrasts<-rbind(profile_contrasts(final_fit,final_train,"Primary",2),
  profile_contrasts(final_sensitivity_fit,final_sensitivity_train,"Without hotel labels",2))
out_csv(final_contrasts,"final_contrasts_capacity2.csv")
out_csv(rbind(profile_contrasts(final_fit,final_train,"Primary",4),
  profile_contrasts(final_sensitivity_fit,final_sensitivity_train,"Without hotel labels",4)),"secondary_contrasts_capacity4.csv")
final_wald<-function(f,d,label){
  bb<-coef(f);vv<-cluster_vcov(f,d);df<-length(unique(d$host_id))-1
  sets<-list("No borough association"=grep("borough",names(bb)),
    "No room-type association across modeled capacities"=grep("room_type",names(bb)),
    "No borough by room-type interaction"=match("boroughManhattan:room_typeEntire home/apt",names(bb)))
  z<-do.call(rbind,lapply(names(sets),function(nm){ii<-sets[[nm]];q<-length(ii)
    ff<-as.numeric(crossprod(bb[ii],solve(vv[ii,ii,drop=FALSE],bb[ii])))/q
    data.frame(analysis=label,hypothesis=nm,F=ff,df1=q,df2=df,p=pf(ff,q,df,lower.tail=FALSE))}))
  z$p_Holm_three<-p.adjust(z$p,"holm");z
}
final_tests<-rbind(final_wald(final_fit,final_train,"Primary"),final_wald(final_sensitivity_fit,final_sensitivity_train,"Without hotel labels"))
out_csv(final_tests,"final_Wald_tests.csv")
dd<-diag_plots(final_fit,final_train,selected_name,"figures/final/01_final_diagnostics.png")
XX<-model.matrix(final_fit)[,-1,drop=FALSE]
vvif<-vapply(seq_len(ncol(XX)),function(j)1/(1-summary(lm(XX[,j]~XX[,-j,drop=FALSE]))$r.squared),numeric(1))
out_csv(data.frame(term=colnames(XX),VIF=vvif),"final_design_VIF.csv")

# Delete each of the ten largest TRAINING hosts separately; no primary deletion.
host_sizes<-sort(table(final_train$host_id),decreasing=TRUE)
base_contr<-profile_contrasts(final_fit,final_train,"Primary",2)
host_checks<-do.call(rbind,lapply(seq_len(min(10,length(host_sizes))),function(k){
  zz<-final_train[final_train$host_id!=names(host_sizes)[k],]
  ff<-lm(as.formula(final_formula),zz,na.action=na.fail)
  cc<-profile_contrasts(ff,zz,"Host deletion diagnostic",2)
  data.frame(host_size_rank=k,listings_removed=as.integer(host_sizes[k]),contrast=cc$contrast,
    primary_log=base_contr$log_difference,without_host_log=cc$log_difference,delta_log=cc$log_difference-base_contr$log_difference)
}))
out_csv(host_checks,"largest_ten_hosts_deletion.csv")
topcase<-which.max(cooks.distance(final_fit));case_train<-final_train[-topcase,]
case_fit<-lm(as.formula(final_formula),case_train,na.action=na.fail)
case_contr<-profile_contrasts(case_fit,case_train,"Largest Cook deletion",2)
out_csv(data.frame(contrast=base_contr$contrast,primary_log=base_contr$log_difference,
  without_case_log=case_contr$log_difference,delta_log=case_contr$log_difference-base_contr$log_difference),"largest_Cook_deletion.csv")
final_diag<-data.frame(n=nrow(final_train),p=final_fit$rank,training_hosts=length(host_sizes),
  max_VIF=max(vvif),Cook_flag_n=sum(cooks.distance(final_fit)>4/nrow(final_train)),max_Cook=max(cooks.distance(final_fit)),
  max_leverage=max(hatvalues(final_fit)),leverage_flag_n=sum(hatvalues(final_fit)>2*final_fit$rank/nrow(final_train)),
  abs_studentized_gt3=sum(abs(rstudent(final_fit))>3),
  max_abs_case_contrast_delta=max(abs(case_contr$log_difference-base_contr$log_difference)),
  max_abs_top10_host_contrast_delta=max(abs(host_checks$delta_log)))
out_csv(final_diag,"final_diagnostic_summary.csv")
cc<-final_contrasts;cc$contrast<-factor(cc$contrast,levels=rev(unique(cc$contrast)))
pp<-ggplot(cc,aes(pct_difference,contrast,color=analysis))+geom_vline(xintercept=0,lty=2)+
  geom_errorbar(aes(xmin=pct_ci_lower,xmax=pct_ci_upper),orientation="y",width=.18,position=position_dodge(.5))+
  geom_point(position=position_dodge(.5),size=2.3)+scale_color_manual(values=c("Primary"="#287B85","Without hotel labels"="#B56830"))+
  labs(title=paste(selected_name,"adjusted associations at capacity two"),subtitle="Pointwise 95% intervals using host-cluster HC1 covariance",
    x="Conditional geometric-mean price difference (%)",y=NULL,color=NULL,
    caption="Inside Airbnb NYC 2026-09-14; training only. Observational associations; intervals exclude model-selection uncertainty.\nBoth room types remain in each sample. Property-label exclusions change the population.")+model_theme
save_model_plot(pp,"figures/final/02_final_contrasts.png",12,6)
rr<-data.frame(borough=final_train$borough,room_type=final_train$room_type,capacity=final_train$accommodates,residual=resid(final_fit))
rmn<-aggregate(residual~borough+room_type+capacity,rr,mean);rn<-aggregate(residual~borough+room_type+capacity,rr,length);names(rn)[4]<-"n"
rmn<-merge(rmn,rn);out_csv(rmn,"final_residual_capacity.csv")
cp<-ggplot(subset(rmn,n>=20),aes(capacity,residual,color=room_type))+geom_hline(yintercept=0,lty=2)+geom_line()+geom_point(aes(size=n))+
  facet_wrap(~borough)+scale_color_manual(values=c("Private room"="#B56830","Entire home/apt"="#287B85"))+
  labs(title=paste(selected_name,"remaining capacity patterns"),x="Guest capacity",y="Mean training residual (log-price units)",color=NULL,size="Cell n",
    caption="Inside Airbnb NYC 2026-09-14; training cells with n >= 20. Remaining group patterns limit the mean model.")+model_theme
save_model_plot(cp,"figures/final/03_final_capacity_residuals.png",10,6)
saveRDS(list(name=selected_name,formula=final_formula,fit=final_fit,training=final_train,
  sensitivity_fit=final_sensitivity_fit,sensitivity_training=final_sensitivity_train,
  centers=centered$centers,sensitivity_centers=centered_sensitivity$centers,capacity_reference=capacity_reference,
  contrasts=final_contrasts,tests=final_tests,diagnostics=final_diag,cv=cv_all,metrics=all_metrics,
  support=support_summary,reference_support=reference_support),"models/final_training_review.rds")
writeLines(trim_model_output(capture.output(sessionInfo())),"reports/final_analysis/session_info.txt")
cat("Training decision:",selected_name,"; relative CV improvements",improvements,"\n")
print(support_summary);print(reference_support);print(final_diag)
message("Review complete. No reserved test outcome evaluated. Freeze separately before test scoring.")
