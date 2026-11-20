# Independent checks of frozen prediction algebra, sampling and reported errors.
if(dir.exists(".r-library")) .libPaths(c(normalizePath(".r-library"),.libPaths()))
z<-readRDS("models/final_training_review.rds")
lock<-jsonlite::fromJSON("config/final_model_lock.json")
ev<-readRDS("models/frozen_evaluation.rds")
checks<-data.frame(check=character(),passed=logical())
verify<-function(name,ok){checks<<-rbind(checks,data.frame(check=name,passed=isTRUE(ok)));if(!isTRUE(ok))stop(name)}
verify("Final model equals recorded M3",z$name=="M3" && z$formula==lock$formula)
verify("Locked coefficients unchanged",max(abs(coef(z$fit)-unlist(lock$coefficients)))<1e-12)
verify("Saved centers learned in training",max(abs(tapply(log(z$training$minimum_nights),z$training$long_stay,mean)-unlist(lock$stay_centers)))<1e-12)
rows<-read.csv("data/processed/model_primary.csv",colClasses="character")
tt<-rows[rows$partition=="test",];pr<-ev$predictions
verify("Every eligible reserved listing scored exactly once",!anyDuplicated(pr$id) && setequal(tt$id,pr$id))
tt<-tt[match(pr$id,tt$id),]
verify("No training and test host overlap",!length(intersect(z$training$host_id,tt$host_id)))
# Construct the design explicitly from locked definitions, independently of predict.lm.
M<-as.numeric(tt$borough=="Manhattan");E<-as.numeric(tt$room_type=="Entire home/apt")
L<-as.numeric(tt$minimum_nights)>=30
X<-cbind(1,M,E,log(as.numeric(tt$accommodates)),as.numeric(tt$bedrooms),
  log(as.numeric(tt$minimum_nights))-unname(unlist(lock$stay_centers)[as.character(as.integer(L))]),as.numeric(L),M*E)
colnames(X)<-c("(Intercept)","boroughManhattan","room_typeEntire home/apt","log_accommodates","bedrooms",
  "within_stay_log_min","long_stay","boroughManhattan:room_typeEntire home/apt")
manual_prediction<-as.vector(X%*%unlist(lock$coefficients)[colnames(X)])
verify("Predictions equal locked manual design calculation",max(abs(manual_prediction-pr$predicted_log_price))<1e-10)
observed<-log(as.numeric(tt$price));err<-observed-manual_prediction
verify("Observed response is natural log price",max(abs(observed-pr$observed_log_price))<1e-12)
verify("MSPR uses test denominator n",abs(mean(err^2)-ev$metrics$test_MSPR)<1e-12)
verify("Training MSE uses n minus rank",abs(sum(resid(z$fit)^2)/(nrow(z$training)-z$fit$rank)-ev$metrics$training_MSE)<1e-12)
verify("RMSE and MSE ratio",abs(sqrt(mean(err^2))-ev$metrics$test_RMSE)<1e-12 && abs(ev$metrics$test_MSPR/ev$metrics$training_MSE-ev$metrics$test_to_training_MSE_ratio)<1e-12)
verify("Benchmark uses training mean only",abs(mean((observed-mean(z$training$log_price))^2)-ev$metrics$training_mean_benchmark_MSPR)<1e-12)
verify("Group counts reconcile",sum(ev$groups$n)==nrow(tt))
verify("Group MSPR weighted mean equals pooled MSPR",abs(weighted.mean(ev$groups$MSPR,ev$groups$n)-ev$metrics$test_MSPR)<1e-12)
verify("Test sample sizes agree",nrow(tt)==ev$metrics$test_n && length(unique(tt$host_id))==ev$metrics$test_hosts)
host_means<-tapply(err^2,tt$host_id,mean)
verify("Equal-host score gives each host equal weight",abs(mean(host_means)-ev$metrics$equal_host_test_MSPR)<1e-12)
# Independent cluster-score covariance formula for primary inference.
x<-model.matrix(z$fit);u<-resid(z$fit);n<-nrow(x);p<-ncol(x);g<-length(unique(z$training$host_id))
hs<-rowsum(x*as.numeric(u),z$training$host_id,reorder=FALSE);bread<-solve(crossprod(x))
cov_manual<-(n-1)/(n-p)*g/(g-1)*bread%*%crossprod(hs)%*%bread
co<-read.csv("reports/final_analysis/final_coefficients.csv")
verify("Final cluster SE matches independent matrix formula",max(abs(sqrt(diag(cov_manual))-co$host_cluster_HC1_SE))<1e-9)
LL<-matrix(0,4,ncol(x),dimnames=list(NULL,colnames(x)))
LL[1:2,"boroughManhattan"]<-1;LL[3:4,"room_typeEntire home/apt"]<-1
LL[c(2,4),"boroughManhattan:room_typeEntire home/apt"]<-1
cc<-subset(z$contrasts,analysis=="Primary");diffs<-as.vector(LL%*%coef(z$fit));ses<-sqrt(diag(LL%*%cov_manual%*%t(LL)))
verify("Final contrasts and interval covariance",max(abs(diffs-cc$log_difference))<1e-12 && max(abs(ses-cc$cluster_SE))<1e-9)
verify("Geometric price transformation",max(abs(100*expm1(diffs)-cc$pct_difference))<1e-9 &&
  max(abs(100*expm1(diffs-qt(.975,g-1)*ses)-cc$pct_ci_lower))<1e-8)
