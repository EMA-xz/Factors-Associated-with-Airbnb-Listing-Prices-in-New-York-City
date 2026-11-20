# NYC AIRBNB PRICE PROJECT -- SINGLE-FILE R SUBMISSION
# Submit this .R file together with the written report PDF. No ZIP, GitHub
# checkout, other script, configuration file, or precomputed results are needed.
#
# HOW TO RUN (R >= 4.0, RStudio or command line)
#   RStudio: open this file and click Source (run the entire file).
#   Terminal: Rscript --vanilla Airbnb_Project.R
# Internet is needed on first run to download the fixed real dataset and any
# missing packages. Packages are installed only in the output folder's library.
# Output: airbnb_submission_output/ under the current working directory.
# An existing pinned data file may be reused via AIRBNB_RAW_DATA; otherwise
# the script downloads it directly from Inside Airbnb and verifies its hash.
# Optional AIRBNB_OUTPUT_DIR sets a different output directory.
#
# CONTENTS
# 1. Setup and embedded historical integrity records.
# 2. Source data, audit, descriptive statistics and four exploratory figures.
# 3. Host-level split, candidate models, clustered inference and diagnostics.
# 4. Training-only refinement, CV, population sensitivity and influence checks.
# 5. Frozen-model verification and reserved-host prediction evaluation.
# 6. Report figures, computed tables, text and independent numerical checks.
# Section markers below preserve the names of the original organized modules.
# Every executable source() call has been replaced by its actual R code.
#
# All analytical numbers and plots are computed from real data. The embedded
# frozen coefficients are historical verification targets, not replacements
# for fitting. The original model was frozen on 2026-11-19 (commit 26e8ecf),
# before test scoring. This script reproduces it; it does not reopen selection.
# Both Private room and Entire home/apt are included in Brooklyn and Manhattan.
# Observational associations are not causal effects; diagnostics have remaining
# limitations discussed in the report. Earlier EDA viewed the full snapshot.
#
# This file generates numerical results, PNG figures and report text in R.
# The separately submitted PDF is already typeset; reproducing its PDF/Word
# typography is not required to run this analysis and does not require Python.
# Team names and UNIs: fill in the report before submission.

