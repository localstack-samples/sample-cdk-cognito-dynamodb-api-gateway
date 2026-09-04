export AWS_ACCESS_KEY_ID ?= test
export AWS_SECRET_ACCESS_KEY ?= test
export AWS_DEFAULT_REGION=us-east-1
SHELL := /bin/bash

## Show this help
usage:
		@fgrep -h "##" $(MAKEFILE_LIST) | fgrep -v fgrep | sed -e 's/\\$$//' | sed -e 's/##//'

## Install dependencies
install:
		@which lstk || npm install -g @localstack/lstk

# Deploy the infrastructure
build:
		cd deployment && ./build.sh;

## Deploy the infrastructure
deploy:
		cd deployment && ./deploy-local.sh;

## Start LocalStack in detached mode
start:
		@test -n "${LOCALSTACK_AUTH_TOKEN}" || (echo "LOCALSTACK_AUTH_TOKEN is not set. Find your token at https://app.localstack.cloud/workspace/auth-token"; exit 1)
		LOCALSTACK_EXTRA_CORS_ALLOWED_ORIGINS=* LOCALSTACK_AUTH_TOKEN=$(LOCALSTACK_AUTH_TOKEN) lstk start

## Stop the Running LocalStack container
stop:
		@echo
		lstk stop

## Save the logs in a separate file, since the LS container will only contain the logs of the last sample run.
logs:
		@lstk logs > logs.txt

.PHONY: usage install run start stop logs
