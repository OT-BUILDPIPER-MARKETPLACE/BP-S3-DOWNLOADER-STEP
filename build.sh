#!/bin/bash
source /opt/buildpiper/shell-functions/functions.sh
source /opt/buildpiper/shell-functions/log-functions.sh
source /opt/buildpiper/shell-functions/str-functions.sh
source /opt/buildpiper/shell-functions/file-functions.sh
source /opt/buildpiper/shell-functions/aws-functions.sh

CODEBASE_LOCATION="${WORKSPACE}/${CODEBASE_DIR}"
logInfoMessage "I'll do processing at [$CODEBASE_LOCATION]"
sleep $SLEEP_DURATION
cd "${CODEBASE_LOCATION}"

TASK_STATUS=0

# -------------------------------
# Input validations
# -------------------------------
if [ "$(isStrNonEmpty $S3_BUCKET)" -ne 0 ]; then
    TASK_STATUS=1
    logErrorMessage "S3 bucket is not provided. Please check"
elif [ "$(isStrNonEmpty ${FILE_PATH})" -ne 0 ]; then
    TASK_STATUS=1
    logErrorMessage "File path for download is not provided. Please check"
elif [ "$(bucketExist ${S3_BUCKET})" -ne 0 ]; then
    TASK_STATUS=1
    logErrorMessage "Unable to access S3 bucket – does not exist or missing permissions"
elif [ "$(isStrNonEmpty ${FILE_KEY})" -ne 0 ]; then
    TASK_STATUS=1
    logErrorMessage "File key is not provided. Please check"
fi

logInfoMessage "Received below arguments"
logInfoMessage "File path where downloading happens: ${FILE_PATH}"
logInfoMessage "S3 Bucket: ${S3_BUCKET}"
logInfoMessage "Location of file/folder in S3 Bucket: ${FILE_KEY}"
logInfoMessage "RECURSIVE Mode: ${RECURSIVE}"

# -------------------------------
# Recursive or non-recursive download
# -------------------------------
if [ "${RECURSIVE}" = true ]; then
    logInfoMessage "Recursive download enabled"
    aws s3 cp "s3://${S3_BUCKET}/${FILE_KEY}" "${FILE_PATH}" --recursive
else
    logInfoMessage "Downloading single file"
    aws s3 cp "s3://${S3_BUCKET}/${FILE_KEY}" "${FILE_PATH}"
fi

TASK_STATUS=$?
saveTaskStatus ${TASK_STATUS} ${ACTIVITY_SUB_TASK_CODE}
