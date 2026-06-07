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

cd $dataDir

# Phase 1: Delete orphaned .dl files (never get minio backup, so never get markers)
set dl_files (find . -maxdepth 1 -name '*.dl' -type f -mmin "+$age_minutes" -printf "%p\n")
set dl_count (count $dl_files)
if test $dl_count -gt 0
    echo "Deleting $dl_count orphaned .dl files."
    sudo rm $dl_files
else
    echo "No orphaned .dl files to delete."
end

# Phase 2: Prune backed-up files
set files (find . -maxdepth 1 -type f ! -name '*.dl' -mmin "+$age_minutes" -printf "%T@ %p\n" | sort -n | awk '{print $NF}')

for file in $files
    test -f "$dataDir/processed_minio/$file"
    set has_minio $status
    if test $has_minio -eq 0
        set might_prune $might_prune $file
    end
end

set count (count $might_prune)
if test $count -gt 0
    echo "Deleting $count files older than $age_minutes minutes."
    sudo rm $might_prune
    echo "Deleted $count. Deleting minio backup tags now."
    cd $dataDir/processed_minio
    sudo rm $might_prune
else
    echo "No files to delete."
end

echo "Pruning complete."
