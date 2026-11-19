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
