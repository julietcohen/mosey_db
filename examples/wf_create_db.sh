#Example workflow script that creates a database

# path to project working directory: where the new DB should be stored
# wd=~/projects/mycoolproject/analysis
wd=~/Documents/OliverLab/covid_paper/new_spp_db/mosey_db_output

# path to mosey_db repo
# MOSEYDB_SRC=~/projects/mosey_db/src
MOSEYDB_SRC=~/Documents/OliverLab/covid_paper/repositories/mosey_db

cd $wd

mkdir -p data

#-------------------------#
#---- Create database ----#
#-------------------------#

# Don't run this if database already exists!
# Below is commented out to prevent accidental execution

cat $MOSEYDB_SRC/db/create_db.sql | sqlite3 data/mosey.db