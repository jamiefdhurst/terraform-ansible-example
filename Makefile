PWD := $(shell echo `pwd`)
SSH_PRIVATE_KEY := $(shell readlink ~/.ssh/id_rsa)
SSH_PUBLIC_KEY := $(shell cat ~/.ssh/id_rsa.pub)
DOCKER_MAIN := docker run -v $(PWD):/data -e TF_VAR_SSH_PUBLIC_KEY="$(SSH_PUBLIC_KEY)" -e AWS_ACCESS_KEY_ID=$(AWS_ACCESS_KEY_ID) -e AWS_SECRET_ACCESS_KEY=$(AWS_SECRET_ACCESS_KEY)
DOCKER_SH_ENTRYPOINT := --entrypoint /bin/sh
DOCKER_BASE := $(DOCKER_MAIN) -it infrastructure
DOCKER_BASE_CUSTOM := $(DOCKER_MAIN) $(DOCKER_SH_ENTRYPOINT) -it infrastructure -c

## build: build the container image to be used in all commands
build:
	@cp ~/.ssh/id_rsa id_rsa
	@docker build -t infrastructure .
	@rm id_rsa

## init: initialise terraform - must be run before any subsequent commands
init:
	@$(DOCKER_BASE) init

## plan: show output of state to be changed
plan:
	@$(DOCKER_BASE) plan

## apply: apply changes to remote files
apply:
	@$(DOCKER_BASE) apply

## destroy: tear down all infrastructure
destroy:
	@$(DOCKER_BASE) destroy

## debug: enter a shell with access to terraform and ansible
debug:
	@$(DOCKER_MAIN) $(DOCKER_SH_ENTRYPOINT) -it infrastructure

## create-state: create remote state in AWS environment
create-state:
	@$(DOCKER_BASE_CUSTOM) "cd state && terraform init && terraform apply"

## destroy-state: destroy remote state in AWS environment
destroy-state:
	@$(DOCKER_BASE_CUSTOM) "cd state && terraform init && terraform destroy"

.PHONY: help
all: help
help: Makefile
	@echo
	@echo " Choose a command to run:"
	@echo
	@sed -n 's/^##//p' $< | column -t -s ':' |  sed -e 's/^/ /'
	@echo