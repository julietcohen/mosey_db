#!/usr/bin/env Rscript --vanilla

#TODO: if script fails, remove download folder?
#TODO: now that I'm requesting all entities in a standard way I could use a function
#       to download data.
#TODO: since I'm now saving just the raw files, I can save directly to disk using rmoveapi
#       I'll just need to replace all \r\n with "" because direct save does not do this.
#TODO: print out the numer of events downloaded. Throw warning if 0 events?

doc <- "Get and clean all data for a study from movebank api
        Usage:
        get_study.r --studyid=<studyid> [--raw=<raw>] [-t] [--auth=<auth>] [--seed=<seed>]
        get_study.r (-h | --help)
        
        Options:
        -h --help     Show this screen.
        -v --version     Show version.
        -r --raw=<raw>  Directory for saving csv files. Defaults to <wd>/data/<studyid>/raw.
        -a --auth=<auth>  Authentication method. Can be password, keyring, or path to yml file. Default is keyring.
        -s --seed=<seed>  Random seed. Defaults to 5326 if not passed
        -t --test         Indicates script is a test run, will not save output parameters or commit to git"

isAbsolute <- function(path) {
  grepl("^(/|[A-Za-z]:|\\\\|~)", path)
}

#---- Input Parameters ----#
if(interactive()) {
  library(here)
  
  .wd <- '~/Documents/OliverLab/covid_paper/new_spp_db/mosey_db_output'
  .seed <- NULL
  .test <- TRUE
  rd <- here

  .studyid <- 3266430241
  .auth <- file.path(.wd,'auth.yml')
  .rawP <- file.path(.wd,'raw_csvs',.studyid,'raw')
  
} else {
  suppressPackageStartupMessages({
    library(docopt)
    library(rprojroot)
    library(whereami)
    library(glue)
  })
  
  ag <- docopt(doc)
  #message("Raw command line args:")
  #print(commandArgs())
  # .wd <- getwd()
  .wd <- '~/Documents/OliverLab/covid_paper/new_spp_db/mosey_db_output'
  .script <-  whereami::thisfile()
  .seed <- ag$seed
  .test <- as.logical(ag$test)
  rd <- is_rstudio_project$make_fix_file(.script)
  
  .auth <- ag$auth
  .studyid <- as.numeric(ag$studyid)
  #.studyid <- ag$studyid
  message(glue("Study ID value: {.studyid}"))
  message(glue("Class of Study ID value: {class(.studyid)}"))
  
  if(length(ag$raw)==0) {
    .rawP <- file.path(.wd,'data',.studyid,'raw')
  } else {
    .rawP <- ifelse(isAbsolute(ag$raw),ag$raw,file.path(.wd,ag$raw))
  }
}

#---- Initialize Environment ----#
.seed <- ifelse(is.null(.seed),5326,as.numeric(.seed))

set.seed(.seed)
t0 <- Sys.time()

source(rd('~/Documents/OliverLab/covid_paper/repositories/mosey_db/startup.r'))

suppressPackageStartupMessages({
  library(getPass)
  library(keyring)
  library(rmoveapi)
  library(move)
  library(tictoc)
  library(yaml)
  library(move2)
})

#Source all files in the auto load funs directory
list.files(rd('funs/auto'),full.names=TRUE) %>%
  walk(source)

#This sets the movebank output format for timestamps for write_csv
output_column.POSIXct <- function(x) {
  format(x, "%Y-%m-%d %H:%M:%OS3", tz='UTC')
}

# If auth is null, look for auth.yml in the working directory
# otherwise based on user request
if(is.null(.auth) || grepl('.*\\.yml$',.auth)) {
  if(is.null(.auth)) {
    yamlPF <- file.path(.wd,'auth.yml')
  } else {
    yamlPF <- ifelse(isAbsolute(.auth),.auth,file.path(.wd,.auth))
  }
  cred <- read_yaml(yamlPF)
  setAuth(cred$user,cred$pass)
  # movebank_store_credentials(cred$user, cred$pass)
} else if(.auth=='keyring') {
  # movebank_store_credentials(key_get('movebank_user'), key_get('movebank_pass'))
  setAuth(key_get('movebank_user'),key_get('movebank_pass'))
} else if(.auth=='input') {
  # movebank_store_credentials(getPass('Movebank user:'), getPass('Movebank password:'))
  setAuth(getPass('Movebank user:'),getPass('Movebank password:'))
} else {
  stop('Invalid authentication method')
}

