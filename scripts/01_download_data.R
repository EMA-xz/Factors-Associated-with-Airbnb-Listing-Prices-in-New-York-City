source("scripts/00_config.R")
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
