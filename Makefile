.PHONY: lint validate helm-lint helm-template verify-chain docs \
	localstack-up localstack-down tf-init-local tf-apply-local assume-admin \
	bootstrap-local deploy-dev undeploy-dev \
	test test-k8ssa test-external

SHELL := /bin/bash
ROOT := $(abspath $(dir $(lastword $(MAKEFILE_LIST))))
LOCAL := $(ROOT)/local
CHART := $(ROOT)/deploy/helm/step-ca
AWS_DIR := $(ROOT)/infrastructure/aws
AWS_LOCAL := $(AWS_DIR)/local
export AWS_DEFAULT_REGION ?= us-east-1
export AWS_ACCESS_KEY_ID ?= test
export AWS_SECRET_ACCESS_KEY ?= test
export AWS_ENDPOINT_URL ?= http://localhost:4566

lint: helm-lint
	@$(ROOT)/scripts/lint.sh

validate: helm-template
	@$(ROOT)/scripts/validate.sh

helm-lint:
	helm lint $(CHART) -f $(CHART)/values.yaml
	helm lint $(CHART) -f $(CHART)/values.yaml -f $(CHART)/values-dev.yaml
	helm lint $(CHART) -f $(CHART)/values.yaml -f $(CHART)/values-staging.yaml
	helm lint $(CHART) -f $(CHART)/values.yaml -f $(CHART)/values-prod.yaml

helm-template:
	helm template step-ca $(CHART) -f $(CHART)/values.yaml -f $(CHART)/values-dev.yaml >/dev/null
	helm template step-ca $(CHART) -f $(CHART)/values.yaml -f $(CHART)/values-staging.yaml >/dev/null
	helm template step-ca $(CHART) -f $(CHART)/values.yaml -f $(CHART)/values-prod.yaml >/dev/null

verify-chain:
	@$(ROOT)/scripts/verify-chain.sh --root $(LOCAL)/root_ca.crt --intermediate $(LOCAL)/intermediate_ca.crt

docs:
	@echo "Docs under $(ROOT)/docs"

localstack-up:
	docker compose -f $(AWS_LOCAL)/docker-compose.yml up -d
	@$(ROOT)/scripts/localstack/wait.sh

localstack-down:
	docker compose -f $(AWS_LOCAL)/docker-compose.yml down

tf-init-local:
	cd $(AWS_LOCAL) && terraform init -backend=false

tf-apply-local: tf-init-local
	cd $(AWS_LOCAL) && \
	  terraform apply -auto-approve -var-file=terraform.tfvars.example
	@$(ROOT)/scripts/localstack/export-outputs.sh

assume-admin:
	@$(ROOT)/scripts/localstack/assume-role.sh admin

bootstrap-local: assume-admin
	@$(ROOT)/scripts/localstack/bootstrap.sh

deploy-dev:
	@$(ROOT)/scripts/localstack/deploy-kind.sh

undeploy-dev:
	helm uninstall step-ca -n step-ca || true
	kubectl delete namespace step-ca --ignore-not-found

test-k8ssa:
	@bash $(ROOT)/test/run-suite.sh k8ssa

test-external:
	@bash $(ROOT)/test/run-suite.sh external

test: test-k8ssa test-external
