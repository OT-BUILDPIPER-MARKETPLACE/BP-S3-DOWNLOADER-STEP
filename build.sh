#!/bin/bash

source /opt/buildpiper/shell-functions/functions.sh
source /opt/buildpiper/shell-functions/log-functions.sh
source /opt/buildpiper/shell-functions/str-functions.sh
source /opt/buildpiper/shell-functions/file-functions.sh
source /opt/buildpiper/shell-functions/aws-functions.sh

CODEBASE_LOCATION="${WORKSPACE}/${CODEBASE_DIR}"
logInfoMessage "I'll do processing at [$CODEBASE_LOCATION]"
sleep  $SLEEP_DURATION

if [ "$ASSUME_OTHER_ROLE" == true ]
then
    role_output=$(aws sts assume-role --role-arn arn:aws:iam::$ACCOUNT_ID:role/$ROLE_NAME --role-session-name $ROLE_SESSION_NAME)
    if [ $? -ne 0 ]; then
        echo "Failed to assume role."
        exit 1
    fi
    AWS_ACCESS_KEY_ID=$(echo $role_output | jq -r '.Credentials.AccessKeyId')
    AWS_SECRET_ACCESS_KEY=$(echo $role_output | jq -r '.Credentials.SecretAccessKey')
    AWS_SESSION_TOKEN=$(echo $role_output | jq -r '.Credentials.SessionToken')
    export AWS_ACCESS_KEY_ID
    export AWS_SECRET_ACCESS_KEY
    export AWS_SESSION_TOKEN
fi

cd "${CODEBASE_LOCATION}"

if [ -z "$S3_BUCKET" ] || [ -z "$FETCH_NUMBER" ]; then
    logErrorMessage "S3 bucket and fetch number must be provided."
    exit 1
fi

if [ "$FETCH_NUMBER" -lt 1 ] || [ "$FETCH_NUMBER" -gt 10 ]; then
    logErrorMessage "Fetch number should be between 1 and 10."
    exit 1
fi

logInfoMessage "Fetching the $FETCH_NUMBER latest zip file from S3 bucket: $S3_BUCKET"

# Get the list of latest 10 zip files sorted by timestamp in the filename
FILES_LIST=$(aws s3 ls "s3://$S3_BUCKET/" | grep "\.zip" | awk '{print $4}' | sort -t'-' -k2,2nr -k3,3nr -k4,4nr -k5,5nr | head -10)

# Convert FILES_LIST to an array
FILES_ARRAY=($FILES_LIST)

if [ "${#FILES_ARRAY[@]}" -lt "$FETCH_NUMBER" ]; then
    logErrorMessage "Requested file number exceeds available latest 10 zip files in the bucket."
    exit 1
fi

logInfoMessage "Latest 10 zip files in S3 bucket:"
for file in "${FILES_ARRAY[@]}"; do
    logInfoMessage "$file"
done

# Get the requested zip file
ZIP_FILE=${FILES_ARRAY[$((FETCH_NUMBER-1))]}

logInfoMessage "Fetching file: $ZIP_FILE"

# Download the zip file from S3
aws s3 cp "s3://$S3_BUCKET/$ZIP_FILE" "$ZIP_FILE"
if [ $? -ne 0 ]; then
    logErrorMessage "Failed to download $ZIP_FILE from S3."
    exit 1
fi

logInfoMessage "Successfully downloaded $ZIP_FILE"

# Ensure unzip is installed
if ! command -v unzip &> /dev/null; then
    logInfoMessage "Installing unzip..."
    yum update -y && yum install -y unzip
fi

# Extract the zip file
unzip "$ZIP_FILE"
if [ $? -ne 0 ]; then
    logErrorMessage "Failed to extract $ZIP_FILE."
    exit 1
fi

logInfoMessage "Successfully extracted $ZIP_FILE"

# Rename the downloaded zip file
mv "$ZIP_FILE" "zip-dist.zip"
logInfoMessage "Renamed $ZIP_FILE to zip-dist.zip"

# List the extracted files
logInfoMessage "Listing extracted files:"
ls -lah
