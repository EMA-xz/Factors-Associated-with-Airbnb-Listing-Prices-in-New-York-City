# Must follow the separately recorded model freeze. This script does not fit a model.
if(!requireNamespace("jsonlite",quietly=TRUE))stop("Install jsonlite first.")
stopifnot(file.exists("config/final_model_lock.json"),file.exists("models/final_training_review.rds"))
lock<-jsonlite::fromJSON("config/final_model_lock.json")
fit_state<-readRDS("models/final_training_review.rds")
stopifnot(identical(fit_state$formula,lock$formula),identical(fit_state$name,lock$model),
  max(abs(coef(fit_state$fit)-unlist(lock$coefficients)[names(coef(fit_state$fit))]))<1e-12,
  unname(tools::md5sum("data/processed/host_split.csv"))==lock$split_md5,
  unname(tools::md5sum("data/processed/model_primary.csv"))==lock$primary_data_md5,
  unname(tools::md5sum("data/raw/nyc_listings_2026-09-14.csv.gz"))==lock$raw_md5)
for(p in names(lock$selection_source_md5))stopifnot(unname(tools::md5sum(p))==lock$selection_source_md5[[p]])
all_rows<-read.csv("data/processed/model_primary.csv",colClasses="character")
test<-all_rows[all_rows$partition=="test",];rm(all_rows)
stopifnot(!anyDuplicated(test$id),!length(intersect(test$host_id,fit_state$training$host_id)))
for(v in c("price","log_price","accommodates","bedrooms","minimum_nights","long_stay"))test[[v]]<-as.numeric(test[[v]])
test$borough<-factor(test$borough,levels=lock$borough_levels)
test$room_type<-factor(test$room_type,levels=lock$room_type_levels)
test$log_accommodates<-log(test$accommodates)
test$log_capacity_2<-log(test$accommodates/lock$capacity_reference)
test$within_stay_log_min<-log(test$minimum_nights)-unname(unlist(lock$stay_centers)[as.character(test$long_stay)])
stopifnot(all(test$price>0),max(abs(log(test$price)-test$log_price))<1e-12)
prediction<-as.numeric(predict(fit_state$fit,newdata=test))
stopifnot(all(is.finite(prediction)))
err<-test$log_price-prediction
predictions<-data.frame(id=test$id,host_id=test$host_id,borough=test$borough,room_type=test$room_type,
  observed_log_price=test$log_price,predicted_log_price=prediction,residual=err,squared_error=err^2)
write.csv(predictions,"data/processed/final_test_predictions.csv",row.names=FALSE)
test_mspr<-mean(err^2);train_mse<-lock$training_residual_MSE
benchmark<-mean((test$log_price-lock$benchmark_training_mean_log_price)^2)
test_metrics<-data.frame(model=lock$model,training_n=lock$training_n,training_hosts=lock$training_hosts,
  training_residual_df=lock$training_n-lock$design_rank,training_MSE=train_mse,
  test_n=nrow(test),test_hosts=length(unique(test$host_id)),test_MSPR=test_mspr,test_RMSE=sqrt(test_mspr),
  test_to_training_MSE_ratio=test_mspr/train_mse,test_mean_residual=mean(err),test_MAE=mean(abs(err)),
  equal_host_test_MSPR=mean(aggregate(squared_error~host_id,predictions,mean)$squared_error),
  training_mean_benchmark_MSPR=benchmark,relative_improvement_vs_benchmark=1-test_mspr/benchmark)
write.csv(test_metrics,"reports/final_analysis/test_metrics.csv",row.names=FALSE)
gg<-split(predictions,interaction(predictions$borough,predictions$room_type,drop=TRUE))
by_group<-do.call(rbind,lapply(gg,function(g)data.frame(borough=g$borough[1],room_type=g$room_type[1],n=nrow(g),
  hosts=length(unique(g$host_id)),MSPR=mean(g$squared_error),RMSE=sqrt(mean(g$squared_error)),mean_residual=mean(g$residual))))
write.csv(by_group,"reports/final_analysis/test_metrics_by_group.csv",row.names=FALSE)
audit<-data.frame(item=c("lock_md5","training_fit_rds_md5","prediction_rows","test_hosts","host_overlap"),
  value=c(unname(tools::md5sum("config/final_model_lock.json")),unname(tools::md5sum("models/final_training_review.rds")),
    nrow(test),length(unique(test$host_id)),length(intersect(test$host_id,fit_state$training$host_id))))
write.csv(audit,"reports/final_analysis/evaluation_audit.csv",row.names=FALSE)
saveRDS(list(metrics=test_metrics,groups=by_group,predictions=predictions,lock=lock),"models/frozen_evaluation.rds")
print(test_metrics)
message("Scored frozen specification only. No model was fitted or altered in this evaluation script.")