cv<-read.csv("data/processed/M4_training_CV_errors.csv",colClasses=c("character","integer","character","character","numeric"))
verify("M4 validation covers training only once",!anyDuplicated(cv$id) && setequal(cv$id,z$training$id) && !any(cv$host_id %in% tt$host_id))
cv_table<-read.csv("reports/final_analysis/training_CV_comparison.csv")
verify("M4 CV score recalculated",abs(mean(cv$squared_error)-cv_table$pooled_listing_MSE[cv_table$model=="M4"])<1e-12)
improve<-1-unlist(cv_table[cv_table$model=="M4",2:3])/unlist(cv_table[cv_table$model=="M3",2:3])
verify("M3 retained under pre-recorded threshold",!all(improve>=.01))
verify("Sensitivity training remains primary subset",all(z$sensitivity_training$id %in% z$training$id) && all(z$sensitivity_training$partition=="train"))
for(file in names(lock$selection_source_md5))verify(paste("Locked selection source",file),unname(tools::md5sum(file))==lock$selection_source_md5[[file]])
payload<-jsonlite::fromJSON("reports/final_report/report_payload.json",simplifyVector=FALSE)
verify("Ten-page payload uses frozen model",length(payload$pages)==10 && payload$model==lock$model && payload$model_lock_md5==unname(tools::md5sum("config/final_model_lock.json")))
# Independently match the existing EDA IDs to raw quote fields. This is a
# measurement audit only; no model or evaluation rule is revised from it.
qa<-read.csv("reports/audit/price_quote_measurement.csv")
eda_ids<-read.csv("data/processed/eda_positive_price.csv",colClasses="character")$id
qr<-read.csv(gzfile("data/raw/nyc_listings_2026-09-14.csv.gz"),colClasses="character",check.names=FALSE,na.strings=c("","NA"))
qr<-qr[match(eda_ids,qr$id),]
verify("Quote audit uses the same EDA listings",nrow(qr)==qa$eda_n && !anyNA(qr$id) && !anyDuplicated(qr$id))
qp<-as.numeric(gsub("[$,]","",qr$price));qn<-as.numeric(qr$price_quote_price_per_night)
verify("Quoted nightly amount agreement recomputed",sum(!is.na(qn) & abs(qp-qn)<.005)==qa$price_matches_quote_at_cent_precision_n && sum(is.na(qn))==qa$quote_amount_missing_n)
qd<-as.integer(as.Date(qr$price_quote_checkout_date)-as.Date(qr$price_quote_checkin_date))
verify("Quoted stay duration recomputed from dates",sum(qd>=30,na.rm=TRUE)==qa$quoted_stay_ge30_n && abs(100*mean(qd>=30,na.rm=TRUE)-qa$quoted_stay_ge30_pct_of_eda)<1e-10)
verify("Quote duration distinct from minimum requirement",sum(as.numeric(qr$minimum_nights)>=30,na.rm=TRUE)==qa$minimum_requirement_ge30_n)
write.csv(checks,"reports/final_analysis/final_computation_validation.csv",row.names=FALSE)
cat(nrow(checks),"final numerical and integrity checks passed.\n")
