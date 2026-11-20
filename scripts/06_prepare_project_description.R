# Regenerate every empirical input, then create a shared payload for the report formats.
if(!requireNamespace("jsonlite",quietly=TRUE)) stop("Install jsonlite: install.packages('jsonlite')")
source("scripts/04_generate_eda.R")
source("scripts/05_prepare_model_samples.R")
dir.create("reports/project_description",recursive=TRUE,showWarnings=FALSE)
money <- function(x) sprintf("$%s",formatC(x,format="f",digits=2,big.mark=","))
pct <- function(x) sprintf("%.1f%%",x)
team <- read.csv("config/team.csv",colClasses="character",stringsAsFactors=FALSE)
if(nrow(team)>0) {
  stopifnot(nrow(team)>=3,nrow(team)<=5,all(!is.na(team$name) & nzchar(trimws(team$name))),
    all(!is.na(team$uni) & nzchar(trimws(team$uni))),!anyDuplicated(team$uni))
}
team_text <- if(nrow(team)) paste(paste0(team$name," (",team$uni,")"),collapse="; ") else
  "Team members and UNIs: __________________________________________________"
paragraph <- function(text) list(type="paragraph",text=text)
heading <- function(text) list(type="heading",text=text)
figure <- function(file,width=6.65) list(type="figure",file=paste0("figures/",file),width=width)
tab <- function(headers,rows,widths) list(type="table",headers=headers,rows=rows,widths=widths)
prices <- by_group[by_group$variable=="price",]
price_table <- lapply(seq_len(nrow(prices)),function(i) {
  z<-prices[i,]
  c(paste(z$borough,z$room_type,sep="\n"),fmt(z$observed_n),money(z$median),money(z$mean),money(z$sd),
    paste0(money(z$q25)," to\n",money(z$q75)))
})
chars <- overall[overall$variable %in% c("accommodates","bedrooms","minimum_nights","review_scores_rating"),]
var_names <- c(accommodates="Guest capacity",bedrooms="Bedrooms",minimum_nights="Minimum nights",review_scores_rating="Review score")
char_table <- lapply(seq_len(nrow(chars)),function(i){z<-chars[i,];c(var_names[z$variable],fmt(z$observed_n),fmt(z$missing_n),
  sprintf("%.2f",z$median),sprintf("%.2f",z$q25),sprintf("%.2f",z$q75))})
