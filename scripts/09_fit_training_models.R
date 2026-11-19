# Training-only regression stage. No held-out errors or test predictions are computed.
if(dir.exists(".r-library")) .libPaths(c(normalizePath(".r-library"),.libPaths()))
if(!requireNamespace("sandwich",quietly=TRUE)) stop("Run Rscript --vanilla scripts/setup_model_dependencies.R first.")
source("scripts/05_prepare_model_samples.R")
train <- primary[primary$partition=="train",]
train_sensitivity <- sensitivity[sensitivity$partition=="train",]
# Remove full-snapshot and test-containing frames from this modeling workspace.
rm(primary,sensitivity,d,eda,raw)
stopifnot(all(train$partition=="train"),all(train_sensitivity$partition=="train"))
dir.create("reports/modeling",recursive=TRUE,showWarnings=FALSE)
dir.create("models",showWarnings=FALSE)
write_model_csv <- function(x,name) write.csv(x,file.path("reports/modeling",name),row.names=FALSE,na="")
trim_model_output <- function(x) {
  x<-sub("[[:space:]]+$","",x)
  if(any(nzchar(x))) x[seq_len(max(which(nzchar(x))))] else character()
}
fit_candidates <- lapply(candidate_formulas,function(f) lm(as.formula(f),data=train,na.action=na.fail))
stopifnot(all(vapply(fit_candidates,nobs,integer(1))==nrow(train)))
for(f in fit_candidates) stopifnot(f$rank==length(coef(f)),all(is.finite(coef(f))))
metrics <- do.call(rbind,lapply(names(fit_candidates),function(nm){
  f<-fit_candidates[[nm]]; s<-summary(f)
  data.frame(model=nm,n=nobs(f),parameters=f$rank,residual_df=df.residual(f),
    R_squared=s$r.squared,adjusted_R_squared=s$adj.r.squared,
    training_residual_MSE=deviance(f)/df.residual(f),AIC=AIC(f),BIC=BIC(f))
}))
write_model_csv(metrics,"candidate_model_metrics.csv")
writeLines(trim_model_output(capture.output(anova(fit_candidates$M0,fit_candidates$M1,fit_candidates$M2))),
           "reports/modeling/classical_nested_F_tests.txt")
for(nm in names(fit_candidates)) {
  writeLines(trim_model_output(capture.output(summary(fit_candidates[[nm]]))),
             file.path("reports/modeling",paste0(nm,"_R_summary.txt")))
}
cluster_vcov <- function(f,data) {
  v<-sandwich::vcovCL(f,cluster=data$host_id,type="HC1",cadjust=TRUE)
  stopifnot(all(is.finite(v)),min(eigen(v,symmetric=TRUE,only.values=TRUE)$values)>0)
  v
}
coef_table <- function(f,data,label) {
  b<-coef(f);v<-cluster_vcov(f,data);g<-length(unique(data$host_id));df<-g-1
  se<-sqrt(diag(v));t<-b/se;ci<-qt(.975,df)*se
  classical<-summary(f)$coefficients
  data.frame(analysis=label,term=names(b),estimate=unname(b),
    ordinary_SE=classical[,2],ordinary_p=classical[,4],
    host_cluster_HC1_SE=se,cluster_reference_df=df,cluster_t=t,
    cluster_p=2*pt(-abs(t),df),cluster_ci_lower=b-ci,cluster_ci_upper=b+ci,row.names=NULL)
}
all_coefs <- do.call(rbind,lapply(names(fit_candidates),function(nm)coef_table(fit_candidates[[nm]],train,nm)))
write_model_csv(all_coefs,"candidate_coefficients.csv")
focal <- fit_candidates$M2 # Prespecified interaction model; retained to answer planned conditional contrasts.
focal_sensitivity <- lm(as.formula(candidate_formulas[["M2"]]),data=train_sensitivity,na.action=na.fail)
stopifnot(focal_sensitivity$rank==length(coef(focal_sensitivity)))
write_model_csv(coef_table(focal_sensitivity,train_sensitivity,"M2_without_hotel_labels"),"sensitivity_coefficients.csv")
writeLines(trim_model_output(capture.output(summary(focal_sensitivity))),"reports/modeling/sensitivity_R_summary.txt")

