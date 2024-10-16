#!/usr/bin/env fish

sorce shared.fish

# This is the local subfolder where the processed file markers are stored:
#   - processed_minio
#   - processed_digitalocean
set processed_subfolder $argv[1]
# This should be a folder like `dev/` or `public-prod/` corresponding to the same thing as in the env
set s3_subfolder $argv[2]

cd $dataDir
# Use s3cmd to upload files to S3 backup

echo "Checking for new files "(date)

sudo mkdir -p $dataDir/$processed_subfolder
sudo chown -R runner:runner $dataDir/$processed_subfolder
sudo rm -rf $dataDir/lost+found

for file in (find . -maxdepth 1 -type f);
    set file (basename $file);

    # if ends with .dl, skip
    if string match -q "*.dl" $file
        continue
    end

    if test -f $dataDir/$processed_subfolder/$file
        #echo "$file has already been processed, skipping..."
        continue
    end

    set FILE_EXISTS (s3cmd ls s3://imagehost-files/$s3_subfolder$file | wc -l)
    echo "s3://imagehost-files/$s3_subfolder$file :" $FILE_EXISTS
    # Check if file exists on S3 before uploading
    if test $FILE_EXISTS -eq 0
        echo "$file does not exist on S3, uploading..."
        s3cmd put "$file" "s3://imagehost-files/$s3_subfolder$file"
        if test $status -eq 0
            echo "Upload successful, touching $processed_subfolder/$file"
            touch $dataDir/$processed_subfolder/$file
        end
    else
        echo "$file already exists on S3, only touching..."
        touch $dataDir/$processed_subfolder/$file
    end

    # Create a file to mark that the file has been processed
end