composition_table <- lapply(seq_len(nrow(coverage)),function(i){
  z<-coverage[i,]; g<-long_stay[long_stay$borough==z$borough & long_stay$room_type==z$room_type,]
  h<-hotel_summary[hotel_summary$borough==z$borough & hotel_summary$room_type==z$room_type,]
  c(paste(z$borough,z$room_type,sep="\n"),pct(z$positive_price_pct),pct(g$within_status_pct),pct(h$hotel_like_label_pct))
})
overall_price <- overall[overall$variable=="price",]
capacity_ids <- c("Brooklyn","Manhattan")
capacity_note <- paste(vapply(capacity_ids,function(b){
  z<-by_group[by_group$borough==b & by_group$variable=="accommodates",]
  paste0(b,": median capacity is ",fmt(z$median[z$room_type=="Entire home/apt"])," for entire homes and ",
    fmt(z$median[z$room_type=="Private room"])," for private rooms")
},character(1)),collapse="; ")
pages <- list(
 list(title="Airbnb Listing Prices in Manhattan and Brooklyn",blocks=list(
  list(type="subtitle",text="Project Description | STAT GU4205/GR5205 | Fall 2026"),
  list(type="small",text=team_text),
  heading("Study objectives"),
  paragraph("A private room and an entire apartment can differ in how many guests they accommodate and how long a guest must stay. We compare nightly prices in Manhattan and Brooklyn while accounting for guest capacity, bedrooms and minimum-stay requirements."),
  list(type="numbered",items=c("Do adjusted borough price differences persist within each room type?",
    "Do adjusted room-type price differences persist within each borough?",
    "Is the price gap between entire homes and private rooms larger in one borough than in the other?")),
  heading("Data source and analytical sample"),
  paragraph(paste0("We use Inside Airbnb's September 2026 snapshot of ",fmt(nrow(raw)),
    " New York City listings [1]. Each observation represents one listing. Price is the nightly amount in US dollars quoted for the observation [2]. The amount can depend on the dates and length of the requested stay.")),
  paragraph(paste0("Manhattan and Brooklyn together have ",fmt(nrow(d))," entire-home and private-room listings. Of these, ",
    fmt(sum(!d$price_observed))," (",pct(100*mean(!d$price_observed)),") have no recorded price. The price summaries cover all ",
    fmt(nrow(eda))," listings with a positive observed price, including those with missing information on other characteristics.")),
  heading("Daily price summaries in USD"),
  tab(c("Borough and room type","n","Median","Mean","SD","Q1 to Q3"),price_table,c(1.70,.55,.80,.80,.80,1.05)),
  list(type="small",text="Q1 and Q3 are the 25th and 75th percentiles. These comparisons are unadjusted.")
 )),
 list(title="Raw price distribution",blocks=list(
  paragraph(paste0("Across the exploratory sample, the mean daily price is ",money(overall_price$mean),
    " and the median is ",money(overall_price$median),". Prices range from ",money(overall_price$min)," to ",money(overall_price$max),
    ", indicating a long upper tail that deserves attention in model diagnostics.")),
  figure("01_raw_price_distribution.png",6.6),
  paragraph(paste0("The lower panel of Figure 1 shows prices through the 99th percentile, ",money(zoom_limit),
    ". The ",fmt(hidden_zoom)," higher-priced listings appear in the upper panel and contribute to the mean. The lower panel makes the distribution of more typical nightly prices easier to see."))
 )),
 list(title="Price transformation and listing characteristics",blocks=list(
  figure("02_log_price_distribution.png",6.65),
  paragraph("Figure 2 shows the same listings on a logarithmic scale. A doubling of price spans the same distance anywhere along this axis, which makes proportional differences easier to see. We will use log price to compare percentage differences between groups."),
  heading("Observed covariates in the exploratory sample"),
  tab(c("Variable","Observed n","Missing n","Median","Q1","Q3"),char_table,c(1.55,.95,.85,.80,.80,.75)),
  paragraph("Capacity and bedrooms describe listing size, while minimum nights captures stay requirements. Review scores have substantial missingness and are not required in the planned core model. Missing bedrooms are not recoded as zero; a reported zero-bedroom listing is retained as a possible studio. Repeated listings from the same host will also be considered when evaluating dependence.")
 )),
 list(title="Borough and room type comparisons",blocks=list(
  figure("03_price_by_borough_room_type.png",6.65),
  paragraph(paste0("Figure 3 compares unadjusted distributions. In Manhattan, median price is ",money(mh$median[mh$room_type=="Private room"]),
    " for private rooms and ",money(mh$median[mh$room_type=="Entire home/apt"]),
    " for entire homes. Among listings requiring at least 30 nights, the corresponding medians are ",
    money(mh_long$median_price_usd[mh_long$room_type=="Private room"])," and ",
    money(mh_long$median_price_usd[mh_long$room_type=="Entire home/apt"]),
    ". The ordering of the two room types changes within this subset, giving us a reason to account for minimum-stay requirements in the regression.")),
  tab(c("Borough and room type","Price coverage","Minimum stay 30+","Hotel like label"),composition_table,c(2.0,1.15,1.35,1.20)),
  list(type="small",text="Price coverage uses all scoped listings in that group. The other percentages use positive-price listings, including records with missing minimum stay in their denominators. Hotel like label means property_type contains hotel, hostel or resort, case-insensitively; it is not a verified business or legal classification."),
  paragraph(paste0("Within Manhattan private rooms, ",fmt(mh_private_hotel$hotel_like_label_n)," of ",fmt(mh_private_hotel$n),
    " listings (",pct(mh_private_hotel$hotel_like_label_pct),") meet that label rule. We retain them in the primary scope and plan one sensitivity analysis excluding those labels and unknown property types. Private room itself is retained in both analyses."))
 )),
 list(title="Capacity relationships and planned analysis",blocks=list(
  figure("04_capacity_price_multidimensional.png",6.65),
  paragraph(paste0("Figure 4 shows how nightly prices vary with guest capacity in each borough. ",capacity_note,
    ". The difference in typical capacity motivates adjusting for listing size. The figure includes ",fmt(nrow(scatter_data)),
    " listings. Diamonds mark medians for groups with at least 20 listings. Few private rooms accommodate large groups, so comparisons at high capacity are less informative.")),
  heading("Planned regression and validation"),
  paragraph(paste0("Our starting specification models log price using borough, room type, their interaction, capacity, bedrooms, log minimum nights and an indicator for minimum stays of at least 30 nights. The model sample includes ",
    fmt(nrow(primary))," listings with complete predictors and a known host. The comparison excluding hotel-like and unknown property labels includes ",fmt(nrow(sensitivity)),
    ". We will compare the borough and room-type estimates across these samples.")),
  paragraph("The figures describe the full sample. For regression, we will use about 80% of hosts for training and the rest for testing, keeping each host's listings together. We will examine residual patterns and influential listings, then compare prediction error for the held-out hosts with training error on the log-price scale."),
  list(type="small",text="Limitations include missing-price selection, differing property/stay composition, unmeasured listing characteristics and a single observational snapshot. Results will describe adjusted associations within the chosen sample, not causal effects or all NYC accommodation [3]."),
  heading("References"),
  list(type="small",text=paste0("[1] Inside Airbnb. New York City detailed listings, ",snapshot_date,". CC BY 4.0. https://insideairbnb.com/get-the-data/")),
  list(type="small",text="[2] Inside Airbnb. Data Dictionary for detailed listings. https://docs.google.com/spreadsheets/d/1iWCNJcSutYqpULSQHlNyGInUvHg2BoUGoNRIGa6Szc4/edit"),
  list(type="small",text="[3] Inside Airbnb. Data Assumptions. https://insideairbnb.com/data-assumptions/")
 ))
)
payload <- list(title="Airbnb Listing Prices in Manhattan and Brooklyn",team_complete=nrow(team)>=3,
  source_md5=expected_md5,pages=pages)
jsonlite::write_json(payload,"reports/project_description/report_payload.json",auto_unbox=TRUE,pretty=TRUE,na="null")
# A readable source-format report from exactly the same payload.
md <- character()
for(page in pages) {
  md<-c(md,paste0("# ",page$title),"")
  for(b in page$blocks) {
    if(b$type=="heading") md<-c(md,paste0("## ",b$text),"")
    else if(b$type=="figure") md<-c(md,paste0("![",basename(b$file),"](../../",b$file,")"),"")
    else if(b$type=="numbered") md<-c(md,paste0(seq_along(b$items),". ",b$items),"")
    else if(b$type=="table") {
      md<-c(md,paste0("| ",paste(b$headers,collapse=" | ")," |"),paste0("| ",paste(rep("---",length(b$headers)),collapse=" | ")," |"),
        vapply(b$rows,function(r) paste0("| ",paste(gsub("\n"," ",r),collapse=" | ")," |"),character(1)),"")
    } else md<-c(md,b$text,"")
  }
}
writeLines(md[seq_len(max(which(nzchar(md))))],"reports/project_description/project_description.md")
message("Report payload and Markdown generated. Team metadata complete: ",payload$team_complete)
