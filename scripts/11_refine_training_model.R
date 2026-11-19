source("scripts/10_training_diagnostics.R")
source("config/model_refinement.R")
center_by_stay <- function(training,other=training) {
  centers<-tapply(training$log_minimum_nights,training$long_stay,mean)
  stopifnot(all(c("0","1") %in% names(centers)))
  apply_to<-function(z){z$within_stay_log_min<-z$log_minimum_nights-unname(centers[as.character(z$long_stay)])
    z$log_accommodates<-log(z$accommodates);z}
  list(training=apply_to(training),other=apply_to(other),centers=centers)
}
centered<-center_by_stay(train)
train3<-centered$training
fit3<-lm(as.formula(refinement_formula),data=train3,na.action=na.fail)
stopifnot(fit3$rank==length(coef(fit3)),fit3$rank==focal$rank)
# Confirm centering changes only the stay parameter interpretation for M2.
centered_M2<-lm(log_price~borough*room_type+accommodates+bedrooms+within_stay_log_min+long_stay,data=train3)
stopifnot(max(abs(fitted(centered_M2)-fitted(focal)))<1e-8)
write_model_csv(data.frame(long_stay=names(centered$centers),training_mean_log_minimum_nights=unname(centered$centers)),"M3_stay_centering_values.csv")

# The already reserved test set is not used. Folds split training HOSTS only.
cv_hosts<-sort(unique(train$host_id),method="radix")
RNGkind("Mersenne-Twister","Inversion","Rejection");set.seed(training_cv_seed)
cv_assignment<-data.frame(host_id=cv_hosts,fold=sample(rep(seq_len(training_cv_folds),length.out=length(cv_hosts))))
write.csv(cv_assignment,"data/processed/training_host_cv_folds.csv",row.names=FALSE)
fold_id<-cv_assignment$fold[match(train$host_id,cv_assignment$host_id)]
cv_rows<-list();counter<-0L
for(k in seq_len(training_cv_folds)) {
  a<-train[fold_id!=k,];b<-train[fold_id==k,]
  stopifnot(length(intersect(a$host_id,b$host_id))==0)
  for(nm in c(names(candidate_formulas),"M3")) {
    if(nm=="M3"){
      prepared<-center_by_stay(a,b)
      ff<-lm(as.formula(refinement_formula),data=prepared$training,na.action=na.fail)
      prediction<-predict(ff,newdata=prepared$other)
    }else{
      ff<-lm(as.formula(candidate_formulas[[nm]]),data=a,na.action=na.fail)
      prediction<-predict(ff,newdata=b)
    }
    stopifnot(all(is.finite(prediction)))
    counter<-counter+1L
    cv_rows[[counter]]<-data.frame(model=nm,fold=k,id=b$id,host_id=b$host_id,
       squared_error=(b$log_price-prediction)^2)
  }
}
cv_records<-do.call(rbind,cv_rows)
stopifnot(all(table(cv_records$model)==nrow(train)))
write.csv(cv_records,"data/processed/training_CV_errors.csv",row.names=FALSE)
cv_fold<-aggregate(squared_error~model+fold,cv_records,mean)
names(cv_fold)[3]<-"fold_MSE"
write_model_csv(cv_fold,"training_host_CV_by_fold.csv")
cv_pool<-aggregate(squared_error~model,cv_records,mean);names(cv_pool)[2]<-"pooled_listing_MSE"
cv_host<-aggregate(squared_error~model+host_id,cv_records,mean)
cv_equalhost<-aggregate(squared_error~model,cv_host,mean);names(cv_equalhost)[2]<-"equal_host_MSE"
cv_summary<-merge(cv_pool,cv_equalhost,by="model")
write_model_csv(cv_summary,"training_host_CV_summary.csv")

s3<-summary(fit3)
metrics3<-data.frame(model="M3",n=nobs(fit3),parameters=fit3$rank,residual_df=df.residual(fit3),
  R_squared=s3$r.squared,adjusted_R_squared=s3$adj.r.squared,training_residual_MSE=deviance(fit3)/df.residual(fit3),AIC=AIC(fit3),BIC=BIC(fit3))
write_model_csv(rbind(metrics,metrics3),"refined_candidate_metrics.csv")
writeLines(trim_model_output(capture.output(summary(fit3))),"reports/modeling/M3_R_summary.txt")
coefs3<-coef_table(fit3,train3,"M3")
write_model_csv(coefs3,"M3_coefficients.csv")
centered_sensitivity<-center_by_stay(train_sensitivity)
sens3<-lm(as.formula(refinement_formula),data=centered_sensitivity$training,na.action=na.fail)
contrast3<-rbind(contrast_table(fit3,train3,"Primary M3"),
  contrast_table(sens3,centered_sensitivity$training,"M3 without hotel labels"))
test3<-rbind(wald_tests(fit3,train3,"Primary M3"),wald_tests(sens3,centered_sensitivity$training,"M3 without hotel labels"))
write_model_csv(contrast3,"M3_adjusted_contrasts.csv")
write_model_csv(test3,"M3_cluster_Wald_tests.csv")
write_model_csv(coef_table(sens3,centered_sensitivity$training,"M3_without_hotel_labels"),"M3_sensitivity_coefficients.csv")
X3<-model.matrix(fit3)[,-1,drop=FALSE]
vifs3<-data.frame(term=colnames(X3),VIF=vapply(seq_len(ncol(X3)),function(j)
  1/(1-summary(lm(X3[,j]~X3[,-j,drop=FALSE]))$r.squared),numeric(1)))
