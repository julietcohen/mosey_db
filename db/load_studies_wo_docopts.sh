#!/bin/bash

# Default values
csvdir="."
db="data/mosey.db"
process="dciv"

# Parse command-line arguments
while [[ "$#" -gt 0 ]]; do
    case $1 in
        --help)
            echo "Usage: load_studies.sh [options]"
            echo ""
            echo "Options:"
            echo "  --help            Show help options."
            echo "  --version         Print program version."
            echo "  --csvdir=<path>   Path to store raw and clean csv directories."
            echo "  --db=<path>       Path to database. Default is data/mosey.db."
            echo "  --process=<steps> Character string specifying which steps to process. Defaults to dciv. (download, clean, import, validate)"
            exit 0
            ;;
        --version)
            echo "load_datasets 0.1"
            exit 0
            ;;
        --csvdir=*)
            csvdir="${1#*=}"
            ;;
        --db=*)
            db="${1#*=}"
            ;;
        --process=*)
            process="${1#*=}"
            ;;
        *)
            echo "Unknown option: $1"
            exit 1
            ;;
    esac
    shift
done

# Script logic begins here
[[ -z "$csvdir" ]] && csvdir=.
[[ -z "$db" ]] && db="data/mosey.db"
[[ -z "$process" ]] && process="dciv"

# Load datasets
studyIds=($(mlr --csv --opprint filter '$run == 1' then cut -f study_id ctfs/study.csv | tail -n +2))

echo "Loading ${#studyIds[@]} studies."

status=load_status.csv
mkdir -p logs

for studyId in "${studyIds[@]}"; do 
    echo "*******"
    echo "Start processing study ${studyId}"
    echo "*******"
    
    studyId=${studyId%$'\r'}
    
    raw="${csvdir}/${studyId}/raw"
    clean="${csvdir}/${studyId}/clean"

    # Download step
    if [[ "$process" = *d* ]]; then
        echo "Downloading study ${studyId}"
        $MOSEYDB_SRC/db/get_study.r $studyId -r $raw -t 2>&1 | tee logs/$studyId.log
        exitcode=("${PIPESTATUS[@]}")
        if [ ${exitcode[0]} -eq 0 ]; then
            echo "Successfully downloaded study"
            echo "$studyId,download,success" >> $status
        else
            echo "Failed to download study ${studyId}"
            echo "$studyId,download,fail" >> $status
            continue
        fi
    fi

    # Clean step
    if [[ "$process" = *c* ]]; then
        echo "Cleaning study ${studyId}"
        $MOSEYDB_SRC/db/clean_study.r $studyId -c $clean -r $raw -t 2>&1 | tee -a logs/$studyId.log
        exitcode=("${PIPESTATUS[@]}")
        if [ ${exitcode[0]} -eq 0 ]; then
            echo "Successfully cleaned study"
            echo "$studyId,clean,success" >> $status
        else
            echo "Failed to clean study ${studyId}"
            echo "$studyId,clean,fail" >> $status
            continue
        fi
    fi

    # Import step
    if [[ "$process" = *i* ]]; then
        params=()
        [[ ! -z "$db" ]] && params+=("-d $db")
        
        echo "Importing study ${studyId}"
        $MOSEYDB_SRC/db/import_study.r -i $studyId -c $clean "${params[@]}" -t 2>&1 | tee -a logs/$studyId.log
        exitcode=("${PIPESTATUS[@]}")
        if [ ${exitcode[0]} -eq 0 ]; then
            echo "Successfully imported data"
            echo "$studyId,import,success" >> $status
        else
            echo "Failed to import study ${studyId}"
            echo "$studyId,import,fail" >> $status
            continue
        fi
    fi

    # Validate step
    if [[ "$process" = *v* ]]; then
        params=()
        [[ ! -z "$db" ]] && params+=("-d $db")
        
        echo "Validating import for study ${studyId}"
        $MOSEYDB_SRC/db/validate_import.r $studyId -c $clean "${params[@]}" -t 2>&1 | tee -a logs/$studyId.log
        exitcode=("${PIPESTATUS[@]}")
        if [ ${exitcode[0]} -eq 0 ]; then
            echo "Successfully validated import"
            echo "$studyId,validate,success" >> $status
        else
            echo "Failed to validate import for study ${studyId}"
            echo "$studyId,validate,fail" >> $status
            continue
        fi
    fi
done

echo "Script Complete"
