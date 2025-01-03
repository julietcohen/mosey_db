#!/usr/bin/env Rscript --vanilla

'
Load cleaned movebank data from csv to database. Need to pass in either a studyid or the path to the data to load.

Usage:
import_study.r [--studyid=<studyid>] [--clean=<clean>] [--db=<db>] [--seed=<seed>] [-t] [-b]
import_study.r (-h | --help)

Options:
-h --help     Show this screen.
-v --version     Show version.
-i --studyid=<studyid>  The study id of the data to load. If passed in, data comes from <wd>/data/<studyid>/clean
-c --clean=<clean>  Directory containing the clean csv files. If not passed in, need to suppy studyid.
-d --db=<db> Data in the <clean> directory will be imported into the database at <db>. Defaults to <wd>/data/mosey.db
-s --seed=<seed>  Random seed. Defaults to 5326 if not passed
-t --test         Indicates script is a test run, will not save output parameters or commit to git
-b --rollback   Rollback the transaction before exiting the script.

' -> doc

isAbsolute <- function(path) {
  grepl("^(/|[A-Za-z]:|\\\\|~)", path)
}

#---- Parameters ----#

if(interactive()) {
  library(here)
  
  .wd <- '~/projects/movedb/analysis/test_get_clean'
  .seed <- NULL
  .test <- TRUE
  .rollback <- TRUE
  rd <- here
  
  .studyid <- 631036041
  .dbPF <- file.path(.wd,'data/mosey.db')
  .cleanP <- .outP <- file.path(.wd,'data',.studyid,'clean')
} else {
  suppressPackageStartupMessages({
    library(docopt)
    library(rprojroot)
    library(R.utils)
  })
  
  ag <- docopt(doc, version = '0.1\n')
  .wd <- getwd()
  .script <-  whereami::thisfile()
  .seed <- ag$seed
  .test <- as.logical(ag$test)
  .rollback <- as.logical(ag$rollback)
  
  rd <- is_rstudio_project$make_fix_file(.script)
  
  .studyid <- as.numeric(ag$studyid)

  if(length(ag$db)==0) {
    .dbPF <- file.path(.wd,'data','mosey.db')
  } else {
    .dbPF <- trimws(ag$db)
  }
  
  if(length(ag$clean)==0) {
    invisible(stopifnot(length(.studyid)>0))
    .cleanP <- file.path(.wd,'data',.studyid,'clean')
  } else {
    .cleanP <- ifelse(isAbsolute(ag$clean),ag$clean,file.path(.wd,ag$clean))
  }
}

#---- Initialize Environment ----#
.seed <- ifelse(is.null(.seed),5326,as.numeric(.seed))

set.seed(5326)
t0 <- Sys.time()

source(rd('startup.r'))

suppressWarnings(
  suppressPackageStartupMessages({
    library(DBI)
    library(knitr)
    library(lubridate)
    library(RSQLite)
    library(here)
}))

#Source all files in the auto load funs directory
list.files(rd('funs/auto'),full.names=TRUE) %>%
  walk(source)

#---- Local parameters ----#

#---- Initialize database ----#
invisible(assert_that(file.exists(.dbPF)))
db <- DBI::dbConnect(RSQLite::SQLite(), .dbPF)
invisible(assert_that(length(dbListTables(db))>0))

fields <- read_csv('/Users/juliet/Documents/OliverLab/covid_paper/repositories/mosey_db/fields.csv',col_types=cols())

#---- Functions ----#

#Format POSIXct according to movebank before writing to the database
movebankTs <- function(x) strftime(x,format='%Y-%m-%d %H:%M:%OS3',tz='UTC')

loadInsert <- function(entity,fields) {
  #entity <- 'event'
  coltypes <- fields %>% 
    filter(table==entity & !is.na(type_clean)) %>% 
    pull('type_clean') %>% paste(collapse="")
  
  dat <- read_csv(file.path(.cleanP,glue('{entity}.csv')),col_type=coltypes)
  
  if(entity == 'event') {
    study_df <- read_csv(file.path(.cleanP,'study.csv'))
    study_id <- study_df$study_id[1]
    dat$study_id <- study_id
  }
  
  rows <- dat %>% 
    mutate_if(is.POSIXct,movebankTs) %>%
    dbAppendTable(db, entity, .)
}

#---------------------#
#---- Main script ----#
#---------------------#
message('Importing data...')

invisible(dbExecute(db,'PRAGMA foreign_keys=ON'))

dbBegin(db)

entities <- c('tag','study','sensor','individual','deployment','event')

rows <- entities %>% map_int(loadInsert,fields=fields)

message(glue('Inserted the following rows into the database'))

tibble(entities,rows) %>% 
  kable(format.args = list(big.mark = ",")) %>%
  paste(collapse='\n') %>% message

#---- Finalize script ----#

if(.rollback) {
  message('Rolling back transaction because this is a test run.')
  dbRollback(db)
} else {
  dbCommit(db)
}

dbDisconnect(db)

message(glue('Script complete in {diffmin(t0)} minutes'))
