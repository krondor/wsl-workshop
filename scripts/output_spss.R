# This file is generated and can be overwritten.
# This is generated base on output_spss.csv
suppressWarnings(library("v2viz"))
library(dplyr)
library(stringr)

refine_dataframe <-function(df) {
  df_new <- df %>% 
      mutate_all(funs(as.character)) %>%
      rename(`concave_points_mean` = `concave points_mean`) %>%
      rename(`concave_points_se` = `concave points_se`) %>%
      rename(`concave_points_worst` = `concave points_worst`) 
  return (df_new)
}

# output file if NULL return df, otherwise, write to file 
refine_file <- function (input, output=NULL, overwrite="FALSE") { 
  if (is.na(overwrite)) { overwrite = "FALSE"}
  if (is.na(output)) { output = NULL}
  if(!file.exists(input)) { 
    return (paste(input, "file does not exist")); 
  } 
  if (!is.null(output) && file.exists(output) && !(overwrite == "TRUE")) { 
    return (paste(output, "already exists.")); 
  } 
  df <- read.csv(input, check.names=FALSE, stringsAsFactors=FALSE) 
  df <- refine_dataframe(df) 
  if (!is.null(output)) { 
    write.csv(df, file = output, row.names=FALSE) 
    return(paste("Writing to", output, "file is complete")) 
  } else { 
    return (df) 
  } 
}

# main entry for Rscript
args <- commandArgs(trailingOnly = TRUE)
opts<-c();
for (arg in args) {
   x <- lapply(strsplit(arg, split="="), trimws);
   opts[x[[1]][1]] <-x[[1]][2];
}
# validate
required <- c(opts['input']);
missingRequired <- any(is.na(required));
if (missingRequired) {
   print("Missing required parameter");
} else {
   refine_file(opts['input'], opts['output'], opts['overwrite']);
}
