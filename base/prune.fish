#!/usr/bin/env fish

source /scripts/shared.fish
set age_minutes $argv[1]

function prune_precheck
    if check_if_disk_needs_pruning
        echo "Disk usage is high, pruning files older than $age_minutes minutes..."
    else
        echo "Disk usage is low, no need to prune. Sleeping for 30 mins."
        sleep 1800
        exit 0
    end
end

prune_precheck

# Look for all files and delete them. This includes .dl files too
# (%T@ %p) is the unix timestamp and the file path
# {print $NF} prints the last column
set files (find . -maxdepth 1 -type f ! -mmin "+$age_minutes" -printf "%T@ %p\n" | sort -n | awk '{print $NF}')

set might_prune ""

for file in $files
    # if a file exists, test -f will return 0
    test -f "$dataDir/processed_minio/$file"
    set has_minio $status
    #test -f "$dataDir/processed_digitalocean/$file"
    #set has_do $status
    if test $has_minio -eq 0
        #if test $has_do -eq 0
            #echo "Deleting $file : BOTH MINIO and DO backup"
        #end
        echo "Deleting $file : Has minio backup"
        # Add to might_prune array
        set might_prune $might_prune $file
        #sudo rm $file
    end
end
