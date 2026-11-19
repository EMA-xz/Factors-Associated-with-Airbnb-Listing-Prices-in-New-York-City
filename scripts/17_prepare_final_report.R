# Full analytical entry point. Recomputations verify the frozen specification;
# they do not choose models from test scores. All report numbers originate in R.
source("scripts/04_generate_eda.R")
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
source("scripts/15_freeze_final_model.R")
source("scripts/16_evaluate_reserved_hosts.R")
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
