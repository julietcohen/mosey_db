# wd=~/projects/mycoolproject/analysis
# out=~/projects/mycoolproject/analysis/data
# src=~/projects/movebankdb/src

#wd=~/Documents/OliverLab/covid_paper/new_spp_db/mosey_db_output
out=~/Documents/OliverLab/covid_paper/new_spp_db/mosey_db_output/raw_clean_csv_dirs
src=~/Documents/OliverLab/covid_paper/repositories/mosey_db
db=~/Documents/OliverLab/covid_paper/new_spp_db/mosey_db_output/data/mosey.db

cd $wd

# In order to run the script below, set up a study control file and an authentication file
# 1) In the control files directory $wd/ctfs, create a file called study.csv with 
# columns for (at minimum) a column 'study_id', 'run'. See example in src/examples/study.csv
# 2) In the main working directory, $wd, set up auth.yml with your authentication information.
# See the file src/examples/study.csv

# run the script and pass "out"" as the "csvdir" arg, and "src" as the "db" arg
$src/db/load_studies.sh --db=$db --csvdir=$out
  
