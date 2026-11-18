# Creates model-ready samples and a host-level split; fits no model and scores no test outcomes.
source("scripts/03_descriptive_analysis.R")
source("config/model_spec.R")
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