contrast_matrix <- function(f) {
  names_b<-names(coef(f))
  L<-matrix(0,4,length(names_b),dimnames=list(c("Manhattan vs Brooklyn | Private room",
    "Manhattan vs Brooklyn | Entire home/apt","Entire home vs Private room | Brooklyn",
    "Entire home vs Private room | Manhattan"),names_b))
  borough_term<-"boroughManhattan"; room_term<-"room_typeEntire home/apt"
  interaction_term<-"boroughManhattan:room_typeEntire home/apt"
  stopifnot(all(c(borough_term,room_term,interaction_term)%in%names_b))
  L[1:2,borough_term]<-1;L[2,interaction_term]<-1
  L[3:4,room_term]<-1;L[4,interaction_term]<-1
  L
}
contrast_table <- function(f,data,label) {
  L<-contrast_matrix(f);b<-coef(f);v<-cluster_vcov(f,data);df<-length(unique(data$host_id))-1
  est<-as.vector(L%*%b);se<-sqrt(diag(L%*%v%*%t(L)));lo<-est-qt(.975,df)*se;hi<-est+qt(.975,df)*se
  p<-2*pt(-abs(est/se),df)
  data.frame(analysis=label,contrast=rownames(L),log_difference=est,cluster_SE=se,
    ci_log_lower=lo,ci_log_upper=hi,geometric_mean_ratio=exp(est),
    pct_difference=100*expm1(est),pct_ci_lower=100*expm1(lo),pct_ci_upper=100*expm1(hi),
    p_unadjusted=p,p_Holm_four_contrasts=p.adjust(p,"holm"),cluster_reference_df=df)
}
contrasts <- rbind(contrast_table(focal,train,"Primary M2"),
                   contrast_table(focal_sensitivity,train_sensitivity,"M2 without hotel labels"))
write_model_csv(contrasts,"adjusted_contrasts.csv")
wald_tests <- function(f,data,label) {
  b<-coef(f);v<-cluster_vcov(f,data);df<-length(unique(data$host_id))-1
  subsets<-list("No borough association at either room type"=c("boroughManhattan","boroughManhattan:room_typeEntire home/apt"),
    "No room-type association in either borough"=c("room_typeEntire home/apt","boroughManhattan:room_typeEntire home/apt"),
    "No borough by room-type interaction"="boroughManhattan:room_typeEntire home/apt")
  z<-do.call(rbind,lapply(names(subsets),function(nm){ix<-match(subsets[[nm]],names(b));q<-length(ix)
    w<-as.numeric(crossprod(b[ix],solve(v[ix,ix,drop=FALSE],b[ix])))/q
    data.frame(analysis=label,hypothesis=nm,approx_cluster_F=w,df1=q,df2=df,p=pf(w,q,df,lower.tail=FALSE))}))
  z$p_Holm_three_questions<-p.adjust(z$p,"holm");z
}
tests <- rbind(wald_tests(focal,train,"Primary M2"),wald_tests(focal_sensitivity,train_sensitivity,"M2 without hotel labels"))
write_model_csv(tests,"cluster_Wald_tests.csv")

# Diagnostics use primary training records only; flags identify review candidates, not deletion rules.
diagnostic_rows <- data.frame(id=train$id,host_id=train$host_id,borough=train$borough,room_type=train$room_type,
  accommodates=train$accommodates,bedrooms=train$bedrooms,minimum_nights=train$minimum_nights,
  long_stay=train$long_stay,hotel_like_label=train$hotel_like_label,
  fitted_log_price=fitted(focal),residual=resid(focal),standardized_residual=rstandard(focal),
  studentized_residual=rstudent(focal),leverage=hatvalues(focal),Cook_distance=cooks.distance(focal))