dir.create(.rawP,showWarnings=FALSE,recursive=TRUE)

invisible(assert_that(dir.exists(.rawP)))

#---- Local parameters ----#

#Make csv paths and convert to list for convenience
csvPF <- tibble(
  FN=c('study','individual','sensor','tag','deployment','event')) %>%
  mutate(PF=file.path(.rawP,glue('{FN}.csv'))) %>%
  deframe %>% as.list

dfs <- list() #Holds references to entity dataframes

#---- Load data ----#

fields <- read_csv('/Users/juliet/Documents/OliverLab/covid_paper/repositories/mosey_db/fields.csv')

message(glue('Downloading data for study {.studyid} from movebank'))

#---------------#
#---- study ----#
#---------------#
message('Getting study data')

attributes <- fields %>% 
              filter(table=='study' & !is.na(name_raw)) %>% 
              pull('name_raw')

# rmoveapi is a custom package by ben, maybe use move2::movebank_download_study
dfs$study <- getStudy(.studyid,params=list(attributes=attributes))
# dfs$study <-movebank_download_study(.studyid, attributes = "all")


message(glue('Study name is: {dfs$study$name}'))
message(glue('Reported num individuals: {dfs$study$number_of_individuals}, num events: {format(dfs$study$number_of_deployed_locations,big.mark=",")}'))


#--------------------#
#---- individual ----#
#--------------------#
message('Getting individual data')

attributes <- fields %>% filter(table=='individual' & !is.na(name_raw)) %>% pull('name_raw')

dfs$individual <- getIndividual(.studyid,params=list(attributes=attributes),accept_license=TRUE)

#----------------#
#---- sensor ----#
#----------------#
message('Getting sensor data')

attributes <- fields %>% filter(table=='sensor' & !is.na(name_raw)) %>% pull('name_raw')

dfs$sensor <- getSensor(.studyid,params=list(attributes=attributes))

#----------------#
#---- tag ----#
#----------------#
message('Getting tag data')

attributes <- fields %>% filter(table=='tag' & !is.na(name_raw)) %>% pull('name_raw')

dfs$tag <- getTag(.studyid,params=list(attributes=attributes))

#--------------------#
#---- deployment ----#
#--------------------#
message('Getting deployment data')

attributes <- fields %>% filter(table=='deployment' & !is.na(name_raw)) %>% pull('name_raw')

dfs$deployment <- getDeployment(.studyid,params=list(attributes=attributes))

#---------------#
#---- event ----#
#---------------#

message('Getting GPS (653) event data. This can take awhile...')
message(glue('Saving event data to csv file in {csvPF$event}'))

attributes <- fields %>% filter(table=='event' & !is.na(name_raw)) %>% pull('name_raw')

tic()
status <- getEvent(.studyid,attributes,sensor_type_id=653,save_as=csvPF$event)
toc()

invisible(assert_that(status)) #Should be TRUE if events were downloaded successfully

#---------------------------------------------------#
#---- Warn if there are entities with 0 records ----#
#---------------------------------------------------#

rcount <- dfs %>% map(~{nrow(.x)})

#Get row count from event because that was downloaded directly to disk
#Subtract 1 becuase the header row is counted
#TODO: make a function countlinesf() for this common bit of code

rcount$event <- glue('wc -l < "{path.expand(csvPF$event)}"') %>% 
  system(intern=T) %>% trimws %>% as.integer - 1

as_tibble(rcount) %>% gather(key='entity',value='num') %>% 
  filter(num <= 0) %>%
  pull(entity) %>% 
  walk(~warning(glue('Entity "{.x}" has 0 records'),call.=FALSE))

#------------------------------------#
#---- Write out raw data to csvs ----#
#------------------------------------#

message(glue('Saving data to csv files in {.rawP}'))

#Write other entities to disk. Event data was saved directly to disk so don't write that.
csvPF %>%
  list_modify('event'=NULL) %>%
  iwalk(~{
    if (!is.null(dfs[[.y]]) && is.data.frame(dfs[[.y]])) {
      write_csv(dfs[[.y]], .x, na="")
    }
  })

message(glue('Script complete'))