submission_previous_wd <- getwd()
submission_previous_options <- options()
submission_previous_libraries <- .libPaths()
tryCatch({
  submission_output <- Sys.getenv("AIRBNB_OUTPUT_DIR", unset="")
  if (!nzchar(submission_output)) {
    submission_output <- file.path(submission_previous_wd, "airbnb_submission_output")
  }
  dir.create(submission_output, recursive=TRUE, showWarnings=FALSE)
  submission_output <- normalizePath(submission_output, mustWork=TRUE)
  submission_cached_raw <- Sys.getenv("AIRBNB_RAW_DATA", unset="")
  if (nzchar(submission_cached_raw)) {
    submission_cached_raw <- normalizePath(submission_cached_raw, mustWork=TRUE)
  }
  setwd(submission_output)
  for (folder in c("config", "scripts", "data/raw", ".r-library")) {
    dir.create(folder, recursive=TRUE, showWarnings=FALSE)
  }
  .libPaths(c(normalizePath(".r-library"), .libPaths()))
  submission_packages <- c("ggplot2", "jsonlite", "sandwich")
  submission_missing <- submission_packages[
    !vapply(submission_packages, requireNamespace, logical(1), quietly=TRUE)]
  if (length(submission_missing)) {
    install.packages(submission_missing, lib=".r-library",
                     repos="https://cloud.r-project.org")
  }
  stopifnot(all(vapply(submission_packages, requireNamespace, logical(1), quietly=TRUE)))
  # ragg is optional; the existing plotting code also supports base PNG.
  if (nzchar(submission_cached_raw)) {
    submission_raw_target <- "data/raw/nyc_listings_2026-09-14.csv.gz"
    if (!file.exists(submission_raw_target)) {
      stopifnot(file.copy(submission_cached_raw, submission_raw_target))
    }
  }

  # HISTORICAL INTEGRITY RECORDS (plain text, not hidden/encoded code).
  # Recreate the four original source texts solely for their existing MD5
  # checks, plus the immutable model lock and the team-header configuration.
  # The actual analysis below is inlined and never sources these files.
  # Refuse to overwrite differing records in an existing output folder.
  submission_write_record <- function(path, text) {
    bytes <- charToRaw(enc2utf8(text))
    if (file.exists(path)) {
      old <- readBin(path, "raw", n=file.info(path)$size)
      if (!identical(old, bytes)) stop("Existing record differs: ", path,
        ". Use an empty output folder; do not change the frozen model.")
    } else {
      writeBin(bytes, path)
    }
  }

submission_write_record("config/model_spec.R", r"---(# Recorded before fitting any regression. Changes require a documented reason.
model_protocol_version <- "2026-11-18-v1"
split_seed <- 20261118L
training_host_fraction <- 0.80
excluded_property_pattern <- "hotel|hostel|resort"
reference_borough <- "Brooklyn"
reference_room_type <- "Private room"
candidate_formulas <- c(
  M0 = "log_price ~ borough + room_type",
  M1 = "log_price ~ borough + room_type + accommodates + bedrooms + log_minimum_nights + long_stay",
  M2 = "log_price ~ borough * room_type + accommodates + bedrooms + log_minimum_nights + long_stay"
)
)---")

submission_write_record("config/model_refinement.R", r"---(# Added after inspecting M2 TRAINING diagnostics, before evaluating M3 or any test errors.
# M2 mean residuals vary nonlinearly with capacity; a log-capacity candidate has
# the same parameter count. Stay centering is an equivalent reparameterization,
# not an improvement in fitted values or a cure for weak within-regime support.
refinement_formula <- "log_price ~ borough * room_type + log_accommodates + bedrooms + within_stay_log_min + long_stay"
training_cv_seed <- 20261119L
training_cv_folds <- 5L
)---")

submission_write_record("config/completion_review.R", r"---(# Recorded before fitting M4 or viewing any reserved test errors, 2026-11-19.
# M3 residual-capacity patterns differ between room types. Test one additional
# slope interaction, with capacity centered at two guests for interpretable contrasts.
completion_candidate_formula <- "log_price ~ borough * room_type + room_type * log_capacity_2 + bedrooms + within_stay_log_min + long_stay"
capacity_reference <- 2
# Use the SAME saved training-host folds. Adopt M4 only if both listing-weighted
# and equal-host CV MSE improve by at least 1%, with full rank in all fits.
# This is a pragmatic complexity threshold, not a significance test or unbiased CV.
minimum_relative_CV_improvement <- .01
# Main conditional room-type comparisons will be at capacity=2. Comparisons at
# capacity=4 are secondary, explicitly labeled, with support counts disclosed.
# No further functional-form search is planned before the reserved evaluation.
)---")

submission_write_record("scripts/14_complete_training_review.R", r"---(source("scripts/12_training_report.R")
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
)---")

submission_write_record("config/final_model_lock.json", r"---({
  "version": "2026-11-19-final-v1",
  "training_base_commit": "d576ba8",
  "model": "M3",
  "formula": "log_price ~ borough * room_type + log_accommodates + bedrooms + within_stay_log_min + long_stay",
  "response": "natural log of positive daily listing price",
  "capacity_reference": 2,
  "borough_levels": ["Brooklyn", "Manhattan"],
  "room_type_levels": ["Private room", "Entire home/apt"],
  "stay_centers": {
    "0": 0.314708427326357,
    "1": 3.42617953523431
  },
  "coefficients": {
    "(Intercept)": 5.0398570471449,
    "boroughManhattan": 0.451737221391304,
    "room_typeEntire home/apt": 0.385362175038003,
    "log_accommodates": 0.44904167126591,
    "bedrooms": 0.112506489118137,
    "within_stay_log_min": -0.0833168779085823,
    "long_stay": -0.914670090301071,
    "boroughManhattan:room_typeEntire home/apt": -0.0383458398852191
  },
  "raw_md5": "d246ef4c52a914b514419cb5839dd9d7",
  "split_md5": "0c60219da3287a4eb53c2e98d51deb5b",
  "primary_data_md5": "7f18ed6eff03734279b08423f5eaf5ce",
  "training_n": 11568,
  "training_hosts": 5564,
  "design_rank": 8,
  "training_residual_MSE": 0.335738908393905,
  "benchmark_training_mean_log_price": 5.37304593107391,
  "rule": "M4 must improve both saved-fold CV MSE metrics by at least 1%; otherwise M3. No further model search.",
  "test_policy": "One frozen specification; compute log-scale MSPR without refitting or tuning. Repeated runs only verify identical outputs.",
  "selection_source_md5": {
    "config/model_spec.R": "4e33e0bf7a6910d4b41ad95ea64ad05d",
    "config/model_refinement.R": "f873fb5e71fcf98057bbf61620594647",
    "config/completion_review.R": "65ca29da48dee7ce04bf6726ef9b7f17",
    "scripts/14_complete_training_review.R": "a5e313a6df59df1e5de03b55885be323"
  }
}
)---")

submission_write_record("config/team.csv", r"---(name,uni
)---")

# ===== EXECUTABLE ANALYSIS =====

# ===== BEGIN scripts/run_final_analysis.R =====
# Run from the repository root after installing the documented dependencies.
# This regenerates analyses and verifies the fixed model; it never retunes to test errors.
options(warn=2)

# ===== BEGIN scripts/17_prepare_final_report.R =====
# Full analytical entry point. Recomputations verify the frozen specification;
# they do not choose models from test scores. All report numbers originate in R.

# ===== BEGIN scripts/04_generate_eda.R =====
# Complete reproducible EDA entry point; this executes download, audit and summaries.
if (!requireNamespace("ggplot2", quietly = TRUE)) {
  stop("Install the plotting dependency first: install.packages('ggplot2')")
}

# ===== BEGIN scripts/03_descriptive_analysis.R =====
# Rebuild the audited sample from the pinned raw snapshot; never rely on hand edits.

# ===== BEGIN scripts/02_audit_data.R =====

# ===== BEGIN scripts/01_download_data.R =====

# ===== BEGIN scripts/00_config.R =====
# Run scripts from the repository root. No external R packages are required.
snapshot_date <- "2026-09-14"
source_url <- paste0("https://data.insideairbnb.com/united-states/ny/",
                     "new-york-city/", snapshot_date, "/data/listings.csv.gz")
raw_path <- file.path("data", "raw", paste0("nyc_listings_", snapshot_date, ".csv.gz"))
# Fingerprint of the actual downloaded file; reject silently changed snapshots.
expected_md5 <- "d246ef4c52a914b514419cb5839dd9d7"
source_sha256 <- "a67bf574e47aa6eba5b2262987dbd9684f206d5cd0183470056f9c936b8e7ae1"
for (folder in c("data/raw", "data/processed", "reports/audit")) {
  dir.create(folder, recursive = TRUE, showWarnings = FALSE)
}

# ===== END scripts/00_config.R =====
if (!file.exists(raw_path)) {
  options(timeout = max(180, getOption("timeout")))
  temporary <- paste0(raw_path, ".download")
  download.file(source_url, temporary, mode = "wb", method = "libcurl")
  if (!identical(unname(tools::md5sum(temporary)), expected_md5)) {
    stop("Downloaded file differs from the pinned snapshot. Investigate before proceeding.")
  }
  if (!file.rename(temporary, raw_path)) stop("Could not save downloaded snapshot.")
}
if (!identical(unname(tools::md5sum(raw_path)), expected_md5)) {
  stop("Local raw file does not match the pinned fingerprint; do not use it.")
}
message("Verified pinned Inside Airbnb snapshot: ", raw_path)

# ===== END scripts/01_download_data.R =====
# Character import preserves long listing IDs exactly and retains source strings.
raw <- read.csv(gzfile(raw_path), colClasses = "character", check.names = FALSE,
                na.strings = c("", "NA"), stringsAsFactors = FALSE)
required <- c("id", "host_id", "last_scraped", "neighbourhood_group_cleansed",
              "room_type", "price", "accommodates", "bedrooms", "minimum_nights",
              "review_scores_rating")
if (length(setdiff(required, names(raw)))) stop("Required source fields are missing.")
missing <- function(x) is.na(x) | trimws(x) == ""
if (any(missing(raw$id)) || anyDuplicated(raw$id)) {
  stop("Missing or duplicate listing IDs: resolve explicitly before creating a sample.")
}
save_csv <- function(x, filename) {
  write.csv(x, file.path("reports/audit", filename), row.names = FALSE, na = "")
}
save_csv(data.frame(field = names(raw), missing_n = vapply(raw, function(x)
  sum(missing(x)), integer(1))), "all_fields.csv")
scope <- raw$neighbourhood_group_cleansed %in% c("Manhattan", "Brooklyn") &
  raw$room_type %in% c("Entire home/apt", "Private room")
d <- raw[scope, required]
names(d)[names(d) == "neighbourhood_group_cleansed"] <- "borough"
names(d)[names(d) == "price"] <- "price_raw"
numeric_fields <- c("accommodates", "bedrooms", "minimum_nights", "review_scores_rating")
parse_failures <- data.frame(field = character(), failed_nonmissing_n = integer())
for (field in numeric_fields) {
  original <- d[[field]]
  d[[field]] <- suppressWarnings(as.numeric(original))
  parse_failures <- rbind(parse_failures, data.frame(field = field,
    failed_nonmissing_n = sum(!missing(original) & is.na(d[[field]]))))
}
price_string <- gsub("[$,]", "", trimws(d$price_raw))
d$price <- suppressWarnings(as.numeric(price_string))
parse_failures <- rbind(parse_failures, data.frame(field = "price",
  failed_nonmissing_n = sum(!missing(d$price_raw) & is.na(d$price))))
save_csv(parse_failures, "parse_failures.csv")
d$price_observed <- !missing(d$price_raw)
d$valid_price <- is.finite(d$price) & d$price > 0
whole <- function(x) is.finite(x) & x == floor(x)
d$valid_core_covariates <- whole(d$accommodates) & d$accommodates >= 1 &
  whole(d$bedrooms) & d$bedrooms >= 0 &
  whole(d$minimum_nights) & d$minimum_nights >= 1
d$valid_rating <- is.finite(d$review_scores_rating) &
  d$review_scores_rating >= 0 & d$review_scores_rating <= 5
d$log_price <- NA_real_
d$log_price[d$valid_price] <- log(d$price[d$valid_price])
eda <- d[d$valid_price, ]
stopifnot(nrow(eda) > 0, all(is.finite(eda$log_price)))
write.csv(d, "data/processed/scoped_listings_with_flags.csv", row.names = FALSE, na = "")
write.csv(eda, "data/processed/eda_positive_price.csv", row.names = FALSE, na = "")
flow <- data.frame(stage = c("Raw NYC snapshot", "Two boroughs and two room types",
  "Observed finite positive price (preliminary EDA sample)",
  "Also valid complete core covariates (candidate, not final model sample)",
  "Also valid observed rating (candidate sensitivity sample)"),
  n = c(nrow(raw), nrow(d), nrow(eda), sum(d$valid_price & d$valid_core_covariates),
    sum(d$valid_price & d$valid_core_covariates & d$valid_rating)))
save_csv(flow, "sample_flow.csv")
groups <- split(d, interaction(d$borough, d$room_type, drop = TRUE))
group_audit <- do.call(rbind, lapply(groups, function(g) {
  p <- g$price[g$valid_price]
  data.frame(borough = g$borough[1], room_type = g$room_type[1], scoped_n = nrow(g),
    missing_price_n = sum(!g$price_observed), valid_price_n = length(p),
    valid_price_pct = 100 * mean(g$valid_price),
    core_complete_n = sum(g$valid_price & g$valid_core_covariates),
    rating_missing_in_eda_n = sum(g$valid_price & is.na(g$review_scores_rating)),
    median_price_usd = if(length(p)) median(p) else NA_real_,
    minimum_nights_ge30_in_eda_n = sum(g$valid_price & g$minimum_nights >= 30, na.rm = TRUE))
}))
rownames(group_audit) <- NULL
stopifnot(sum(group_audit$scoped_n) == nrow(d), sum(group_audit$valid_price_n) == nrow(eda))
save_csv(group_audit, "group_audit.csv")
fields <- c("price", numeric_fields)
missingness <- do.call(rbind, lapply(list(scoped = d, positive_price = eda), function(g) {
  data.frame(field = fields, n = nrow(g),
    missing_n = vapply(g[fields], function(x) sum(is.na(x)), integer(1)))
}))
missingness$sample <- rep(c("scoped", "positive_price"), each = length(fields))
rownames(missingness) <- NULL
save_csv(missingness, "missingness.csv")
numeric_summary <- do.call(rbind, lapply(fields, function(field) {
  x <- eda[[field]]; x <- x[is.finite(x)]
  q <- if(length(x)) unname(quantile(x, c(0, .25, .5, .75, .99, 1))) else rep(NA_real_, 6)
  data.frame(field = field, observed_n = length(x), mean = if(length(x)) mean(x) else NA_real_,
    sd = if(length(x)>1) sd(x) else NA_real_, min = q[1], q25 = q[2],
    median = q[3], q75 = q[4], q99 = q[5], max = q[6])
}))
save_csv(numeric_summary, "numeric_summary_positive_price.csv")
known_host <- !missing(eda$host_id)
host_sizes <- table(eda$host_id[known_host])
host_audit <- data.frame(known_hosts_n = length(host_sizes),
  hosts_with_multiple_scoped_priced_listings_n = sum(host_sizes > 1),
  listings_from_those_hosts_n = sum(host_sizes[host_sizes > 1]),
  max_scoped_priced_listings_per_host = if(length(host_sizes)) max(host_sizes) else NA_integer_,
  listings_missing_host_id_n = sum(!known_host))
save_csv(host_audit, "host_audit.csv")
save_csv(as.data.frame(table(raw$last_scraped), responseName = "n"), "scrape_dates.csv")
source_manifest <- data.frame(provider = "Inside Airbnb", snapshot_label = snapshot_date,
  observed_scrape_min = min(raw$last_scraped, na.rm=TRUE),
  observed_scrape_max = max(raw$last_scraped, na.rm=TRUE), url = source_url,
  local_file = raw_path, bytes = file.info(raw_path)$size,
  md5 = unname(tools::md5sum(raw_path)), sha256_at_acquisition = source_sha256,
  raw_rows = nrow(raw), raw_columns = ncol(raw))
save_csv(source_manifest, "source_manifest.csv")
fmt <- function(x) format(x, big.mark = ",", scientific = FALSE, trim = TRUE)
lines <- c("# Data audit: NYC Airbnb", "",
  "Generated by `Rscript --vanilla scripts/02_audit_data.R`; do not edit numerical results by hand.", "",
  paste0("Source: Inside Airbnb; snapshot label ", snapshot_date, "."),
  paste0("Observed scraping dates: ", source_manifest$observed_scrape_min, " to ", source_manifest$observed_scrape_max, "."),
  paste0("Raw file: ", fmt(nrow(raw)), " listings and ", ncol(raw), " fields; listing IDs are unique and nonmissing."), "",
  "## Sample accounting", "",
  paste0("- ", flow$stage, ": ", fmt(flow$n), "."), "",
  paste0("Missing price in scope: ", fmt(sum(!d$price_observed)), " (",
    sprintf("%.1f", 100*mean(!d$price_observed)), "% of scoped listings)."),
  paste0("Observed but nonfinite/nonpositive/unparseable prices: ",
    sum(d$price_observed & !d$valid_price), "."), "",
  "## Four-group coverage", "",
  vapply(seq_len(nrow(group_audit)), function(i) {
    g <- group_audit[i, ]
    paste0("- ", g$borough, " / ", g$room_type, ": ", fmt(g$scoped_n),
      " scoped; ", fmt(g$valid_price_n), " positive-price listings (",
      sprintf("%.1f", g$valid_price_pct), "%); median observed positive price $",
      sprintf("%.2f", g$median_price_usd), ".")
  }, character(1)), "", "## Decisions and limits", "",
  "- This is a preliminary EDA sample, not a finalized regression sample.",
  "- No price trimming, winsorization, imputation, random subsampling, or model fitting was performed.",
  "- Missing prices are not replaced by zero or another price-quote field. Coverage must be discussed before inference.",
  "- Bedrooms equal to zero are allowed; missing bedrooms are not assumed to mean a studio.",
  "- Missing ratings are retained in the scoped and EDA datasets; a rating is not required for EDA.",
  paste0("- ", fmt(sum(eda$minimum_nights >= 30, na.rm = TRUE)), " of ", fmt(nrow(eda)),
    " positive-price listings have minimum_nights >= 30; do not describe this sample as exclusively short stays."),
  paste0("- ", fmt(host_audit$hosts_with_multiple_scoped_priced_listings_n),
    " known hosts have multiple scoped positive-price listings, accounting for ",
    fmt(host_audit$listings_from_those_hosts_n), " listings; assess dependence before model inference/splitting."),
  "- Comparisons are observational associations in this snapshot, not causal effects or realized transaction prices.",
  "- Inspect missing-price selection, covariate overlap, and price semantics before finalizing the model.", "",
  "All detailed counts are in the adjacent CSV files. Row-level data are regenerated locally and excluded from Git.")
writeLines(lines, "reports/audit/data_audit.md")
writeLines(sub("[[:space:]]+$", "", capture.output(sessionInfo())),
           "reports/audit/session_info.txt")
cat(paste(lines, collapse = "\n"), "\n")

# ===== END scripts/02_audit_data.R =====
dir.create("reports/eda", recursive = TRUE, showWarnings = FALSE)
eda_csv <- function(x, name) write.csv(x, file.path("reports/eda", name),
                                     row.names = FALSE, na = "")
safe_median <- function(x) if (any(is.finite(x))) median(x[is.finite(x)]) else NA_real_
d$borough <- factor(d$borough, c("Brooklyn", "Manhattan"))
d$room_type <- factor(d$room_type, c("Entire home/apt", "Private room"))
d$price_status <- ifelse(d$valid_price, "Observed positive price", "No usable price")
d$stay_group <- ifelse(!whole(d$minimum_nights) | d$minimum_nights < 1,
                       "Missing/invalid", ifelse(d$minimum_nights >= 30, "30+ nights", "1-29 nights"))
d$property_type <- raw$property_type[scope]
d$property_type[is.na(d$property_type) | d$property_type == ""] <- "Missing"
# Descriptive string rule, not a legal or verified business classification.
d$hotel_like_label <- grepl("hotel|hostel|resort", d$property_type, ignore.case=TRUE)
eda <- d[d$valid_price, ]
group_summary <- function(data, fields, fun) {
  pieces <- split(data, interaction(data[fields], drop = TRUE, lex.order = TRUE))
  out <- do.call(rbind, lapply(pieces, function(g) {
    result <- fun(g)
    keys <- g[rep(1, nrow(result)), fields, drop = FALSE]
    rownames(keys) <- NULL
    rownames(result) <- NULL
    cbind(keys, result)
  }))
  rownames(out) <- NULL
  out
}
coverage <- group_summary(d, c("borough", "room_type"), function(g) data.frame(
  scoped_n = nrow(g), observed_positive_n = sum(g$valid_price),
  missing_price_n = sum(!g$price_observed), unusable_price_n = sum(!g$valid_price),
  missing_price_pct = 100 * mean(!g$price_observed),
  positive_price_pct = 100 * mean(g$valid_price)))
eda_csv(coverage, "price_coverage_by_group.csv")
stay <- group_summary(d, c("borough", "room_type", "price_status", "stay_group"),
  function(g) data.frame(n = nrow(g)))
denom <- aggregate(n ~ borough + room_type + price_status, stay, sum)
names(denom)[4] <- "status_group_n"
stay <- merge(stay, denom, by = c("borough", "room_type", "price_status"), sort = TRUE)
stay$within_status_pct <- 100 * stay$n / stay$status_group_n
eda_csv(stay, "minimum_stay_by_price_status.csv")
selection <- group_summary(d, c("borough", "room_type", "price_status"), function(g) data.frame(
  n = nrow(g), accommodates_observed_n = sum(is.finite(g$accommodates)),
  accommodates_median = safe_median(g$accommodates), bedrooms_observed_n = sum(is.finite(g$bedrooms)),
  bedrooms_median = safe_median(g$bedrooms), minimum_nights_observed_n = sum(is.finite(g$minimum_nights)),
  minimum_nights_median = safe_median(g$minimum_nights),
  rating_observed_n = sum(is.finite(g$review_scores_rating)),
  rating_missing_pct = 100 * mean(is.na(g$review_scores_rating))))
eda_csv(selection, "observed_characteristics_by_price_status.csv")
describe <- function(g) {
  do.call(rbind, lapply(c("price", "log_price", "accommodates", "bedrooms", "minimum_nights", "review_scores_rating"), function(v) {
    z <- g[[v]]; z <- z[is.finite(z)]
    q <- if(length(z)) unname(quantile(z, c(0, .25, .5, .75, 1))) else rep(NA_real_,5)
    data.frame(variable = v, sample_n = nrow(g), observed_n = length(z), missing_n = nrow(g)-length(z),
      mean = if(length(z)) mean(z) else NA_real_, sd = if(length(z)>1) sd(z) else NA_real_,
      min = q[1], q25 = q[2], median = q[3], q75 = q[4], max = q[5])
  }))
}
overall <- describe(eda)
eda_csv(overall, "descriptive_overall.csv")
by_group <- group_summary(eda, c("borough", "room_type"), describe)
eda_csv(by_group, "descriptive_by_group.csv")
stay_prices <- group_summary(eda, c("borough", "room_type", "stay_group"), function(g) data.frame(
  n = nrow(g), median_price_usd = median(g$price), q25_price_usd = unname(quantile(g$price,.25)),
  q75_price_usd = unname(quantile(g$price,.75))))
eda_csv(stay_prices, "price_by_group_and_minimum_stay.csv")
# Exact counts expose sparse covariate combinations; no extrapolation is attempted.
capacity <- group_summary(eda, c("borough", "room_type", "accommodates"), function(g)
  data.frame(n = nrow(g), median_log_price = median(g$log_price)))
eda_csv(capacity, "capacity_support.csv")
bedroom_support <- group_summary(eda, c("borough", "room_type", "bedrooms"), function(g) data.frame(n=nrow(g)))
eda_csv(bedroom_support, "bedroom_support.csv")
# Property types are descriptive only: no hotel-like records are silently removed.
property <- data.frame(borough = raw$neighbourhood_group_cleansed[scope], room_type = raw$room_type[scope],
  property_type = raw$property_type[scope], price_status = d$price_status)
stopifnot(nrow(property) == nrow(d))
property$property_type[is.na(property$property_type) | property$property_type == ""] <- "Missing"
property_counts <- group_summary(property, c("borough", "room_type", "price_status", "property_type"), function(g) data.frame(n=nrow(g)))
eda_csv(property_counts, "property_type_composition.csv")
hotel_summary <- group_summary(eda, c("borough", "room_type"), function(g) data.frame(
  n=nrow(g), hotel_like_label_n=sum(g$hotel_like_label),
  hotel_like_label_pct=100*mean(g$hotel_like_label), missing_property_type_n=sum(g$property_type=="Missing")))
eda_csv(hotel_summary,"hotel_like_labels_by_group.csv")
hotel_stay <- group_summary(eda,c("borough","room_type","stay_group","hotel_like_label"),function(g)
  data.frame(n=nrow(g),median_price_usd=median(g$price)))
eda_csv(hotel_stay,"price_by_stay_and_hotel_label.csv")
eda_csv(unique(eda[,c("property_type","hotel_like_label")]),"property_label_classification.csv")
stopifnot(sum(coverage$scoped_n) == nrow(d), sum(coverage$observed_positive_n) == nrow(eda),
          sum(stay$n) == nrow(d), sum(stay_prices$n) == nrow(eda),
          sum(property_counts$n) == nrow(d))
write.csv(eda, "data/processed/eda_with_stay_groups.csv", row.names=FALSE, na="")

# ===== END scripts/03_descriptive_analysis.R =====
library(ggplot2)
dir.create("figures", showWarnings = FALSE)
colors <- c("Entire home/apt" = "#287B85", "Private room" = "#B56830")
base_theme <- theme_minimal(base_size = 12, base_family = "sans") +
  theme(plot.title = element_text(face="bold", size=17, color="#203039"),
        plot.subtitle = element_text(size=11, color="#4B5960", margin=margin(b=12)),
        panel.grid.minor = element_blank(), panel.grid.major.x = element_blank(),
        legend.position="top", legend.title=element_blank(),
        plot.caption=element_text(hjust=0, size=9, color="#4B5960", margin=margin(t=12)),
        plot.margin=margin(15,20,15,15), strip.text=element_text(face="bold", size=12))
source_note <- paste0("Source: Inside Airbnb NYC, snapshot ", snapshot_date,
                      " (scraped ", source_manifest$observed_scrape_min, " to ", source_manifest$observed_scrape_max, ").")
count_labels <- function(x) format(x, big.mark=",", scientific=FALSE, trim=TRUE)
usd <- function(x) paste0("$", format(round(x), big.mark=",", scientific=FALSE, trim=TRUE))
bin_counts <- function(x, width, origin=0) {
  lo <- min(origin, floor(min(x)/width)*width)
  hi <- (floor(max(x)/width)+1)*width
  h <- hist(x, breaks=seq(lo,hi,by=width), plot=FALSE, right=FALSE, include.lowest=TRUE)
  stopifnot(sum(h$counts)==length(x))
  data.frame(left=head(h$breaks,-1), right=tail(h$breaks,-1), n=h$counts)
}
hist_plot <- function(bins) ggplot(bins) +
  geom_rect(aes(xmin=left, xmax=right, ymin=0, ymax=n), fill="#287B85", color="white", linewidth=.15) +
  scale_y_continuous(labels=count_labels, expand=expansion(mult=c(0,.08))) + base_theme
full_bins <- bin_counts(eda$price,250)
detail_bins <- bin_counts(eda$price,25)
eda_csv(full_bins,"figure01_full_bins.csv")
eda_csv(detail_bins,"figure01_detail_bins.csv")
zoom_limit <- unname(quantile(eda$price,.99))
hidden_zoom <- sum(eda$price>zoom_limit)
raw_full <- hist_plot(full_bins) + scale_x_continuous(labels=usd, expand=expansion(mult=c(0,.01))) +
  labs(title="01  |  Daily listing prices have a long upper tail",
       subtitle=paste0("Full range | n = ",fmt(nrow(eda))," | $250 bins | all positive prices retained"),
       x="Daily listing price (USD)", y="Number of listings")
raw_detail <- hist_plot(detail_bins) + scale_x_continuous(labels=usd) +
  coord_cartesian(xlim=c(0,zoom_limit), expand=FALSE) +
  labs(title="Detail of the main price range",
       subtitle=paste0("Display zoom to the 99th percentile (",usd(zoom_limit),") | $25 bins"),
       x="Daily listing price (USD)",y="Number of listings",
       caption=paste0(source_note,"\n",fmt(hidden_zoom)," prices above the zoom limit remain in the data and full-range panel."))
png_device <- function(path,width,height) {
  if(requireNamespace("ragg",quietly=TRUE)) ragg::agg_png(path,width=width,height=height,units="in",res=180)
  else grDevices::png(path,width=width,height=height,units="in",res=180)
}
png_device("figures/01_raw_price_distribution.png",10,9)
grid::grid.newpage()
grid::pushViewport(grid::viewport(layout=grid::grid.layout(2,1,heights=c(1,1.1))))
print(raw_full,vp=grid::viewport(layout.pos.row=1,layout.pos.col=1))
print(raw_detail,vp=grid::viewport(layout.pos.row=2,layout.pos.col=1))
dev.off()
log_bins <- bin_counts(eda$log_price,.2,origin=floor(min(eda$log_price)/.2)*.2)
eda_csv(log_bins,"figure02_log_bins.csv")
log_plot <- hist_plot(log_bins) + labs(title="02  |  Listing prices on the natural-log scale",
  subtitle=paste0("Same ",fmt(nrow(eda))," listings | bin width = 0.2 log units | no price trimming"),
  x="Natural log of daily listing price in USD", y="Number of listings",
  caption=paste0(source_note,"\nA transformed outcome distribution does not by itself validate regression assumptions."))
save_plot <- function(plot,path,width=10,height=6.5) {
  png_device(path,width,height); print(plot); dev.off()
}
save_plot(log_plot,"figures/02_log_price_distribution.png")
box_n <- group_summary(eda,c("borough","room_type"),function(g) data.frame(n=nrow(g)))
box_n$label <- paste0("n = ",fmt(box_n$n))
box_n$label_y <- max(eda$log_price)+.25
eda_csv(box_n,"figure03_group_labels.csv")
box_plot <- ggplot(eda,aes(borough,log_price,fill=room_type)) +
  geom_boxplot(position=position_dodge(width=.8),width=.65,outlier.alpha=.25,outlier.size=.7) +
  geom_text(data=box_n,aes(x=borough,y=label_y,label=label,group=room_type),
    inherit.aes=FALSE,position=position_dodge(width=.8),size=3.3) +
  scale_fill_manual(values=colors) + scale_y_continuous(expand=expansion(mult=c(.03,.08))) + base_theme +
  labs(title="03  |  Price distributions across the four study groups",
       subtitle="Unadjusted comparisons | all observed positive prices included",
       x="Borough",y="Natural log of daily listing price in USD",
       caption=paste0(source_note,"\nBoxes: median and interquartile range; whiskers: up to 1.5 IQR; points: observations beyond whiskers."))
save_plot(box_plot,"figures/03_price_by_borough_room_type.png")
scatter_data <- eda[whole(eda$accommodates) & eda$accommodates>=1,]
scatter_excluded <- nrow(eda)-nrow(scatter_data)
median_points <- capacity[capacity$n>=20 & whole(capacity$accommodates) & capacity$accommodates>=1,]
eda_csv(median_points,"figure04_capacity_medians.csv")
scatter_plot <- ggplot(scatter_data,aes(accommodates,log_price,color=room_type)) +
  geom_point(position=position_jitter(width=.12,height=0,seed=20261118),alpha=.16,size=.9) +
  geom_point(data=median_points,aes(y=median_log_price,fill=room_type),shape=23,size=2.8,color="#203039",stroke=.35) +
  facet_wrap(~borough,nrow=1) + scale_color_manual(values=colors) +
  scale_fill_manual(values=colors,guide="none") +
  guides(color=guide_legend(override.aes=list(alpha=1,size=3))) +
  scale_x_continuous(breaks=c(1,2,4,6,8,10,12,14,16)) + base_theme +
  labs(title="04  |  Guest capacity and price, by room type and borough",
       subtitle=paste0("All ",fmt(nrow(scatter_data))," eligible listings | horizontal jitter only; prices unchanged"),
       x="Maximum guest capacity (persons)",y="Natural log of daily listing price in USD",
       caption=paste0(source_note,"\nDiamonds: median log price for borough/room-type/capacity cells with at least 20 listings.",
         "\nExcluded for missing/invalid capacity: ",scatter_excluded,". Sparse cells remain visible as individual points."))
save_plot(scatter_plot,"figures/04_capacity_price_multidimensional.png",11,7)
plot_manifest <- data.frame(figure=1:4,
  file=c("01_raw_price_distribution.png","02_log_price_distribution.png","03_price_by_borough_room_type.png","04_capacity_price_multidimensional.png"),
  sample_n=c(rep(nrow(eda),3),nrow(scatter_data)),
  additional_excluded_n=c(0,0,0,scatter_excluded),
  notes=c("Full sample; second panel only zooms display", "Natural log; same sample", "Unadjusted; all outliers retained", "Capacity valid; fixed horizontal jitter seed"))
eda_csv(plot_manifest,"figure_manifest.csv")
stopifnot(all(file.exists(file.path("figures",plot_manifest$file))))
price_rows <- by_group[by_group$variable=="price",]
summarize_group <- function(i) {
  z<-price_rows[i,]
  paste0("- ",z$borough," / ",z$room_type,": n = ",fmt(z$observed_n),
    "; median $",sprintf("%.2f",z$median),"; Q1-Q3 $",sprintf("%.2f",z$q25),"-$",sprintf("%.2f",z$q75),
    "; mean $",sprintf("%.2f",z$mean),"; SD $",sprintf("%.2f",z$sd),".")
}
long_stay <- stay[stay$price_status=="Observed positive price" & stay$stay_group=="30+ nights",]
price_overall <- overall[overall$variable=="price",]
mh <- price_rows[price_rows$borough=="Manhattan",]
mh_long <- stay_prices[stay_prices$borough=="Manhattan" & stay_prices$stay_group=="30+ nights",]
mh_private_hotel <- hotel_summary[hotel_summary$borough=="Manhattan" & hotel_summary$room_type=="Private room",]
mh_private_selection <- selection[selection$borough=="Manhattan" & selection$room_type=="Private room",]
md <- c("# Exploratory data analysis: NYC Airbnb listing prices", "",
 "Generated entirely from the pinned source snapshot by `Rscript --vanilla scripts/04_generate_eda.R`.",
 "All numerical statements, table files and figures are computed by R. This is descriptive analysis, not regression inference.", "",
 "## Data and sample", "",
 paste0(source_note," The raw file contains ",fmt(nrow(raw))," listings and ",ncol(raw)," fields."),
 paste0("The scope is Manhattan/Brooklyn and Entire home/apt/Private room (",fmt(nrow(d))," listings). ",
   "The EDA sample contains ",fmt(nrow(eda))," listings with observed, finite, positive daily prices. ",
   "No high-price trimming, imputation or subsampling is used."),
 "Missing ratings/bedrooms do not exclude listings from price plots. Figure 4 additionally requires valid guest capacity.", "",
 "## Price coverage and minimum-stay composition", "",
 paste0(fmt(sum(!d$price_observed))," scoped listings lack a price (",sprintf("%.1f",100*mean(!d$price_observed)),
   "%). Positive-price coverage is not equal across the four groups:"), "",
 vapply(seq_len(nrow(coverage)),function(i) {z<-coverage[i,];paste0("- ",z$borough," / ",z$room_type,": ",
   fmt(z$observed_positive_n)," of ",fmt(z$scoped_n)," (",sprintf("%.1f",z$positive_price_pct),"%).")},character(1)), "",
 "These coverage differences limit generalization. A complete-case price analysis does not resolve selection from missing prices.",
 paste0("Within Manhattan Private room, median minimum stay is ",
   mh_private_selection$minimum_nights_median[mh_private_selection$price_status=="Observed positive price"],
   " nights for listings with observed positive prices and ",
   mh_private_selection$minimum_nights_median[mh_private_selection$price_status=="No usable price"],
   " nights for listings without usable prices. Thus price-observed and price-missing records differ on at least this observed characteristic; this does not identify the missing-data mechanism."), "",
 "Among positive-price listings, the proportions requiring at least 30 nights are:", "",
 vapply(seq_len(nrow(long_stay)),function(i) {z<-long_stay[i,];paste0("- ",z$borough," / ",z$room_type,": ",
   fmt(z$n)," / ",fmt(z$status_group_n)," (",sprintf("%.1f",z$within_status_pct),"%).")},character(1)),
 paste0("Minimum stay is missing/invalid for ",sum(eda$stay_group=="Missing/invalid")," positive-price listings; denominators above include these records."),
 "The sample mixes minimum-stay regimes. It should not be described as exclusively short-stay accommodation; compare within stay groups before interpreting room-type differences.", "",
 "## Property-type composition", "",
 paste0("Room type alone does not identify residential accommodation. Within Manhattan Private room listings with positive prices, ",
   fmt(mh_private_hotel$hotel_like_label_n)," of ",fmt(mh_private_hotel$n)," (",sprintf("%.1f",mh_private_hotel$hotel_like_label_pct),
   "%) have property_type text containing hotel, hostel or resort (case-insensitive). ",
   "This is a transparent text flag, not a verified business or legal classification. No such records were excluded from these plots."),
 "The exact property labels and group counts are in property_type_composition.csv and property_label_classification.csv. A residential-scope sensitivity analysis should be considered before final modeling; room_type = Private room must not be described as exclusively a room in someone's home.", "",
 "## Descriptive price statistics", "",
 paste0("Overall: median $",sprintf("%.2f",price_overall$median),"; mean $",sprintf("%.2f",price_overall$mean),
   "; SD $",sprintf("%.2f",price_overall$sd),"; range $",sprintf("%.2f",price_overall$min),"-$",sprintf("%.2f",price_overall$max),"."), "",
 vapply(seq_len(nrow(price_rows)),summarize_group,character(1)), "",
 "Group summaries describe observed prices without adjustment for capacity, bedrooms, minimum stay or other characteristics. They are not estimates of causal effects or tests of significance.", "",
 "## Figure 1: raw prices", "", "![Raw price distribution](../../figures/01_raw_price_distribution.png)", "",
 paste0("The mean exceeds the median and the full-range panel shows the long upper tail. ",
   "The lower panel zooms to $",sprintf("%.2f",zoom_limit)," (the sample 99th percentile); ",
   fmt(hidden_zoom)," prices above this value remain in the dataset. The two panels have different, explicitly labeled bin widths."), "",
 "## Figure 2: log prices", "", "![Natural-log price distribution](../../figures/02_log_price_distribution.png)", "",
 "The natural log compresses the upper tail, making the main distribution easier to inspect. This supports examining a log-price model but does not establish linearity, constant residual variance, residual normality or independence.", "",
 "## Figure 3: four-group comparisons", "", "![Borough and room type boxplots](../../figures/03_price_by_borough_room_type.png)", "",
 paste0("In Manhattan, the unadjusted median is $",sprintf("%.2f",mh$median[mh$room_type=="Private room"]),
   " for Private room and $",sprintf("%.2f",mh$median[mh$room_type=="Entire home/apt"]),
   " for Entire home/apt. Within listings requiring 30+ nights, these medians are $",
   sprintf("%.2f",mh_long$median_price_usd[mh_long$room_type=="Private room"])," and $",
   sprintf("%.2f",mh_long$median_price_usd[mh_long$room_type=="Entire home/apt"]),
   ", respectively. The descriptive contrast changes substantially with the minimum-stay subset; this is not a causal decomposition."),
 "Compare group medians and within-group spread against the computed descriptive statistics above. Distribution overlap and different minimum-stay compositions make a universal claim that one room type is more expensive premature. Covariate adjustment and interaction contrasts are needed later.", "",
 "## Figure 4: capacity, price, room type and borough", "", "![Multidimensional capacity plot](../../figures/04_capacity_price_multidimensional.png)", "",
 paste0("This plot displays four variables: guest capacity (x), log price (y), room type (color) and borough (panel). ",
   "All ",fmt(nrow(scatter_data))," eligible observations are drawn. ",scatter_excluded," price-eligible listings are excluded for invalid/missing capacity. ",
   "Diamond markers summarize cells with at least 20 records, while all sparse cells still appear as points. ",
   "High-capacity combinations should be checked against capacity_support.csv before interpreting fitted comparisons."), "",
 "## Research objectives and next analysis", "",
 "1. Estimate adjusted borough differences within each room type.",
 "2. Estimate adjusted room-type differences within each borough.",
 "3. Test whether the room-type association differs by borough (interaction).", "",
 "The candidate model uses log(price), borough, room type, their interaction, capacity, bedrooms and a suitable representation of minimum stay. Rating inclusion is a separate sensitivity decision because of missingness. No regression model is fitted in this stage.",
 "Before fitting: review observed-price selection, property-type composition, capacity overlap, influential extremes and repeated hosts; reserve a test set and use appropriate training-only model decisions. Subsequent inference should report effect sizes, intervals, diagnostics and the required MSPR/MSE comparison.", "",
 "## Reproducibility and outputs", "",
 "Run `Rscript --vanilla scripts/04_generate_eda.R` from the repository root. Install ggplot2 first if needed; ragg is optional for PNG rendering. Raw and row-level derived data remain local and reproducible. PNG figures and aggregate CSV results are versioned.",
 "See figure_manifest.csv for per-figure sample sizes; descriptive_overall.csv and descriptive_by_group.csv for statistics; observed_characteristics_by_price_status.csv and minimum_stay_by_price_status.csv for selection checks; price_by_group_and_minimum_stay.csv for within-stay descriptive comparisons.", "",
 "Source: [Inside Airbnb](https://insideairbnb.com/get-the-data/), NYC detailed listings; CC BY 4.0. The snapshot is observational and is not a random sample of all NYC accommodation or observed transactions.")
writeLines(md,"reports/eda/eda_report.md")
writeLines(sub("[[:space:]]+$","",capture.output(sessionInfo())),"reports/eda/session_info.txt")
message("Generated four figures, descriptive CSVs, and reports/eda/eda_report.md")

# ===== END scripts/04_generate_eda.R =====
dir.create("figures/final",recursive=TRUE,showWarnings=FALSE)
report_theme<-theme_minimal(base_size=11)+theme(panel.grid.minor=element_blank(),legend.position="top",
  legend.title=element_blank(),plot.title=element_text(size=12,face="bold"),plot.subtitle=element_text(size=9),
  plot.caption=element_text(size=8,hjust=0),plot.margin=margin(5,8,5,5))
save_plot(raw_full+labs(title="Figure 1  Daily listing prices in USD",subtitle=paste0("Full range; n = ",fmt(nrow(eda)),"; $250 bins"),caption=NULL)+report_theme,
  "figures/final/04_report_raw_prices.png",7,2.55)
save_plot(log_plot+labs(title="Figure 2  Natural log of daily price",subtitle="Same observations; bin width = 0.2",caption=NULL)+report_theme,
  "figures/final/05_report_log_prices.png",7,2.55)
save_plot(box_plot+labs(title="Figure 3  Unadjusted borough and room comparisons",subtitle=NULL,caption=NULL)+report_theme,
  "figures/final/06_report_group_prices.png",7,3.05)
save_plot(scatter_plot+labs(title="Figure 4  Capacity and price across the four groups",subtitle=NULL,caption=NULL)+report_theme,
  "figures/final/07_report_capacity.png",7,3.2)

# ===== BEGIN scripts/15_freeze_final_model.R =====
# Regenerate TRAINING work; never read test errors when making this record.

# ===== BEGIN scripts/14_complete_training_review.R =====

# ===== BEGIN scripts/12_training_report.R =====
# Complete entry point for the training-model stage; all numerical text is computed.

# ===== BEGIN scripts/11_refine_training_model.R =====

# ===== BEGIN scripts/10_training_diagnostics.R =====
# Draw training-only diagnostics and planned contrasts from fitted objects.

# ===== BEGIN scripts/09_fit_training_models.R =====
# Training-only regression stage. No held-out errors or test predictions are computed.
if(dir.exists(".r-library")) .libPaths(c(normalizePath(".r-library"),.libPaths()))
if(!requireNamespace("sandwich",quietly=TRUE)) stop("Run Rscript --vanilla scripts/setup_model_dependencies.R first.")

# ===== BEGIN scripts/05_prepare_model_samples.R =====
# Creates model-ready samples and a host-level split; fits no model and scores no test outcomes.

# ===== BEGIN scripts/03_descriptive_analysis.R =====
# Rebuild the audited sample from the pinned raw snapshot; never rely on hand edits.

# ===== BEGIN scripts/02_audit_data.R =====

# ===== BEGIN scripts/01_download_data.R =====

# ===== BEGIN scripts/00_config.R =====
# Run scripts from the repository root. No external R packages are required.
snapshot_date <- "2026-09-14"
source_url <- paste0("https://data.insideairbnb.com/united-states/ny/",
                     "new-york-city/", snapshot_date, "/data/listings.csv.gz")
raw_path <- file.path("data", "raw", paste0("nyc_listings_", snapshot_date, ".csv.gz"))
# Fingerprint of the actual downloaded file; reject silently changed snapshots.
expected_md5 <- "d246ef4c52a914b514419cb5839dd9d7"
source_sha256 <- "a67bf574e47aa6eba5b2262987dbd9684f206d5cd0183470056f9c936b8e7ae1"
for (folder in c("data/raw", "data/processed", "reports/audit")) {
  dir.create(folder, recursive = TRUE, showWarnings = FALSE)
}

# ===== END scripts/00_config.R =====
if (!file.exists(raw_path)) {
  options(timeout = max(180, getOption("timeout")))
  temporary <- paste0(raw_path, ".download")
  download.file(source_url, temporary, mode = "wb", method = "libcurl")
  if (!identical(unname(tools::md5sum(temporary)), expected_md5)) {
    stop("Downloaded file differs from the pinned snapshot. Investigate before proceeding.")
  }
  if (!file.rename(temporary, raw_path)) stop("Could not save downloaded snapshot.")
}
if (!identical(unname(tools::md5sum(raw_path)), expected_md5)) {
  stop("Local raw file does not match the pinned fingerprint; do not use it.")
}
message("Verified pinned Inside Airbnb snapshot: ", raw_path)

# ===== END scripts/01_download_data.R =====
# Character import preserves long listing IDs exactly and retains source strings.
raw <- read.csv(gzfile(raw_path), colClasses = "character", check.names = FALSE,
                na.strings = c("", "NA"), stringsAsFactors = FALSE)
required <- c("id", "host_id", "last_scraped", "neighbourhood_group_cleansed",
              "room_type", "price", "accommodates", "bedrooms", "minimum_nights",
              "review_scores_rating")
if (length(setdiff(required, names(raw)))) stop("Required source fields are missing.")
missing <- function(x) is.na(x) | trimws(x) == ""
if (any(missing(raw$id)) || anyDuplicated(raw$id)) {
  stop("Missing or duplicate listing IDs: resolve explicitly before creating a sample.")
}
save_csv <- function(x, filename) {
  write.csv(x, file.path("reports/audit", filename), row.names = FALSE, na = "")
}
save_csv(data.frame(field = names(raw), missing_n = vapply(raw, function(x)
  sum(missing(x)), integer(1))), "all_fields.csv")
scope <- raw$neighbourhood_group_cleansed %in% c("Manhattan", "Brooklyn") &
  raw$room_type %in% c("Entire home/apt", "Private room")
d <- raw[scope, required]
names(d)[names(d) == "neighbourhood_group_cleansed"] <- "borough"
names(d)[names(d) == "price"] <- "price_raw"
numeric_fields <- c("accommodates", "bedrooms", "minimum_nights", "review_scores_rating")
parse_failures <- data.frame(field = character(), failed_nonmissing_n = integer())
for (field in numeric_fields) {
  original <- d[[field]]
  d[[field]] <- suppressWarnings(as.numeric(original))
  parse_failures <- rbind(parse_failures, data.frame(field = field,
    failed_nonmissing_n = sum(!missing(original) & is.na(d[[field]]))))
}
price_string <- gsub("[$,]", "", trimws(d$price_raw))
d$price <- suppressWarnings(as.numeric(price_string))
parse_failures <- rbind(parse_failures, data.frame(field = "price",
  failed_nonmissing_n = sum(!missing(d$price_raw) & is.na(d$price))))
save_csv(parse_failures, "parse_failures.csv")
d$price_observed <- !missing(d$price_raw)
d$valid_price <- is.finite(d$price) & d$price > 0
whole <- function(x) is.finite(x) & x == floor(x)
d$valid_core_covariates <- whole(d$accommodates) & d$accommodates >= 1 &
  whole(d$bedrooms) & d$bedrooms >= 0 &
  whole(d$minimum_nights) & d$minimum_nights >= 1
d$valid_rating <- is.finite(d$review_scores_rating) &
  d$review_scores_rating >= 0 & d$review_scores_rating <= 5
d$log_price <- NA_real_
d$log_price[d$valid_price] <- log(d$price[d$valid_price])
eda <- d[d$valid_price, ]
stopifnot(nrow(eda) > 0, all(is.finite(eda$log_price)))
write.csv(d, "data/processed/scoped_listings_with_flags.csv", row.names = FALSE, na = "")
write.csv(eda, "data/processed/eda_positive_price.csv", row.names = FALSE, na = "")
flow <- data.frame(stage = c("Raw NYC snapshot", "Two boroughs and two room types",
  "Observed finite positive price (preliminary EDA sample)",
  "Also valid complete core covariates (candidate, not final model sample)",
  "Also valid observed rating (candidate sensitivity sample)"),
  n = c(nrow(raw), nrow(d), nrow(eda), sum(d$valid_price & d$valid_core_covariates),
    sum(d$valid_price & d$valid_core_covariates & d$valid_rating)))
save_csv(flow, "sample_flow.csv")
groups <- split(d, interaction(d$borough, d$room_type, drop = TRUE))
group_audit <- do.call(rbind, lapply(groups, function(g) {
  p <- g$price[g$valid_price]
  data.frame(borough = g$borough[1], room_type = g$room_type[1], scoped_n = nrow(g),
    missing_price_n = sum(!g$price_observed), valid_price_n = length(p),
    valid_price_pct = 100 * mean(g$valid_price),
    core_complete_n = sum(g$valid_price & g$valid_core_covariates),
    rating_missing_in_eda_n = sum(g$valid_price & is.na(g$review_scores_rating)),
    median_price_usd = if(length(p)) median(p) else NA_real_,
    minimum_nights_ge30_in_eda_n = sum(g$valid_price & g$minimum_nights >= 30, na.rm = TRUE))
}))
rownames(group_audit) <- NULL
stopifnot(sum(group_audit$scoped_n) == nrow(d), sum(group_audit$valid_price_n) == nrow(eda))
save_csv(group_audit, "group_audit.csv")
fields <- c("price", numeric_fields)
missingness <- do.call(rbind, lapply(list(scoped = d, positive_price = eda), function(g) {
  data.frame(field = fields, n = nrow(g),
    missing_n = vapply(g[fields], function(x) sum(is.na(x)), integer(1)))
}))
missingness$sample <- rep(c("scoped", "positive_price"), each = length(fields))
rownames(missingness) <- NULL
save_csv(missingness, "missingness.csv")
numeric_summary <- do.call(rbind, lapply(fields, function(field) {
  x <- eda[[field]]; x <- x[is.finite(x)]
  q <- if(length(x)) unname(quantile(x, c(0, .25, .5, .75, .99, 1))) else rep(NA_real_, 6)
  data.frame(field = field, observed_n = length(x), mean = if(length(x)) mean(x) else NA_real_,
    sd = if(length(x)>1) sd(x) else NA_real_, min = q[1], q25 = q[2],
    median = q[3], q75 = q[4], q99 = q[5], max = q[6])
}))
save_csv(numeric_summary, "numeric_summary_positive_price.csv")
known_host <- !missing(eda$host_id)
host_sizes <- table(eda$host_id[known_host])
host_audit <- data.frame(known_hosts_n = length(host_sizes),
  hosts_with_multiple_scoped_priced_listings_n = sum(host_sizes > 1),
  listings_from_those_hosts_n = sum(host_sizes[host_sizes > 1]),
  max_scoped_priced_listings_per_host = if(length(host_sizes)) max(host_sizes) else NA_integer_,
  listings_missing_host_id_n = sum(!known_host))
save_csv(host_audit, "host_audit.csv")
save_csv(as.data.frame(table(raw$last_scraped), responseName = "n"), "scrape_dates.csv")
source_manifest <- data.frame(provider = "Inside Airbnb", snapshot_label = snapshot_date,
  observed_scrape_min = min(raw$last_scraped, na.rm=TRUE),
  observed_scrape_max = max(raw$last_scraped, na.rm=TRUE), url = source_url,
  local_file = raw_path, bytes = file.info(raw_path)$size,
  md5 = unname(tools::md5sum(raw_path)), sha256_at_acquisition = source_sha256,
  raw_rows = nrow(raw), raw_columns = ncol(raw))
save_csv(source_manifest, "source_manifest.csv")
fmt <- function(x) format(x, big.mark = ",", scientific = FALSE, trim = TRUE)
lines <- c("# Data audit: NYC Airbnb", "",
  "Generated by `Rscript --vanilla scripts/02_audit_data.R`; do not edit numerical results by hand.", "",
  paste0("Source: Inside Airbnb; snapshot label ", snapshot_date, "."),
  paste0("Observed scraping dates: ", source_manifest$observed_scrape_min, " to ", source_manifest$observed_scrape_max, "."),
  paste0("Raw file: ", fmt(nrow(raw)), " listings and ", ncol(raw), " fields; listing IDs are unique and nonmissing."), "",
  "## Sample accounting", "",
  paste0("- ", flow$stage, ": ", fmt(flow$n), "."), "",
  paste0("Missing price in scope: ", fmt(sum(!d$price_observed)), " (",
    sprintf("%.1f", 100*mean(!d$price_observed)), "% of scoped listings)."),
  paste0("Observed but nonfinite/nonpositive/unparseable prices: ",
    sum(d$price_observed & !d$valid_price), "."), "",
  "## Four-group coverage", "",
  vapply(seq_len(nrow(group_audit)), function(i) {
    g <- group_audit[i, ]
    paste0("- ", g$borough, " / ", g$room_type, ": ", fmt(g$scoped_n),
      " scoped; ", fmt(g$valid_price_n), " positive-price listings (",
      sprintf("%.1f", g$valid_price_pct), "%); median observed positive price $",
      sprintf("%.2f", g$median_price_usd), ".")
  }, character(1)), "", "## Decisions and limits", "",
  "- This is a preliminary EDA sample, not a finalized regression sample.",
  "- No price trimming, winsorization, imputation, random subsampling, or model fitting was performed.",
  "- Missing prices are not replaced by zero or another price-quote field. Coverage must be discussed before inference.",
  "- Bedrooms equal to zero are allowed; missing bedrooms are not assumed to mean a studio.",
  "- Missing ratings are retained in the scoped and EDA datasets; a rating is not required for EDA.",
  paste0("- ", fmt(sum(eda$minimum_nights >= 30, na.rm = TRUE)), " of ", fmt(nrow(eda)),
    " positive-price listings have minimum_nights >= 30; do not describe this sample as exclusively short stays."),
  paste0("- ", fmt(host_audit$hosts_with_multiple_scoped_priced_listings_n),
    " known hosts have multiple scoped positive-price listings, accounting for ",
    fmt(host_audit$listings_from_those_hosts_n), " listings; assess dependence before model inference/splitting."),
  "- Comparisons are observational associations in this snapshot, not causal effects or realized transaction prices.",
  "- Inspect missing-price selection, covariate overlap, and price semantics before finalizing the model.", "",
  "All detailed counts are in the adjacent CSV files. Row-level data are regenerated locally and excluded from Git.")
writeLines(lines, "reports/audit/data_audit.md")
writeLines(sub("[[:space:]]+$", "", capture.output(sessionInfo())),
           "reports/audit/session_info.txt")
cat(paste(lines, collapse = "\n"), "\n")

# ===== END scripts/02_audit_data.R =====
dir.create("reports/eda", recursive = TRUE, showWarnings = FALSE)
eda_csv <- function(x, name) write.csv(x, file.path("reports/eda", name),
                                     row.names = FALSE, na = "")
safe_median <- function(x) if (any(is.finite(x))) median(x[is.finite(x)]) else NA_real_
d$borough <- factor(d$borough, c("Brooklyn", "Manhattan"))
d$room_type <- factor(d$room_type, c("Entire home/apt", "Private room"))
d$price_status <- ifelse(d$valid_price, "Observed positive price", "No usable price")
d$stay_group <- ifelse(!whole(d$minimum_nights) | d$minimum_nights < 1,
                       "Missing/invalid", ifelse(d$minimum_nights >= 30, "30+ nights", "1-29 nights"))
d$property_type <- raw$property_type[scope]
d$property_type[is.na(d$property_type) | d$property_type == ""] <- "Missing"
# Descriptive string rule, not a legal or verified business classification.
d$hotel_like_label <- grepl("hotel|hostel|resort", d$property_type, ignore.case=TRUE)
eda <- d[d$valid_price, ]
group_summary <- function(data, fields, fun) {
  pieces <- split(data, interaction(data[fields], drop = TRUE, lex.order = TRUE))
  out <- do.call(rbind, lapply(pieces, function(g) {
    result <- fun(g)
    keys <- g[rep(1, nrow(result)), fields, drop = FALSE]
    rownames(keys) <- NULL
    rownames(result) <- NULL
    cbind(keys, result)
  }))
  rownames(out) <- NULL
  out
}
coverage <- group_summary(d, c("borough", "room_type"), function(g) data.frame(
  scoped_n = nrow(g), observed_positive_n = sum(g$valid_price),
  missing_price_n = sum(!g$price_observed), unusable_price_n = sum(!g$valid_price),
  missing_price_pct = 100 * mean(!g$price_observed),
  positive_price_pct = 100 * mean(g$valid_price)))
eda_csv(coverage, "price_coverage_by_group.csv")
stay <- group_summary(d, c("borough", "room_type", "price_status", "stay_group"),
  function(g) data.frame(n = nrow(g)))
denom <- aggregate(n ~ borough + room_type + price_status, stay, sum)
names(denom)[4] <- "status_group_n"
stay <- merge(stay, denom, by = c("borough", "room_type", "price_status"), sort = TRUE)
stay$within_status_pct <- 100 * stay$n / stay$status_group_n
eda_csv(stay, "minimum_stay_by_price_status.csv")
selection <- group_summary(d, c("borough", "room_type", "price_status"), function(g) data.frame(
  n = nrow(g), accommodates_observed_n = sum(is.finite(g$accommodates)),
  accommodates_median = safe_median(g$accommodates), bedrooms_observed_n = sum(is.finite(g$bedrooms)),
  bedrooms_median = safe_median(g$bedrooms), minimum_nights_observed_n = sum(is.finite(g$minimum_nights)),
  minimum_nights_median = safe_median(g$minimum_nights),
  rating_observed_n = sum(is.finite(g$review_scores_rating)),
  rating_missing_pct = 100 * mean(is.na(g$review_scores_rating))))
eda_csv(selection, "observed_characteristics_by_price_status.csv")
describe <- function(g) {
  do.call(rbind, lapply(c("price", "log_price", "accommodates", "bedrooms", "minimum_nights", "review_scores_rating"), function(v) {
    z <- g[[v]]; z <- z[is.finite(z)]
    q <- if(length(z)) unname(quantile(z, c(0, .25, .5, .75, 1))) else rep(NA_real_,5)
    data.frame(variable = v, sample_n = nrow(g), observed_n = length(z), missing_n = nrow(g)-length(z),
      mean = if(length(z)) mean(z) else NA_real_, sd = if(length(z)>1) sd(z) else NA_real_,
      min = q[1], q25 = q[2], median = q[3], q75 = q[4], max = q[5])
  }))
}
overall <- describe(eda)
eda_csv(overall, "descriptive_overall.csv")
by_group <- group_summary(eda, c("borough", "room_type"), describe)
eda_csv(by_group, "descriptive_by_group.csv")
stay_prices <- group_summary(eda, c("borough", "room_type", "stay_group"), function(g) data.frame(
  n = nrow(g), median_price_usd = median(g$price), q25_price_usd = unname(quantile(g$price,.25)),
  q75_price_usd = unname(quantile(g$price,.75))))
eda_csv(stay_prices, "price_by_group_and_minimum_stay.csv")
# Exact counts expose sparse covariate combinations; no extrapolation is attempted.
capacity <- group_summary(eda, c("borough", "room_type", "accommodates"), function(g)
  data.frame(n = nrow(g), median_log_price = median(g$log_price)))
eda_csv(capacity, "capacity_support.csv")
bedroom_support <- group_summary(eda, c("borough", "room_type", "bedrooms"), function(g) data.frame(n=nrow(g)))
eda_csv(bedroom_support, "bedroom_support.csv")
# Property types are descriptive only: no hotel-like records are silently removed.
property <- data.frame(borough = raw$neighbourhood_group_cleansed[scope], room_type = raw$room_type[scope],
  property_type = raw$property_type[scope], price_status = d$price_status)
stopifnot(nrow(property) == nrow(d))
property$property_type[is.na(property$property_type) | property$property_type == ""] <- "Missing"
property_counts <- group_summary(property, c("borough", "room_type", "price_status", "property_type"), function(g) data.frame(n=nrow(g)))
eda_csv(property_counts, "property_type_composition.csv")
hotel_summary <- group_summary(eda, c("borough", "room_type"), function(g) data.frame(
  n=nrow(g), hotel_like_label_n=sum(g$hotel_like_label),
  hotel_like_label_pct=100*mean(g$hotel_like_label), missing_property_type_n=sum(g$property_type=="Missing")))
eda_csv(hotel_summary,"hotel_like_labels_by_group.csv")
hotel_stay <- group_summary(eda,c("borough","room_type","stay_group","hotel_like_label"),function(g)
  data.frame(n=nrow(g),median_price_usd=median(g$price)))
eda_csv(hotel_stay,"price_by_stay_and_hotel_label.csv")
eda_csv(unique(eda[,c("property_type","hotel_like_label")]),"property_label_classification.csv")
stopifnot(sum(coverage$scoped_n) == nrow(d), sum(coverage$observed_positive_n) == nrow(eda),
          sum(stay$n) == nrow(d), sum(stay_prices$n) == nrow(eda),
          sum(property_counts$n) == nrow(d))
write.csv(eda, "data/processed/eda_with_stay_groups.csv", row.names=FALSE, na="")

# ===== END scripts/03_descriptive_analysis.R =====

# ===== BEGIN config/model_spec.R =====
# Recorded before fitting any regression. Changes require a documented reason.
model_protocol_version <- "2026-11-18-v1"
split_seed <- 20261118L
training_host_fraction <- 0.80
excluded_property_pattern <- "hotel|hostel|resort"
reference_borough <- "Brooklyn"
reference_room_type <- "Private room"
candidate_formulas <- c(
  M0 = "log_price ~ borough + room_type",
  M1 = "log_price ~ borough + room_type + accommodates + bedrooms + log_minimum_nights + long_stay",
  M2 = "log_price ~ borough * room_type + accommodates + bedrooms + log_minimum_nights + long_stay"
)

# ===== END config/model_spec.R =====
dir.create("reports/model_preparation", recursive=TRUE, showWarnings=FALSE)
save_prep <- function(x,name) write.csv(x,file.path("reports/model_preparation",name),row.names=FALSE,na="")
d$valid_host_id <- !is.na(d$host_id) & trimws(d$host_id)!=""
d$primary_eligible <- d$valid_price & d$valid_core_covariates & d$valid_host_id
d$exclusion_reason <- ifelse(!d$valid_price,"No finite positive price",
  ifelse(!d$valid_core_covariates,"Missing or invalid core covariate",
    ifelse(!d$valid_host_id,"Missing host ID","Included")))
primary <- d[d$primary_eligible,]
primary$borough <- factor(primary$borough,levels=c(reference_borough,"Manhattan"))
primary$room_type <- factor(primary$room_type,levels=c(reference_room_type,"Entire home/apt"))
primary$log_minimum_nights <- log(primary$minimum_nights)
primary$long_stay <- as.integer(primary$minimum_nights>=30)
primary$excluded_property_label <- grepl(excluded_property_pattern,primary$property_type,ignore.case=TRUE)
primary$sensitivity_eligible <- !primary$excluded_property_label & primary$property_type!="Missing"
# Same known host always stays on the same side, including in the sensitivity subset.
hosts <- sort(unique(primary$host_id),method="radix")
RNGkind("Mersenne-Twister","Inversion","Rejection")
set.seed(split_seed)
n_train_hosts <- floor(training_host_fraction*length(hosts))
stopifnot(n_train_hosts>0,n_train_hosts<length(hosts))
train_hosts <- hosts[sample.int(length(hosts),n_train_hosts)]
host_split <- data.frame(host_id=hosts,partition=ifelse(hosts %in% train_hosts,"train","test"))
primary$partition <- host_split$partition[match(primary$host_id,host_split$host_id)]
sensitivity <- primary[primary$sensitivity_eligible,]
stopifnot(!anyDuplicated(primary$id),!anyNA(primary$partition),
          length(intersect(unique(primary$host_id[primary$partition=="train"]),
                           unique(primary$host_id[primary$partition=="test"])))==0,
          all(is.finite(primary$log_minimum_nights)),all(sensitivity$id %in% primary$id))
for (sample_data in list(primary,sensitivity)) {
  stopifnot(all(table(sample_data$borough,sample_data$room_type,sample_data$partition)>0))
}
write.csv(primary,"data/processed/model_primary.csv",row.names=FALSE,na="")
write.csv(sensitivity,"data/processed/model_without_hotel_labels.csv",row.names=FALSE,na="")
write.csv(host_split,"data/processed/host_split.csv",row.names=FALSE,na="")
write.csv(d[,c("id","host_id","borough","room_type","primary_eligible","exclusion_reason")],
          "data/processed/model_eligibility.csv",row.names=FALSE,na="")
flow <- data.frame(stage=c("Scoped listings","Positive-price EDA sample",
  "Positive price and valid complete core covariates","Primary sample with known host ID",
  "Sensitivity sample without hotel/hostel/resort text or unknown property type"),
  n=c(nrow(d),sum(d$valid_price),sum(d$valid_price & d$valid_core_covariates),nrow(primary),nrow(sensitivity)))
save_prep(flow,"model_sample_flow.csv")
exclusions <- group_summary(d,c("borough","room_type","exclusion_reason"),function(g)data.frame(n=nrow(g)))
save_prep(exclusions,"exclusions_by_group.csv")
counts <- do.call(rbind,lapply(c("primary","without_hotel_labels"),function(s) {
  z<-if(s=="primary")primary else sensitivity
  cbind(sample=s,group_summary(z,c("partition","borough","room_type"),function(g)
    data.frame(listings_n=nrow(g),hosts_n=length(unique(g$host_id)))))
}))
rownames(counts)<-NULL
save_prep(counts,"split_counts_by_group.csv")
totals <- do.call(rbind,lapply(c("primary","without_hotel_labels"),function(s) {
  z<-if(s=="primary")primary else sensitivity
  cbind(sample=s,group_summary(z,"partition",function(g)data.frame(listings_n=nrow(g),hosts_n=length(unique(g$host_id)))))
}))
rownames(totals)<-NULL
save_prep(totals,"split_totals.csv")
save_prep(data.frame(model=names(candidate_formulas),formula=unname(candidate_formulas)),"candidate_formulas.csv")
rules <- c("# Modeling sample protocol", "",paste0("Protocol version: ",model_protocol_version,". Recorded before any regression fitting."),"",
  "## Eligibility and scope", "",
  "Primary analysis retains both room types in both boroughs, including hotel-like property labels. Require finite positive price, integer accommodates >= 1, integer bedrooms >= 0, integer minimum_nights >= 1 and a known host ID. No arbitrary price trimming or imputation. Rating is not required or included in the core model.","",
  "The sensitivity sample uses the same requirements and excludes property_type strings matching hotel|hostel|resort (case-insensitive), plus unknown property types. This is a non-hotel-label subset, not a verified residential population. It retains Private room. These exclusions are fixed before model results are examined.","",
  paste0("- ",flow$stage,": ",fmt(flow$n),"."),"",
  "## Fixed split", "",
  paste0("Sort unique host IDs, use R seed ",split_seed," with Mersenne-Twister/Inversion/Rejection, and select floor(",training_host_fraction,
    " * number of hosts) for training without replacement. The remaining hosts form the test set. This targets roughly 80% of hosts, not exactly 80% of listings. Each host stays in one partition; the sensitivity subset inherits that assignment."),"",
  vapply(seq_len(nrow(totals)),function(i){z<-totals[i,];paste0("- ",z$sample," / ",z$partition,": ",fmt(z$listings_n)," listings from ",fmt(z$hosts_n)," hosts.")},character(1)),"",
  "The split has zero host overlap and both room types in each borough in both partitions. Do not redraw it in response to model performance. Row-level assignments are in the reproducible local data/processed/host_split.csv.","",
  "Earlier EDA viewed the entire snapshot, including future test records. This is a prospective holdout for subsequent model fitting and selection, not an untouched preregistered external test dataset. No test errors have been calculated. Do not use test outcomes for subsequent transformation selection, thresholds, model selection, or tuning.","",
  "## Candidate regressions", "",
  paste0("- ",names(candidate_formulas),": `",unname(candidate_formulas),"`."),"",
  "Reference levels are Brooklyn and Private room. log_minimum_nights is the natural log of the minimum stay; long_stay indicates minimum_nights >= 30. Together they allow a threshold shift plus variation with stay length. This is a starting specification, not a proven adequate model. Check rank, collinearity and residual form using training data. Document justified revisions before touching test errors; do not select by desired significance.","",
  "Fit all candidate models to the same primary training rows. For the property-label sensitivity, refit the final selected specification on the sensitivity training rows and compare the same borough/room-type contrasts. Do not separately search for a favorable sensitivity specification. Compare estimates and intervals, not only significance labels; the subset changes the target population.","",
  "## Subsequent analysis", "",
  "No models are fitted in this preparation step. Future work: training-data diagnostics, influential observations, appropriate handling of host dependence/heteroskedasticity, interaction contrasts with confidence intervals, and MSPR on held-out hosts compared with training residual MSE on the log-price scale. Compute MSE with the residual degrees of freedom and report the validation sample sizes. Do not refit on test records before the required comparison.")
writeLines(rules,"reports/model_preparation/model_protocol.md")
writeLines(sub("[[:space:]]+$","",capture.output(sessionInfo())),"reports/model_preparation/session_info.txt")
message("Prepared primary and sensitivity samples and a deterministic host split; no models fitted.")

# ===== END scripts/05_prepare_model_samples.R =====
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

# ===== END scripts/09_fit_training_models.R =====
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

# ===== END scripts/10_training_diagnostics.R =====

# ===== BEGIN config/model_refinement.R =====
# Added after inspecting M2 TRAINING diagnostics, before evaluating M3 or any test errors.
# M2 mean residuals vary nonlinearly with capacity; a log-capacity candidate has
# the same parameter count. Stay centering is an equivalent reparameterization,
# not an improvement in fitted values or a cure for weak within-regime support.
refinement_formula <- "log_price ~ borough * room_type + log_accommodates + bedrooms + within_stay_log_min + long_stay"
training_cv_seed <- 20261119L
training_cv_folds <- 5L

# ===== END config/model_refinement.R =====
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

# ===== END scripts/11_refine_training_model.R =====
fmt <- function(x,d=3) formatC(x,format="f",digits=d,big.mark=",")
fp <- function(x) format.pval(x,digits=3,eps=.001)
int_term <- "boroughManhattan:room_typeEntire home/apt"
m2_int <- all_coefs[all_coefs$analysis=="M2" & all_coefs$term==int_term,]
m3_int <- coefs3[coefs3$term==int_term,]
cv2 <- cv_summary$pooled_listing_MSE[cv_summary$model=="M2"]
cv3 <- cv_summary$pooled_listing_MSE[cv_summary$model=="M3"]
primary3 <- contrast3[contrast3$analysis=="Primary M3",]
secondary3 <- contrast3[contrast3$analysis!="Primary M3",]
result_lines <- function(z) vapply(seq_len(nrow(z)),function(i) sprintf(
  "- %s: %s%% (pointwise 95%% interval %s%% to %s%%); Holm-adjusted p %s.",
  z$contrast[i],fmt(z$pct_difference[i],1),fmt(z$pct_ci_lower[i],1),fmt(z$pct_ci_upper[i],1),fp(z$p_Holm_four_contrasts[i])),character(1))
metrics_lines <- vapply(seq_len(nrow(cv_summary)),function(i){
  nm<-cv_summary$model[i];m<-rbind(metrics,metrics3);m<-m[m$model==nm,]
  sprintf("- %s: adjusted R-squared %s; training residual MSE %s; host-fold CV MSE %s (listing weighted), %s (equal host weighted).",
    nm,fmt(m$adjusted_R_squared),fmt(m$training_residual_MSE),fmt(cv_summary$pooled_listing_MSE[i]),fmt(cv_summary$equal_host_MSE[i]))
},character(1))
question_lines <- vapply(seq_len(nrow(test3)),function(i) sprintf(
  "- %s / %s: approximate F(%s, %s) = %s; p %s; Holm-adjusted p %s.",
  test3$analysis[i],test3$hypothesis[i],fmt(test3$df1[i],0),fmt(test3$df2[i],0),
  fmt(test3$approx_cluster_F[i]),fp(test3$p[i]),fp(test3$p_Holm_three_questions[i])),character(1))
report <- c(
  "# Training regression analysis — working results", "",
  "Generated by scripts/12_training_report.R from the pinned Inside Airbnb NYC 2026-09-14 snapshot. This is a modeling-stage report, not the final course submission.", "",
  "## Status and sample", "",
  sprintf("The primary training analysis uses %s listings from %s hosts. Both Private room and Entire home/apt remain included in Manhattan and Brooklyn. The property-label sensitivity uses %s training listings from %s hosts.",
    fmt(nrow(train3),0),fmt(length(unique(train3$host_id)),0),fmt(nrow(train_sensitivity),0),fmt(length(unique(train_sensitivity$host_id)),0)), "",
  "The saved host-level test partition has not been scored. Training and testing hosts are disjoint; the sensitivity subset inherits the same split. Earlier EDA examined the full snapshot, so this is a prospective holdout for subsequent modeling, not pristine external validation. Missing-price listings remain excluded without imputation; observed-price associations need not describe the entire NYC market.", "",
  "## Model sequence and diagnostic-driven revision", "",
  "The response is natural-log listing price. Brooklyn and Private room are reference levels. Ratings are omitted from the core model to avoid selecting only reviewed listings. M0 contains borough and room type; M1 adds capacity, bedrooms, log minimum nights and a 30-or-more-night indicator; M2 adds borough-by-room-type interaction.", "",
  "M2 diagnostic plots motivated one documented refinement, M3: use log guest capacity rather than linear capacity. Also center log minimum nights within the two minimum-stay regimes, using training means only. Centering is an algebraically equivalent reparameterization of the stay terms; it does not improve predictions by itself, create additional information, or solve weak support within a regime. The same number of coefficients is retained. The capacity transformation is the substantive model-form change.", "",
  "```r", refinement_formula, "```", "",
  "Here within_stay_log_min = log(minimum_nights) minus its training mean in the same long_stay group; long_stay = 1 when minimum_nights >= 30. The indicator coefficient is therefore a contrast at the two group-specific centering values, not a discontinuity at 30 nights. Saved centering values must be reused for future prediction.", "",
  sprintf("Model comparison uses %s-fold validation within the training hosts, with seed %s. Every listing from a host shares a fold, and the stay centers are relearned inside each fold. Scores are mean squared errors in log-price units; smaller is better. These are exploratory comparisons because the M3 idea came from the same training data, not an independent assessment of the entire selection process.",training_cv_folds,training_cv_seed), "",
  metrics_lines, "",
  sprintf("M3 reduces pooled validation MSE by %s%% relative to M2. It has the lowest observed CV error among these candidates and is the current working specification. This small improvement is descriptive, not a statistical test of predictive superiority. We retain the interaction to address the prespecified third question and conditional comparisons, not because its primary-sample p-value is small.",fmt(100*(cv2-cv3)/cv2,1)), "",
  "See [candidate metrics](refined_candidate_metrics.csv), [fold-level errors](training_host_CV_by_fold.csv), and [M3 R summary](M3_R_summary.txt). Classical AIC, BIC and nested F output are supplied as familiar supporting output; they rely on working independent-error likelihood assumptions and are not the main evidence when hosts repeat.", "",
  "## Dependence and inference", "",
  sprintf("There are %s training hosts with multiple listings, covering %s records; the largest host contributes %s records. Ordinary independent-error uncertainty estimates can differ substantially from host-cluster estimates. In M2, the interaction has ordinary p %s versus host-cluster p %s. Under M3, its host-cluster p is %s; this does not demonstrate that the interaction is exactly zero.",
    fmt(host_summary$hosts_with_multiple_listings,0),fmt(host_summary$listings_from_repeat_hosts,0),fmt(host_summary$max_listings_one_host,0),
    fp(m2_int$ordinary_p),fp(m2_int$cluster_p),fp(m3_int$cluster_p)), "",
  "Inference uses sandwich::vcovCL with host clusters, type='HC1', cadjust=TRUE. Individual/contrast intervals use a t reference with G-1 degrees of freedom; joint Wald statistics use an approximate F(q, G-1) reference. These are large-sample approximations, not exact small-sample tests. They allow within-host error dependence and heterogeneous variances under regularity conditions, while assuming independent hosts. They do not repair an incorrect conditional mean, neighborhood-level dependence across hosts, selection from missing prices, or omitted variables. See the [official vcovCL documentation](https://sandwich.r-forge.r-project.org/reference/vcovCL.html).", "",
  "The four planned conditional contrasts form one Holm-adjusted p-value family within each sample; the three research-question tests form a separate family. Intervals are pointwise 95%, not simultaneous. Neither these intervals nor p-values account for diagnostic-driven model refinement or comparisons across specifications/samples, so they are exploratory inference.", "",
  "## Conditional comparisons under M3", "",
  "Percentages are 100 × (exp(log contrast) - 1), comparing fitted conditional geometric-mean prices at the same modeled covariates. They are not arithmetic-mean dollar differences or causal effects. The common slope form assumes these contrasts are constant across capacity, bedrooms and stay conditions; sparse covariate combinations can require extrapolation.", "",
  result_lines(primary3), "",
  "![M3 adjusted associations](../../figures/modeling/06_M3_adjusted_contrasts.png)", "",
  "## Research questions and sensitivity", "",
  question_lines, "",
  "The primary working model provides evidence of adjusted borough and room-type associations, but not clear evidence that the room-type association varies by borough. The joint borough test sets both the borough main effect and interaction to zero; the joint room-type test sets both the room main effect and interaction to zero. Thus these tests do not mistake a reference-group coefficient for an overall association.", "",
  "The prespecified sensitivity excludes property_type text matching hotel|hostel|resort and unknown property-type labels. It still contains Private room listings and is not a verified legal or residential classification. It changes the target population, so a different result is not evidence that one sample is correct or that the two effects differ statistically.", "",
  result_lines(secondary3), "",
  "The interaction evidence and private-room borough contrast are sensitive to this population definition. Report both analyses; do not select the sample because it produces the desired significance. A formal difference-between-samples test has not been conducted.", "",
  "## Diagnostic findings and influence", "",
  "![M3 diagnostics](../../figures/modeling/04_M3_diagnostics.png)", "",
  "![Capacity refinement](../../figures/modeling/05_capacity_refinement_comparison.png)", "",
  "Residual Q-Q plots show pronounced upper-tail departures; scale-location plots show unequal residual spread. Group residual means still vary with capacity, even after the log transformation. M3 improves aggregate validation error but does not fully resolve functional-form limitations. Classical Gaussian/constant-variance assumptions should not be declared satisfied. Cluster covariance addresses part of the uncertainty problem, not these remaining mean patterns.", "",
  sprintf("The maximum design-column VIF falls from %s in M2 to %s in M3. Much of the change reflects within-regime centering of stay terms, not evidence that information about their separate effects increased.",fmt(max(vifs$VIF),2),fmt(max(vifs3$VIF),2)), "",
  sprintf("M3 has %s records above the Cook screening rule 4/n and %s with absolute externally studentized residual above 3; maximum Cook distance is %s. These are review flags, not automatic exclusion rules. No record was removed from the main model on this basis.",fmt(diagnostics3$Cook_flag_n,0),fmt(diagnostics3$studentized_abs_gt3_n,0),fmt(diagnostics3$max_Cook,4)), "",
  sprintf("Dropping the single largest-Cook record changes the four log contrasts by at most %s. Dropping the largest host changes them by at most %s, equivalent to a multiplicative change in a fitted contrast ratio of up to %s%%. Host-level concentration therefore deserves more attention than a single influential listing. These deletion fits are diagnostic only; neither replaces the primary analysis. See the exact [influence checks](M3_influence_checks.csv).",fmt(diagnostics3$max_abs_case_deletion_contrast_change,4),fmt(diagnostics3$max_abs_host_deletion_contrast_change,4),fmt(100*expm1(diagnostics3$max_abs_host_deletion_contrast_change),1)), "",
  "## Remaining work before final submission", "",
  "1. Review whether the working functional form and remaining group patterns are acceptable for the course's inferential aim; document any further justified revision using training data only, then freeze the specification and prediction rule.",
  "2. Evaluate that frozen model once on the reserved hosts. Report test MSPR = mean((observed log price - predicted log price)^2) alongside training residual MSE = RSS/(n-p). Do not tune the model in response to the test score. Dollar-scale prediction requires a separately justified retransformation rule; exponentiation alone does not predict arithmetic-mean price.",
  "3. Integrate focused EDA, model summary, tests, diagnostics, influence and limitations into the approximately ten-page final report, with code submitted separately. The earlier five-page Project Description remains the initial proposal-stage artifact.",
  "4. Supply the real team names/UNIs and review instructor announcements and any additional classroom requirements.", "",
  "## Reproduce", "", "```sh", "Rscript --vanilla scripts/setup_model_dependencies.R", "Rscript --vanilla scripts/12_training_report.R", "Rscript --vanilla scripts/13_verify_training.R", "```", "",
  "R performs every calculation and creates all six modeling figures. Raw/processed row-level data, fitted-object caches and local package libraries are excluded from Git. CSV results and figures are regenerated; do not edit them by hand.")
writeLines(report,"reports/modeling/training_report.md")
message("Generated reports/modeling/training_report.md; reserved test set remains unscored.")

# ===== END scripts/12_training_report.R =====

# ===== BEGIN config/completion_review.R =====
# Recorded before fitting M4 or viewing any reserved test errors, 2026-11-19.
# M3 residual-capacity patterns differ between room types. Test one additional
# slope interaction, with capacity centered at two guests for interpretable contrasts.
completion_candidate_formula <- "log_price ~ borough * room_type + room_type * log_capacity_2 + bedrooms + within_stay_log_min + long_stay"
capacity_reference <- 2
# Use the SAME saved training-host folds. Adopt M4 only if both listing-weighted
# and equal-host CV MSE improve by at least 1%, with full rank in all fits.
# This is a pragmatic complexity threshold, not a significance test or unbiased CV.
minimum_relative_CV_improvement <- .01
# Main conditional room-type comparisons will be at capacity=2. Comparisons at
# capacity=4 are secondary, explicitly labeled, with support counts disclosed.
# No further functional-form search is planned before the reserved evaluation.

# ===== END config/completion_review.R =====
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

# ===== END scripts/14_complete_training_review.R =====
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

# ===== END scripts/15_freeze_final_model.R =====

# ===== BEGIN scripts/16_evaluate_reserved_hosts.R =====
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

# ===== END scripts/16_evaluate_reserved_hosts.R =====
# ggplot's unspecified ordering of multiple guides can vary between sessions.
# Make the final rendering deterministic without changing locked training code.
ordered_guides<-guides(color=guide_legend(order=1),size=guide_legend(order=2))
p_cap<-p_cap+ordered_guides;p_cap3<-p_cap3+ordered_guides;cp<-cp+ordered_guides
save_model_plot(p_cap,"figures/modeling/02_M2_residual_capacity.png",10,7)
save_model_plot(p_cap3,"figures/modeling/05_capacity_refinement_comparison.png",11,9)
save_model_plot(cp,"figures/final/03_final_capacity_residuals.png",10,6)
z<-readRDS("models/final_training_review.rds");ev<-readRDS("models/frozen_evaluation.rds")
stopifnot(z$name=="M3") # This report describes the recorded decision; never silently change its model.
f<-z$fit;tr<-z$training
readtab<-function(path)read.csv(path,stringsAsFactors=FALSE,check.names=FALSE)
covg<-readtab("reports/eda/price_coverage_by_group.csv")
desc<-readtab("reports/eda/descriptive_by_group.csv");prices<-subset(desc,variable=="price")
overall<-readtab("reports/eda/descriptive_overall.csv");op<-subset(overall,variable=="price")
hotel<-readtab("reports/eda/hotel_like_labels_by_group.csv")
mh_hotel<-subset(hotel,borough=="Manhattan" & room_type=="Private room")
stayprices<-readtab("reports/eda/price_by_group_and_minimum_stay.csv")
mh_stay<-subset(stayprices,borough=="Manhattan" & stay_group=="30+ nights")
flow<-readtab("reports/model_preparation/model_sample_flow.csv")
manifest<-readtab("reports/audit/source_manifest.csv")
co<-readtab("reports/final_analysis/final_coefficients.csv")
decision<-readtab("reports/final_analysis/training_selection_decision.csv")
inf<-readtab("reports/final_analysis/largest_ten_hosts_deletion.csv")
hs<-readtab("reports/modeling/training_host_structure.csv")
tm<-ev$metrics;gc<-ev$groups;ct<-z$contrasts;wt<-z$tests;dg<-z$diagnostics
num<-function(x,d=0)formatC(x,digits=d,format="f",big.mark=",")
money<-function(x)paste0("$",num(x,2))
pval<-function(x)format.pval(x,digits=3,eps=.001)
percent<-function(x)paste0(num(x,1),"%")
group_label<-function(b,r)paste(b,ifelse(r=="Entire home/apt","entire home","private room"),sep="\n")
labels<-c("Borough gap in private rooms","Borough gap in entire homes","Room gap in Brooklyn","Room gap in Manhattan")
pc<-subset(ct,analysis=="Primary");sc<-subset(ct,analysis!="Primary")
wp<-subset(wt,analysis=="Primary");ws<-subset(wt,analysis!="Primary")
short_contrast<-setNames(labels,pc$contrast)
pr<-pp+scale_y_discrete(labels=short_contrast)+labs(title="Figure 5  Adjusted price comparisons",subtitle="Pointwise 95% host-cluster intervals at capacity two",caption=NULL)+report_theme
save_model_plot(pr,"figures/final/08_report_contrasts.png",7,4)
# Compact diagnostic panels regenerated from the final fit, not edited images.
diagdata<-data.frame(fitted=fitted(f),residual=resid(f),standardized=rstandard(f),Cook=cooks.distance(f),index=seq_len(nrow(tr)))
diagdata$bin<-pmin(20,ceiling(rank(diagdata$fitted,ties.method="first")/nrow(tr)*20))
binned<-aggregate(cbind(fitted,residual)~bin,diagdata,mean)
diagdata$root<-sqrt(abs(diagdata$standardized));scaled<-aggregate(cbind(fitted,root)~bin,diagdata,mean)
dt<-theme_minimal(base_size=9)+theme(panel.grid.minor=element_blank(),plot.title=element_text(size=10,face="bold"),plot.margin=margin(6,6,6,6))
p1<-ggplot(diagdata,aes(fitted,residual))+geom_point(size=.4,alpha=.13,color="#287B85")+geom_hline(yintercept=0,lty=2)+geom_line(data=binned,color="#B56830")+labs(title="Residuals versus fitted",x="Fitted log price",y="Residual")+dt
qq<-data.frame(x=qnorm(ppoints(nrow(tr))),y=sort(diagdata$standardized));quart<-quantile(diagdata$standardized,c(.25,.75))
slope<-diff(quart)/diff(qnorm(c(.25,.75)));intercept<-quart[1]-slope*qnorm(.25)
p2<-ggplot(qq,aes(x,y))+geom_point(size=.5,alpha=.4,color="#287B85")+geom_abline(slope=slope,intercept=intercept,color="#B56830")+labs(title="Normal Q-Q plot",x="Normal quantile",y="Standardized residual")+dt
p3<-ggplot(diagdata,aes(fitted,root))+geom_point(size=.4,alpha=.13,color="#287B85")+geom_line(data=scaled,color="#B56830")+labs(title="Scale-location",x="Fitted log price",y="Sqrt absolute standardized residual")+dt
p4<-ggplot(diagdata,aes(index,Cook))+geom_segment(aes(xend=index,yend=0),linewidth=.2,color="#287B85")+geom_hline(yintercept=4/nrow(tr),lty=2,color="#B56830")+scale_x_continuous(breaks=c(0,3000,6000,9000))+labs(title="Cook's distance",x="Training index",y="Cook's distance")+dt
save_grid(list(p1,p2,p3,p4),"figures/final/09_report_diagnostics.png",7,5.4)
save_model_plot(cp+labs(title="Figure 7  Remaining mean residual patterns",caption=NULL)+report_theme,
  "figures/final/10_report_remaining_patterns.png",7,3.2)

team<-read.csv("config/team.csv",colClasses="character")
if(nrow(team))stopifnot(nrow(team)>=3,nrow(team)<=5,all(nzchar(trimws(team$name))),all(nzchar(trimws(team$uni))),!anyNA(team),!anyDuplicated(team$uni))
team_text<-if(nrow(team))paste(paste0(team$name," (",team$uni,")"),collapse="; ")else "Team members and UNIs: __________________________________________________"
P<-function(s)list(type="paragraph",text=s)
S<-function(s)list(type="small",text=s)
H<-function(s)list(type="heading",text=s)
F<-function(s,w=6.8)list(type="figure",file=paste0("figures/final/",s),width=w)
T<-function(headers,rows,widths)list(type="table",headers=headers,rows=rows,widths=widths)
V<-function(s)list(type="verbatim",text=s)
old_width<-getOption("width");options(width=115)
rsummary<-trim_model_output(capture.output(summary(f)));options(width=old_width)
writeLines(rsummary,"reports/final_analysis/report_R_summary.txt")
price_rows<-lapply(seq_len(nrow(prices)),function(i){a<-prices[i,];c(group_label(a$borough,a$room_type),num(a$observed_n),money(a$median),money(a$mean),money(a$sd))})
comparison_rows<-lapply(seq_len(nrow(pc)),function(i)c(labels[i],percent(pc$pct_difference[i]),paste0(percent(pc$pct_ci_lower[i])," to ",percent(pc$pct_ci_upper[i])),pval(pc$p_Holm_four[i])))
question_rows<-lapply(seq_len(nrow(wp)),function(i)c(c("Borough main effect and interaction = 0","Room main effect and interaction = 0","Borough by room interaction = 0")[i],num(wp$F[i],3),paste0(wp$df1[i],", ",num(wp$df2[i])),pval(wp$p_Holm_three[i])))
selection_rows<-lapply(seq_len(nrow(z$metrics)),function(i){a<-z$metrics[i,];v<-z$cv[z$cv$model==a$model,];c(a$model,num(a$parameters),num(a$adjusted_R_squared,3),num(a$training_residual_MSE,4),num(v$pooled_listing_MSE,4),num(v$equal_host_MSE,4))})
bygroup_rows<-lapply(seq_len(nrow(gc)),function(i){a<-gc[i,];c(group_label(a$borough,a$room_type),num(a$n),num(a$MSPR,4),num(a$mean_residual,4))})
influence_rows<-lapply(seq_len(nrow(pc)),function(i){a<-inf[inf$contrast==pc$contrast[i],];c(labels[i],num(pc$log_difference[i],4),paste0(num(min(a$without_host_log),4)," to ",num(max(a$without_host_log),4)))})
support_rows<-lapply(seq_len(nrow(prices)),function(i){a<-prices[i,];b<-subset(z$reference_support,borough==a$borough & room_type==a$room_type & accommodates==2);c(group_label(a$borough,a$room_type),num(b$n[b$long_stay==0]),num(b$n[b$long_stay==1]))})
pages<-list(
 list(title="Airbnb Listing Prices in Manhattan and Brooklyn",blocks=list(
  S("Final regression report | STAT GU4205/GR5205 | Fall 2026"),S(team_text),
  H("Research objectives and main findings"),
  P("We examine whether advertised Airbnb prices differ by borough and room type after adjustment for guest capacity, bedrooms and minimum-stay requirements. We ask whether borough differences persist within each room type, whether room-type differences persist within each borough, and whether the room-type association varies by borough. These are observational associations, not effects of changing a listing's location or room type."),
  P(sprintf("The final working model finds positive adjusted borough and room-type differences, but weak evidence for the borough-by-room interaction in the primary sample (host-cluster p %s). The interaction evidence changes in the property-label sensitivity sample. Reserved-host log-price MSPR is %s, compared with training residual MSE %s. Remaining residual patterns and missing-price selection limit interpretation.",pval(wp$p[3]),num(tm$test_MSPR,4),num(tm$training_MSE,4))),
  H("Data collection and scope"),
  P(sprintf("We downloaded Inside Airbnb's NYC detailed-listings snapshot labeled %s on 2026-11-18 [1]. Its %s unique listings and %s fields were scraped from %s to %s. Each row is a listing. The provider defines price as a daily amount in local currency [2]; NYC amounts are interpreted as USD, not realized transactions or total trip costs.",manifest$snapshot_label,num(manifest$raw_rows),num(manifest$raw_columns),manifest$observed_scrape_min,manifest$observed_scrape_max)),
  P(sprintf("The scope is Manhattan and Brooklyn, retaining Entire home/apt and Private room. Of %s scoped records, %s (%s) lack a price. The EDA includes all %s finite positive-price records. Requiring complete valid core covariates and a known host leaves %s model records. No arbitrary price cap, tail deletion or imputation is applied.",num(sum(covg$scoped_n)),num(sum(covg$missing_price_n)),percent(100*sum(covg$missing_price_n)/sum(covg$scoped_n)),num(op$sample_n),num(flow$n[4]))),
  H("Observed daily price summaries"),T(c("Borough and room type","n","Median","Mean","SD"),price_rows,c(2,.65,1.1,1.1,1.1)),
  S("Source: fixed Inside Airbnb snapshot; positive-price EDA sample. These are unadjusted summaries. Sample composition and model eligibility are distinct from the EDA inclusion rule.")
 )),
 list(title="Exploratory price distributions",blocks=list(
  F("04_report_raw_prices.png"),
  P(sprintf("Figure 1 retains the full range, from %s to %s. The mean (%s) exceeds the median (%s), with a pronounced upper tail. The earlier exploratory report also provides a display zoom; extreme prices remain in the analysis.",money(op$min),money(op$max),money(op$mean),money(op$median))),
  F("05_report_log_prices.png"),
  P("Figure 2 uses the same records after taking natural logs. This compresses the upper tail and motivates examining proportional price differences. A more concentrated outcome histogram does not establish residual normality, linearity, constant variance or independence; those are assessed after fitting."),
  S("Figures 1 and 2: Inside Airbnb NYC 2026-09-14. All positive prices retained. Bin widths are stated in the panels; the change of horizontal scale changes the visual distribution, not the underlying observations.")
 )),
 list(title="Room type and listing composition",blocks=list(
  F("06_report_group_prices.png"),
  P(sprintf("Figure 3 shows overlapping unadjusted distributions. Manhattan medians are %s for private rooms and %s for entire homes; among listings requiring 30+ nights, they are %s and %s. Minimum-stay composition therefore matters for interpretation.",money(prices$median[prices$borough=="Manhattan" & prices$room_type=="Private room"]),money(prices$median[prices$borough=="Manhattan" & prices$room_type=="Entire home/apt"]),money(mh_stay$median_price_usd[mh_stay$room_type=="Private room"]),money(mh_stay$median_price_usd[mh_stay$room_type=="Entire home/apt"]))),
  F("07_report_capacity.png"),
  S("Figure 3 boxes show medians and IQRs; whiskers extend up to 1.5 IQR. Figure 4 displays four variables: capacity, log price, room type and borough. All eligible records are plotted; fixed horizontal jitter changes only display positions. Diamonds are medians for cells with at least 20 records. Source: Inside Airbnb NYC 2026-09-14."),
  P(sprintf("Capacity distributions differ, and high-capacity private rooms are sparse. In Manhattan, %s of %s private-room listings (%s) have hotel/hostel/resort text in property_type. This motivates a prespecified sensitivity analysis; Private room itself remains included.",num(mh_hotel$hotel_like_label_n),num(mh_hotel$n),percent(mh_hotel$hotel_like_label_pct)))
 )),
 list(title="Final statistical model",blocks=list(
  P(sprintf("We fit M3 by ordinary least squares to %s saved training records from %s hosts. The response is natural-log daily price; borough and room_type are factors with Brooklyn and Private room as reference levels. Guest capacity enters on a log scale; bedrooms enters linearly, allowing zero bedrooms. Ratings are omitted from the core model to avoid requiring reviewed listings.",num(tm$training_n),num(tm$training_hosts))),
  V("log_price ~ borough * room_type + log_accommodates + bedrooms +\n  within_stay_log_min + long_stay"),
  P(sprintf("long_stay indicates minimum_nights >= 30. within_stay_log_min is log(minimum_nights) minus its training mean in the corresponding stay regime: %s below 30 nights and %s at 30+ nights. Centering is an equivalent reparameterization of the stay terms. The long_stay coefficient compares the two group-specific centers, not a discontinuity at exactly 30 nights.",num(z$centers["0"],4),num(z$centers["1"],4))),
  H("R summary output"),V(paste(rsummary,collapse="\n")),
  P("This R summary reports ordinary independent-error standard errors and tests. The main inference on the next page instead uses host-cluster HC1 covariance [3], since a host can contribute multiple listings. The coefficient estimates are unchanged; their uncertainty estimates differ."),
  S("The borough-by-room interaction permits different room contrasts across boroughs. exp(a log contrast) is a fitted conditional geometric-mean ratio; it is not an arithmetic-mean dollar ratio unless additional distributional assumptions are made.")
 )),
 list(title="Research questions and adjusted comparisons",blocks=list(
  P(sprintf("Inference uses %s training hosts and sandwich::vcovCL(type='HC1', cadjust=TRUE). Contrast intervals use t with G-1 degrees of freedom; joint Wald tests use approximate F(q, G-1). These allow within-host dependence and heterogeneous variances, assuming independent hosts and appropriate regularity conditions [3]. They do not repair mean misspecification or dependence between different hosts.",num(tm$training_hosts))),
  H("Conditional comparisons in the primary sample"),
  T(c("Comparison","Difference","Pointwise 95% CI","Holm p"),comparison_rows,c(2.4,.9,2,.75)),
  S("Borough gaps compare Manhattan with Brooklyn. Room gaps compare Entire home/apt with Private room. Differences are percentages of fitted conditional geometric means at common covariates. Four contrast p-values form one Holm family. Intervals are pointwise, not simultaneous."),
  H("Joint research question tests"),T(c("Null hypothesis","F statistic","df1, df2","Holm p"),question_rows,c(3,1,.95,1.1)),
  P(sprintf("The joint borough and room-type hypotheses are rejected in this working model. The borough-by-room interaction is not clearly supported (p %s). This does not prove an exactly zero interaction. With an interaction present, the borough main coefficient describes private rooms, and the room main coefficient describes Brooklyn; comparisons in the other group require adding the interaction coefficient.",pval(wp$p[3]))),
  P("The three joint tests form a separate Holm family. Neither family adjustment nor the pointwise intervals accounts for training-data-driven functional-form selection or inspection across specifications. Interpret these inferential results as exploratory. Tests from the ordinary R summary are provided for transparency, not substituted for host-cluster inference."),
  P(sprintf("The four estimated differences range from %s to %s. Positive fitted associations persist after the included controls, but omitted neighborhood, amenities and property quality can still explain part of those differences. The model is a parsimonious association summary, not an experiment.",percent(min(pc$pct_difference)),percent(max(pc$pct_difference))))
 )),
 list(title="Sensitivity to property labels",blocks=list(
  P(sprintf("The sensitivity sample excludes property_type text matching hotel|hostel|resort, case-insensitively, and unknown property labels. It uses the same final formula and inherited host split, with %s training listings from %s hosts. Both room types remain included. This is a label-based subset, not a verified residential or legal classification.",num(nrow(z$sensitivity_training)),num(length(unique(z$sensitivity_training$host_id))))),
  F("08_report_contrasts.png"),
  P(sprintf("Figure 5 shows a substantial change in the private-room borough contrast: %s in the primary sample versus %s in the subset. The Manhattan room contrast changes from %s to %s. The borough-by-room interaction has cluster p %s in the subset, compared with %s in the primary sample.",percent(pc$pct_difference[1]),percent(sc$pct_difference[1]),percent(pc$pct_difference[4]),percent(sc$pct_difference[4]),pval(ws$p[3]),pval(wp$p[3]))),
  P("These analyses answer questions about different populations. A significant result in one sample and a nonsignificant result in another does not establish a statistically significant difference between the estimates; no such difference test was performed. We report both and do not choose the sample to obtain significance."),
  S("Figure 5 uses training estimates and pointwise 95% intervals; model-selection uncertainty is not included. Source: Inside Airbnb NYC 2026-09-14. Under M3 the four contrasts are constant over the modeled capacity range; showing capacity two anchors interpretation without proving validity outside supported profiles.")
 )),
 list(title="Appendix A Model selection and support",blocks=list(
  T(c("Model","p","Adj R2","Train MSE","CV listing","CV host"),selection_rows,c(.55,.4,.8,1,1.25,1.25)),
  S("All models use identical primary training records. CV listing pools listing errors; CV host gives each validation host equal weight. All errors are on the natural-log-price scale. p includes the intercept."),
  P("M0 contains borough and room type. M1 adds capacity, bedrooms, log minimum nights and long_stay. M2 adds the planned borough-by-room interaction. M3 logs capacity and centers log minimum nights within stay regimes. M4 additionally allows the log-capacity slope to differ by room type, motivated by M3 residual patterns."),
  P(sprintf("Five folds separate training hosts, using the original saved folds. Preprocessing is learned inside each fold. M4 improves listing-weighted CV MSE by %s%% and equal-host CV MSE by %s%% versus M3. The rule recorded before fitting M4 required at least 1%% improvement in both, so M3 is retained for parsimony. This threshold is a practical choice, not a test of predictive superiority.",num(100*decision$listing_CV_improvement,3),num(100*decision$equal_host_CV_improvement,3))),
  P("The interaction is retained to answer the planned research question, rather than selected by a favorable p-value. Because model refinements arose from training diagnostics, these CV scores do not provide an unbiased assessment of the entire selection process. The final coefficients, preprocessing and prediction rule were recorded before reserved-host errors were calculated."),
  H("Training support at capacity two and one bedroom"),
  T(c("Borough and room type","Minimum stay below 30","Minimum stay 30 or more"),support_rows,c(2.65,1.7,1.7)),
  P(sprintf("Across all capacities and bedrooms, %s joint capacity-bedroom-stay cells contain at least 20 records in every group, covering %s%% of training listings. This check supports common profiles but not every combination. Exact minimum-night overlap and unobserved characteristics are not guaranteed.",num(z$support$joint_cells_all_four_groups_at_least20),num(z$support$pct_in_those_cells,1)))
 )),
 list(title="Appendix B Model diagnostics",blocks=list(
  F("09_report_diagnostics.png"),
  S("Figure 6. Final M3 training diagnostics, Inside Airbnb NYC 2026-09-14. Orange residual and scale-location lines show means in 20 fitted-value bins; the Q-Q line uses the first and third quartiles. The Cook threshold is 4/n, a screening rule rather than an automatic deletion criterion."),
  P("The Q-Q plot has a pronounced upper tail and the scale-location plot shows unequal spread. Mean residual patterns remain at some fitted values and capacities. Logging the response and capacity improves interpretability and some fit features, but does not make all classical assumptions hold. Host-cluster covariance addresses uncertainty from some dependence and heteroskedasticity, not systematic mean errors."),
  P(sprintf("The largest design-column VIF is %s, compared with %s in the earlier M2. Much of the reduction comes from equivalent within-regime centering, not an increase in information. There are %s Cook flags, %s leverage flags above 2p/n, and %s absolute externally studentized residuals above 3. No record is automatically removed.",num(dg$max_VIF,2),num(max(readtab("reports/modeling/M2_design_column_VIF.csv")$VIF),2),num(dg$Cook_flag_n),num(dg$leverage_flag_n),num(dg$abs_studentized_gt3)))
 )),
 list(title="Appendix C Validation and influence",blocks=list(
  P(sprintf("A fixed host split reserved %s listings from %s hosts; no host overlaps training. The frozen M3 predicts these records without refitting or re-centering. Earlier EDA viewed the full snapshot, so this is a prospective holdout for later modeling, not untouched external validation. All inferential estimates in this report remain training estimates.",num(tm$test_n),num(tm$test_hosts))),
  T(c("Quantity","Definition","Value"),list(
    c("Training residual MSE","RSS / (n - p)",num(tm$training_MSE,4)),
    c("Reserved-host MSPR","Mean squared prediction error",num(tm$test_MSPR,4)),
    c("Reserved-host RMSE","Square root of MSPR",num(tm$test_RMSE,4)),
    c("Training-mean benchmark MSPR","Predict training mean log price",num(tm$training_mean_benchmark_MSPR,4))),c(2.1,3.3,1.1)),
  P(sprintf("Test MSPR is %s times training MSE and %s%% below the constant benchmark. A lower test error can reflect sample composition and sampling variation; it does not prove the absence of overfitting or validate all assumptions. Equal-host test MSPR is %s. We made no model changes in response to these scores.",num(tm$test_to_training_MSE_ratio,3),num(100*tm$relative_improvement_vs_benchmark,1),num(tm$equal_host_test_MSPR,4))),
  T(c("Test group","n","MSPR","Mean residual"),bygroup_rows,c(2.6,.65,1.2,1.5)),
  S("Residual = observed minus predicted log price. Group errors are descriptive; group host counts would not sum to unique hosts because a host can list in multiple groups."),
  H("Influence of listings and hosts"),
  P(sprintf("Deleting the largest-Cook record changes any primary log contrast by at most %s. Deleting each of the ten largest hosts separately changes one by up to %s; the largest host has %s training listings. All primary records are retained. These limited deletion checks show host concentration matters and are not exhaustive robustness validation.",num(dg$max_abs_case_contrast_delta,4),num(dg$max_abs_top10_host_contrast_delta,4),num(hs$max_listings_one_host))),
  T(c("Contrast","Primary log gap","Range after one host deletion"),influence_rows,c(2.65,1.1,2.2))
 )),
 list(title="Limitations and conclusions",blocks=list(
  F("10_report_remaining_patterns.png"),
  S("Figure 7. Point area represents cell n. Training group-capacity cells with n >= 20 are shown; smaller cells remain in the model. Residual patterns persist despite the diagnostic-driven checks. Source: Inside Airbnb NYC 2026-09-14."),
  P("The observed-price sample is selected: missingness differs across groups and observed characteristics. A single snapshot mixes stay requirements and property types and does not identify realized bookings. Omitted amenities, quality and neighborhood differences can confound associations. Repeated-host adjustment does not account for all cross-host or spatial dependence. Sparse covariate combinations, residual mean patterns and model-selection uncertainty limit nominal tests and intervals."),
  P("Within the final working model, Manhattan and entire-home listings have higher adjusted geometric-mean prices than their comparison groups. Evidence that the room-type association differs by borough is weak in the primary sample and sensitive to property-label exclusions. The reserved evaluation shows improvement over a constant prediction, while group errors and influence checks discourage treating the model as a precise market-wide pricing rule."),
  H("References and reproducibility"),
  S("[1] Inside Airbnb. New York City detailed listings, snapshot 2026-09-14. Retrieved 2026-11-18. CC BY 4.0. https://insideairbnb.com/get-the-data/"),
  S("[2] Inside Airbnb. Data Dictionary, detailed listings, version 4.3 (August 2022), linked from the source download page. https://docs.google.com/spreadsheets/d/1iWCNJcSutYqpULSQHlNyGInUvHg2BoUGoNRIGa6Szc4/edit"),
  S("[3] sandwich package. Clustered Covariance Matrix Estimation, vcovCL documentation. https://sandwich.r-forge.r-project.org/reference/vcovCL.html"),
  S("[4] Inside Airbnb. Data Assumptions. https://insideairbnb.com/data-assumptions/"),
  S("Data are a snapshot of public listings [4]. Code, fixed-source fingerprints, sample rules, frozen specification and generated outputs accompany this report. Run scripts/run_final_analysis.R for R analysis, then scripts/18_build_final_report.py for document rendering. Raw and processed row-level data are regenerated locally. Code is submitted separately rather than pasted into this appendix.")
 ))
)
dir.create("reports/final_report",recursive=TRUE,showWarnings=FALSE)
payload<-list(title="Airbnb Listing Prices in Manhattan and Brooklyn",team_complete=nrow(team)>=3,source_md5=manifest$md5,
  model_lock_md5=unname(tools::md5sum("config/final_model_lock.json")),model=z$name,pages=pages)
jsonlite::write_json(payload,"reports/final_report/report_payload.json",auto_unbox=TRUE,pretty=TRUE,digits=NA)
md<-character()
for(page in pages){
  md<-c(md,paste0("# ",page$title),"")
  for(b in page$blocks){
    if(b$type=="heading")md<-c(md,paste0("## ",b$text),"")
    else if(b$type=="figure")md<-c(md,paste0("![",basename(b$file),"](../../",b$file,")"),"")
    else if(b$type=="verbatim")md<-c(md,"```",b$text,"```","")
    else if(b$type=="table")md<-c(md,paste0("| ",paste(b$headers,collapse=" | ")," |"),paste0("| ",paste(rep("---",length(b$headers)),collapse=" | ")," |"),
      vapply(b$rows,function(x)paste0("| ",paste(gsub("\n"," ",x),collapse=" | ")," |"),character(1)),"")
    else md<-c(md,b$text,"")
  }
}
writeLines(trim_model_output(md),"reports/final_report/final_report.md")
message("Prepared ten-page final-report payload from computed outputs. Team complete: ",payload$team_complete)

# ===== END scripts/17_prepare_final_report.R =====

# ===== BEGIN scripts/13_verify_training.R =====
# Independent algebra/data-integrity checks on the completed training outputs.
# Run 12_training_report.R first. This script never evaluates reserved outcomes.
if(dir.exists(".r-library")) .libPaths(c(normalizePath(".r-library"),.libPaths()))
a<-readRDS("models/training_stage.rds")
b<-readRDS("models/M3_training_stage.rds")
checks<-data.frame(check=character(),passed=logical(),detail=character())
check<-function(name,ok,detail="") {
  checks<<-rbind(checks,data.frame(check=name,passed=isTRUE(ok),detail=as.character(detail)))
  if(!isTRUE(ok)) stop("Verification failed: ",name)
}
manual_cov<-function(f,d){
  x<-model.matrix(f);u<-resid(f);n<-nrow(x);p<-ncol(x);g<-length(unique(d$host_id))
  scores<-rowsum(x*as.numeric(u),d$host_id,reorder=FALSE)
  bread<-solve(crossprod(x))
  (n-1)/(n-p)*g/(g-1)*bread%*%crossprod(scores)%*%bread
}
fits<-list(M2=list(f=a$candidates$M2,d=a$train),M3=list(f=b$fit,d=b$training),
  M3_sensitivity=list(f=b$sensitivity_fit,d=b$sensitivity_training))
for(nm in names(fits)) {
  f<-fits[[nm]]$f;d<-fits[[nm]]$d
  check(paste(nm,"training records only"),all(d$partition=="train") && nrow(d)==nobs(f))
  vm<-manual_cov(f,d);vs<-sandwich::vcovCL(f,cluster=d$host_id,type="HC1",cadjust=TRUE)
  err<-max(abs(vm-vs));check(paste(nm,"manual clustered covariance"),err<1e-9,sprintf("max absolute error %.3g",err))
}
# Independent prediction-based contrasts instead of selecting coefficient names.
for(nm in c("M3","M3_sensitivity")) {
  f<-fits[[nm]]$f;d<-fits[[nm]]$d;new<-d[rep(1,4),]
  new$borough<-factor(c("Brooklyn","Manhattan","Brooklyn","Manhattan"),levels=levels(d$borough))
  new$room_type<-factor(c("Private room","Private room","Entire home/apt","Entire home/apt"),levels=levels(d$room_type))
  xx<-model.matrix(delete.response(terms(f)),new)
  L<-rbind(xx[2,]-xx[1,],xx[4,]-xx[3,],xx[3,]-xx[1,],xx[4,]-xx[2,])
  pr<-predict(f,newdata=new);expected<-c(pr[2]-pr[1],pr[4]-pr[3],pr[3]-pr[1],pr[4]-pr[2])
  z<-b$contrasts[b$contrasts$analysis==if(nm=="M3")"Primary M3" else "M3 without hotel labels",]
  check(paste(nm,"contrasts match prediction differences"),max(abs(expected-z$log_difference))<1e-10)
  se<-sqrt(diag(L%*%manual_cov(f,d)%*%t(L)))
  check(paste(nm,"contrast uncertainty"),max(abs(se-z$cluster_SE))<1e-9)
  check(paste(nm,"ratio and interval transformation"),
    max(abs(exp(z$log_difference)-z$geometric_mean_ratio))<1e-10 &&
    max(abs(100*expm1(z$ci_log_lower)-z$pct_ci_lower))<1e-8 &&
    max(abs(100*expm1(z$ci_log_upper)-z$pct_ci_upper))<1e-8)
  tt<-b$tests[b$tests$analysis==unique(z$analysis),]
  vi<-manual_cov(f,d);j<-match("boroughManhattan:room_typeEntire home/apt",names(coef(f)))
  p_t<-2*pt(-abs(coef(f)[j]/sqrt(vi[j,j])),length(unique(d$host_id))-1)
  check(paste(nm,"one-df Wald agrees with t test"),abs(p_t-tt$p[tt$df1==1])<1e-9)
}
check("Sensitivity training IDs subset primary",all(b$sensitivity_training$id %in% b$training$id))
split<-read.csv("data/processed/host_split.csv",colClasses="character")
check("No reserved host in modeling objects",!any(b$training$host_id %in% split$host_id[split$partition=="test"]))
fold<-read.csv("data/processed/training_host_cv_folds.csv",colClasses=c("character","integer"))
cv<-read.csv("data/processed/training_CV_errors.csv",colClasses=c("character","integer","character","character","numeric"))
check("One fold per training host",!anyDuplicated(fold$host_id) && setequal(fold$host_id,b$training$host_id))
check("CV excludes reserved hosts",all(cv$host_id %in% fold$host_id) && all(cv$fold==fold$fold[match(cv$host_id,fold$host_id)]))
for(nm in unique(cv$model)) {
  z<-cv[cv$model==nm,]
  check(paste(nm,"each training listing validated once"),!anyDuplicated(z$id) && setequal(z$id,b$training$id))
  check(paste(nm,"pooled CV error recomputation"),abs(mean(z$squared_error)-b$cv$pooled_listing_MSE[b$cv$model==nm])<1e-12)
}
check("M3 training MSE denominator",abs(deviance(b$fit)/(nobs(b$fit)-b$fit$rank)-summary(b$fit)$sigma^2)<1e-12)
pngs<-list.files("figures/modeling",pattern="[.]png$",full.names=TRUE)
check("Six nonempty generated modeling figures",length(pngs)==6 && all(file.info(pngs)$size>10000))
write.csv(checks,"reports/modeling/computation_validation.csv",row.names=FALSE)
cat(nrow(checks),"training computation/integrity checks passed. No held-out prediction was computed.\n")

# ===== END scripts/13_verify_training.R =====

# ===== BEGIN scripts/19_verify_final_analysis.R =====
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
write.csv(checks,"reports/final_analysis/final_computation_validation.csv",row.names=FALSE)
cat(nrow(checks),"final numerical and integrity checks passed.\n")

# ===== END scripts/19_verify_final_analysis.R =====

# ===== END scripts/run_final_analysis.R =====

  cat("\nCOMPLETE: all analysis and numerical verification finished.\n")
  cat("Output folder:", submission_output, "\n")
  cat("Report figures: figures/final/\n")
  cat("Final estimates and test errors: reports/final_analysis/\n")
  cat("Computed report text: reports/final_report/final_report.md\n")
  cat("This .R file and the report PDF are the submission files.\n")
}, finally={
  setwd(submission_previous_wd)
  options(submission_previous_options)
  .libPaths(submission_previous_libraries)
})