diagnostic_rows$review_Cook <- diagnostic_rows$Cook_distance>4/nrow(train)
diagnostic_rows$review_leverage <- diagnostic_rows$leverage>2*focal$rank/nrow(train)
diagnostic_rows$review_studentized <- abs(diagnostic_rows$studentized_residual)>3
write.csv(diagnostic_rows,"data/processed/M2_training_diagnostics.csv",row.names=FALSE,na="")
X<-model.matrix(focal)[,-1,drop=FALSE]
vifs<-data.frame(term=colnames(X),VIF=vapply(seq_len(ncol(X)),function(j){
  1/(1-summary(lm(X[,j]~X[,-j,drop=FALSE]))$r.squared)
},numeric(1)))
write_model_csv(vifs,"M2_design_column_VIF.csv")
db<-dfbetas(focal)
diagnostic_summary <- data.frame(n=nrow(train),parameters=focal$rank,
  Cook_screen_cutoff=4/nrow(train),Cook_flag_n=sum(diagnostic_rows$review_Cook),max_Cook=max(diagnostic_rows$Cook_distance),
  leverage_screen_cutoff=2*focal$rank/nrow(train),leverage_flag_n=sum(diagnostic_rows$review_leverage),max_leverage=max(diagnostic_rows$leverage),
  studentized_abs_gt3_n=sum(diagnostic_rows$review_studentized),max_abs_studentized=max(abs(diagnostic_rows$studentized_residual)),
  max_abs_DFBETAS=max(abs(db)),max_VIF=max(vifs$VIF))
write_model_csv(diagnostic_summary,"M2_diagnostic_summary.csv")
top <- diagnostic_rows[order(-diagnostic_rows$Cook_distance),][1:10,]
write_model_csv(data.frame(Cook_rank=seq_len(nrow(top)),top[,c("borough","room_type","accommodates","bedrooms","minimum_nights","Cook_distance","leverage","studentized_residual")],row.names=NULL),"M2_top_influence_characteristics.csv")
host_sizes<-sort(table(train$host_id),decreasing=TRUE)
host_summary<-data.frame(training_hosts=length(host_sizes),hosts_with_multiple_listings=sum(host_sizes>1),
  listings_from_repeat_hosts=sum(host_sizes[host_sizes>1]),max_listings_one_host=max(host_sizes))
write_model_csv(host_summary,"training_host_structure.csv")
# Exact diagnostic refit without the largest-Cook observation; not used to select the main sample.
drop_one <- which.max(diagnostic_rows$Cook_distance)
fit_drop_one <- lm(as.formula(candidate_formulas[["M2"]]),data=train[-drop_one,],na.action=na.fail)
L<-contrast_matrix(focal)
influence_check <- data.frame(contrast=rownames(L),primary_log_difference=as.vector(L%*%coef(focal)),
  without_top_Cook_log_difference=as.vector(L%*%coef(fit_drop_one)))
influence_check$change_log_difference <- influence_check$without_top_Cook_log_difference-influence_check$primary_log_difference
influence_check$primary_pct <- 100*expm1(influence_check$primary_log_difference)
influence_check$without_top_Cook_pct <- 100*expm1(influence_check$without_top_Cook_log_difference)
write_model_csv(influence_check,"M2_top_Cook_case_deletion_check.csv")
stopifnot(all(vapply(fit_candidates,function(f) identical(rownames(model.frame(f)),rownames(train)),logical(1))))
saveRDS(list(candidates=fit_candidates,M2_sensitivity=focal_sensitivity,train=train,train_sensitivity=train_sensitivity,
  diagnostic_rows=diagnostic_rows,metrics=metrics,coefficients=all_coefs,contrasts=contrasts,tests=tests,
  vifs=vifs,diagnostic_summary=diagnostic_summary,influence_check=influence_check,host_summary=host_summary),
  "models/training_stage.rds")
writeLines(sub("[[:space:]]+$","",capture.output(sessionInfo())),"reports/modeling/session_info.txt")
message("Fitted M0/M1/M2 and the prespecified property-label sensitivity on training data only.")
