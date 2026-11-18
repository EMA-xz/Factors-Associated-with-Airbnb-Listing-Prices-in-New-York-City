# Complete reproducible EDA entry point; this executes download, audit and summaries.
if (!requireNamespace("ggplot2", quietly = TRUE)) {
  stop("Install the plotting dependency first: install.packages('ggplot2')")
}
source("scripts/03_descriptive_analysis.R")
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
