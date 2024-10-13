#!/usr/bin/env fish

cd /data/juushFiles

set age_minutes $argv[1]

# Look for all files and delete them
set files (find . -maxdepth 1 -type f ! -name ".dl" -mmin "+$age_minutes")
for file in $files
    # check for both $dataDir/processed_minio/$file and $dataDir/processed_digitalocean/$file
    # if a file exists, test -f will return 0
    test -f "/data/juushFiles/processed_minio/$file"
    set has_minio $status
    test -f "/data/juushFiles/processed_digitalocean/$file"
    set has_do $status
    if test $has_minio -eq 0
        if test $has_do -eq 0
            echo "Deleting $file : BOTH MINIO and DO backup"
        else
            echo "Deleting $file : MINIO backup"
        end
        sudo rm $file
    end
end
