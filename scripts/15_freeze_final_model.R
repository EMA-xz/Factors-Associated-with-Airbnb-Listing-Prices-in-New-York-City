# Regenerate TRAINING work; never read test errors when making this record.
source("scripts/14_complete_training_review.R")
if(!requireNamespace("jsonlite",quietly=TRUE))stop("Install jsonlite first.")
z<-readRDS("models/final_training_review.rds")
freeze_files<-c("config/model_spec.R","config/model_refinement.R","config/completion_review.R", "scripts/14_complete_training_review.R")
locked<-list(version="2026-11-19-final-v1",training_base_commit="d576ba8",model=z$name,formula=z$formula,
  response="natural log of positive daily listing price",capacity_reference=z$capacity_reference,
  borough_levels=levels(z$training$borough),room_type_levels=levels(z$training$room_type),
  stay_centers=as.list(z$centers),coefficients=as.list(coef(z$fit)),
  raw_md5=unname(tools::md5sum("data/raw/nyc_listings_2026-09-14.csv.gz")),
  split_md5=unname(tools::md5sum("data/processed/host_split.csv")),
  primary_data_md5=unname(tools::md5sum("data/processed/model_primary.csv")),
  training_n=nrow(z$training),training_hosts=length(unique(z$training$host_id)),
  design_rank=z$fit$rank,training_residual_MSE=deviance(z$fit)/df.residual(z$fit),
  benchmark_training_mean_log_price=mean(z$training$log_price),
  rule="M4 must improve both saved-fold CV MSE metrics by at least 1%; otherwise M3. No further model search.",
  test_policy="One frozen specification; compute log-scale MSPR without refitting or tuning. Repeated runs only verify identical outputs.",
  selection_source_md5=as.list(tools::md5sum(freeze_files)))
tmp<-tempfile(fileext=".json")
jsonlite::write_json(locked,tmp,auto_unbox=TRUE,pretty=TRUE,digits=NA)
lockfile<-"config/final_model_lock.json"
if(file.exists(lockfile)){
  stopifnot(identical(readLines(lockfile),readLines(tmp)))
}else file.copy(tmp,lockfile)
unlink(tmp)
decision<-read.csv("reports/final_analysis/training_selection_decision.csv")
support<-z$support
review<-c("# Final specification fixed before reserved-host evaluation","",
  "Decision date: 2026-11-19. This record describes the pre-evaluation decision; later test scores are stored separately.","",
  paste("Selected model:",z$name),paste0("Formula: `",z$formula,"`."),"",
  sprintf("M4 allowed the log-capacity slope to vary by room type. Its listing-weighted CV MSE improved by %.3f%% and equal-host MSE by %.3f%% relative to M3. Neither reached the previously recorded 1%% adoption requirement, so retain M3. This is a pragmatic parsimony decision, not a significance test or claim that M3 predicts better than M4.",100*decision$listing_CV_improvement,100*decision$equal_host_CV_improvement),"",
  "The original response, sample eligibility, both room types, host split and hotel-label sensitivity are unchanged. Retain the planned borough-by-room interaction to answer the research question, not because it is significant. The coefficient estimates and training-only stay centers are locked in config/final_model_lock.json.","",
  sprintf("There are %d joint capacity-bedroom-stay-regime cells with at least 20 training records in every borough/room group. They cover %d training records (%.1f%%). Both stay regimes have observations at two-person capacity and one bedroom in all four groups. Marginal cell overlap does not prove joint overlap in exact minimum nights, neighborhood, amenities or other unmeasured characteristics.",support$joint_cells_all_four_groups_at_least20,support$listings_in_those_cells,support$pct_in_those_cells),"",
  "Primary conditional comparisons are reported at capacity two, one bedroom and a common modeled minimum-stay condition. Under M3, borough/room contrasts do not depend on capacity; four-person comparisons are redundant and supplied only as a labeled secondary output. Common-slope assumptions remain approximations.","",
  sprintf("The largest absolute change in a primary log contrast after deleting any one of the ten largest hosts is %.4f, versus %.4f after deleting the largest-Cook record. These are limited influence checks, not exhaustive leave-every-host-out validation. No case or host is deleted from the primary fit.",z$diagnostics$max_abs_top10_host_contrast_delta,z$diagnostics$max_abs_case_contrast_delta),"",
  "Residual upper tails, unequal spread and group-capacity patterns persist. Host-cluster covariance protects against some error dependence and heteroskedasticity, not mean misspecification. Treat coefficients as a parsimonious working log-price association model; do not claim all assumptions pass, precise market-wide conditional effects, or causality.","",
  "Reserved evaluation rule: use the saved training coefficients and centers for all eligible test hosts; compute mean squared log-price error and compare with training RSS/(n-p). Also report the training-mean intercept-only benchmark and group errors descriptively. Do not refit on test data, search alternatives using test scores, remove high-error test observations, or redraw the split. The earlier full-snapshot EDA limits the independence of this evaluation.")
writeLines(review,"reports/final_analysis/specification_decision.md")
message("Final specification and preprocessing locked. Test outcomes have still not been evaluated by this script.")
