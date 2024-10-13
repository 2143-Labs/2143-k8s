#!/usr/bin/env fish

cd /data/juushFiles

# Look for all files older than 20 seconds and delete them
set files (find . -maxdepth 1 -type f ! -name ".dl" -mmin +0.3)
for file in $files
    echo "Want to delete $file"
    # check for both $dataDir/processed_minio/$file and $dataDir/processed_digitalocean/$file
    # if a file exists, test -f will return 0
    test -f "/data/juushFiles/processed_minio/$file"
    set has_minio $status
    test -f "/data/juushFiles/processed_digitalocean/$file"
    set has_do $status
    if test $has_minio -eq 0
        if test $has_do -eq 0
            echo "Deleting $file : BOTH"
        else
            echo "Deleting $file : MINIO ONLY"
        end
        sudo rm $file
    end
end