write_model_csv(vifs3,"M3_design_column_VIF.csv")
diag3<-diag_plots(fit3,train3,"M3","figures/modeling/04_M3_diagnostics.png")
diag3$id<-train3$id;diag3$host_id<-train3$host_id
write.csv(diag3,"data/processed/M3_training_diagnostics.csv",row.names=FALSE)
cap3<-data.frame(borough=train3$borough,room_type=train3$room_type,value=train3$accommodates,residual=resid(fit3))
capmean3<-aggregate(residual~borough+room_type+value,cap3,mean)
capn3<-aggregate(residual~borough+room_type+value,cap3,length);names(capn3)[4]<-"n"
capmean3<-merge(capmean3,capn3,by=c("borough","room_type","value"))
write_model_csv(capmean3,"M3_residual_by_capacity.csv")
compare_cap<-rbind(data.frame(model="M2 linear capacity",cap_res[,c("borough","room_type","value","residual","n")]),
                   data.frame(model="M3 log capacity",capmean3))
p_cap3<-ggplot(subset(compare_cap,n>=20),aes(value,residual,color=room_type))+geom_hline(yintercept=0,lty=2)+
  geom_line()+geom_point(aes(size=n),alpha=.8)+facet_grid(model~borough)+
  scale_color_manual(values=c("Private room"="#B56830","Entire home/apt"="#287B85"))+
  labs(title="Capacity residual patterns before and after the log transformation",x="Guest capacity (persons)",
    y="Mean residual (log-price units)",color=NULL,size="Cell n",
    caption="Inside Airbnb NYC 2026-09-14; training records only. Connected cells have at least 20 observations.\nRemaining group patterns are limitations; robust standard errors do not correct a misspecified conditional mean.")+model_theme
save_model_plot(p_cap3,"figures/modeling/05_capacity_refinement_comparison.png",11,9)
f3<-contrast3;f3$contrast<-factor(f3$contrast,levels=rev(unique(f3$contrast)))
p_effect3<-ggplot(f3,aes(pct_difference,contrast,color=analysis))+geom_vline(xintercept=0,lty=2)+
  geom_errorbar(aes(xmin=pct_ci_lower,xmax=pct_ci_upper),orientation="y",width=.18,position=position_dodge(width=.5))+
  geom_point(position=position_dodge(width=.5),size=2.4)+
  scale_color_manual(values=c("Primary M3"="#287B85","M3 without hotel labels"="#B56830"))+
  labs(title="Adjusted price associations under M3",subtitle="Pointwise 95% intervals using host-cluster HC1 covariance",
    x="Difference in conditional geometric-mean price (%)",y=NULL,color=NULL,
    caption="Inside Airbnb NYC 2026-09-14; saved training partition only. These are associations, not causal effects.\nThe non-hotel-label subset changes the target population. Intervals do not account for training-data model refinement.")+model_theme
save_model_plot(p_effect3,"figures/modeling/06_M3_adjusted_contrasts.png",12,6)

# Diagnostic influence checks on M3. Keep all original training records in main inference.
top3<-which.max(cooks.distance(fit3))
delete3<-lm(as.formula(refinement_formula),data=train3[-top3,],na.action=na.fail)
largest_host<-names(which.max(table(train3$host_id)))
delete_host3<-lm(as.formula(refinement_formula),data=train3[train3$host_id!=largest_host,],na.action=na.fail)
L3<-contrast_matrix(fit3)
influence3<-data.frame(contrast=rownames(L3),primary_log=as.vector(L3%*%coef(fit3)),
  without_top_Cook_log=as.vector(L3%*%coef(delete3)),without_largest_host_log=as.vector(L3%*%coef(delete_host3)))
influence3$delta_top_Cook<-influence3$without_top_Cook_log-influence3$primary_log
influence3$delta_largest_host<-influence3$without_largest_host_log-influence3$primary_log
write_model_csv(influence3,"M3_influence_checks.csv")
diagnostics3<-data.frame(n=nrow(train3),parameters=fit3$rank,max_Cook=max(cooks.distance(fit3)),
  Cook_flag_n=sum(cooks.distance(fit3)>4/nrow(train3)),max_leverage=max(hatvalues(fit3)),
  studentized_abs_gt3_n=sum(abs(rstudent(fit3))>3),max_VIF=max(vifs3$VIF),
  largest_host_listings=sum(train3$host_id==largest_host),max_abs_case_deletion_contrast_change=max(abs(influence3$delta_top_Cook)),
  max_abs_host_deletion_contrast_change=max(abs(influence3$delta_largest_host)))
write_model_csv(diagnostics3,"M3_diagnostic_summary.csv")
saveRDS(list(fit=fit3,sensitivity_fit=sens3,training=train3,sensitivity_training=centered_sensitivity$training,
  centers=centered$centers,sensitivity_centers=centered_sensitivity$centers,formula=refinement_formula,
  cv=cv_summary,contrasts=contrast3,tests=test3,diagnostics=diagnostics3),"models/M3_training_stage.rds")
writeLines(sub("[[:space:]]+$","",capture.output(sessionInfo())),"reports/modeling/session_info.txt")
message("Completed one diagnostic-driven refinement and training-only host CV. Reserved test set remains unscored.")
