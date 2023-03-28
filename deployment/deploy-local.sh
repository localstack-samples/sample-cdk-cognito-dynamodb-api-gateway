#!/bin/bash

# Copyright Amazon.com, Inc. or its affiliates. All Rights Reserved.
# SPDX-License-Identifier: MIT-0

#####################################################################
# TRAP SHELL SIGNALS

# clean-up on exit
trap trap_signals 0 INT QUIT KILL TERM
trap_signals() {
    rm -rf /tmp/$$*
}

#####################################################################
# PREFLIGHT CHECK

if [ -z "$AWS_CLI_BIN" ]; then
    AWS_CLI_BIN="awslocal"
fi

#####################################################################
# VARIABLES

outputs_file="/tmp/$$.cdk-infrastructure-outputs.json"

#####################################################################
# BUILD

# build all lambdas first
# do an incremental build during deployment.  this speeds up deployment time
./build.sh incremental

#####################################################################
# DEPLOYMENT

# log some info
echo
echo "Initiating CDK deployment.."

yarn add @aws-cdk/core@1.197.0

echo "Bootstrap CDK"
cdklocal bootstrap aws://000000000000/us-east-1 || exit 4

echo "Deployment for CDK stacks"

cdklocal deploy \
    --require-approval never \
    --outputs-file "${outputs_file}" \
    --all || exit 5

# Prepare web-ui deployment
export COGNITO_USER_POOL_ID="$(awk '/UserPoolId/{ gsub(/"|,/, ""); print $2 }' "$outputs_file")"
export COGNITO_CLIENT_ID="$(awk '/UserPoolClientId/{ gsub(/"|,/, ""); print $2 }' "$outputs_file")"
export API_GATEWAY_API_NAME="$(awk '/RestApiName/{ gsub(/"|,/, ""); print $2 }' "$outputs_file")"
export API_GATEWAY_API_ENDPOINT="$(awk '/StageUrl/{ gsub(/"|,/, ""); print $2 }' "$outputs_file")"
export S3_BUCKET_NAME="$(awk '/WebUiBucketName/{ gsub(/"|,/, ""); print $2 }' "$outputs_file")"
export CLOUDFRONT_DISTRIBUTION_ID="$(awk '/CloudfrontDistributionId/{ gsub(/"|,/, ""); print $2 }' "$outputs_file")"
export CLOUDFRONT_DISTRIBUTION_DOMAIN="$(awk '/CloudfrontDistributionDomainName/{ gsub(/"|,/, ""); print $2 }' "$outputs_file")"

# Deploy the Web UI
echo
echo "Deploying Sample Web App.."
(cd ../source/sample-web-app && ./build-local.sh && ./deploy-local.sh ) || exit 6

# Log more information
echo
echo "Sample Web App URL: ${CLOUDFRONT_DISTRIBUTION_DOMAIN}"
