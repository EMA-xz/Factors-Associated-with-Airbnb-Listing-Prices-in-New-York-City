# Install model-specific dependencies locally; do not modify the user's global R library.
dir.create(".r-library",showWarnings=FALSE)
.libPaths(c(normalizePath(".r-library"),.libPaths()))
packages <- "sandwich"
needed <- packages[!vapply(packages,requireNamespace,logical(1),quietly=TRUE)]
if(length(needed)) install.packages(needed,lib=".r-library",repos="https://cloud.r-project.org",type="source")
stopifnot(all(vapply(packages,requireNamespace,logical(1),quietly=TRUE)))
