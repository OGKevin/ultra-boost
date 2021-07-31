# This make file is inspired by: https://github.com/talos-systems/talos/blob/5f027615ffac68e0a484a5da4827a6589bae3880/Makefile
# However, I do understand how it works, so it's not a blind copy paste + modifications.
# There could be targets left that do not work that I forgot to remove. E.f. Lint and Fmt targets. I've removed those
# as these are nice to haves and requires some setup. I deemed that out of the scope of this assignment.

# tl;dr
# make --> test and build
# make ultra-boost --> build the image in build cache
# make local-ultra-boost --> build the image locally and load it into local docker registry
# make unit-tests --> run test, modify main_test.go to mimic a test failure.


REGISTRY ?= ghcr.io
USERNAME ?= ogkevin
SHA ?= $(shell git describe --match=none --always --abbrev=8 --dirty)
TAG ?= $(shell git describe --tag --always --dirty)
IMAGE_REGISTRY ?= $(REGISTRY)
IMAGE_TAG ?= $(TAG)
BRANCH ?= $(shell git rev-parse --abbrev-ref HEAD)
REGISTRY_AND_USERNAME := $(IMAGE_REGISTRY)/$(USERNAME)
DOCKER_LOGIN_ENABLED ?= true
NAME = ultra-boost
DEST = /tmp

VERSION_PKG = github.com/OGKevin/ogkevin/pkg/version

CGO_ENABLED ?= 0
GO_BUILDFLAGS ?=
GO_LDFLAGS ?= \
	-X $(VERSION_PKG).Name=$(NAME) \
	-X $(VERSION_PKG).SHA=$(SHA) \
	-X $(VERSION_PKG).Tag=$(TAG) \
	-extldflags "-static"

GO_VERSION="1.16"
GOFUMPT_VERSION="v0.1.1"

space := $(subst ,, )
BUILD := docker buildx build
BUILD_LOCAL := docker build
PLATFORM ?= linux/amd64
PLATFORM_RELEASE ?= linux/amd64,linux/arm64
PROGRESS ?= auto
PUSH ?= false
COMMON_ARGS := --file=Dockerfile
COMMON_ARGS += --progress=$(PROGRESS)
COMMON_ARGS += --platform=$(PLATFORM)
COMMON_ARGS += --push=$(PUSH)
COMMON_ARGS += --build-arg=TAG=$(TAG)
COMMON_ARGS += --build-arg=CGO_ENABLED=$(CGO_ENABLED)
COMMON_ARGS += --build-arg=GO_BUILDFLAGS="$(GO_BUILDFLAGS)"
COMMON_ARGS += --build-arg=GO_LDFLAGS="$(GO_LDFLAGS)"

CI_ARGS ?=

all: unit-tests ultra-boost

# Help Menu

define HELP_MENU_HEADER
# Getting Started

To build this project, you must have the following installed:

- git
- make
- docker (19.03 or higher)
- buildx (https://github.com/docker/buildx)

## Creating a Builder Instance

The build process makes use of features not currently supported by the default
builder instance (docker driver). To create a compatible builder instance, run:

```
docker buildx create --driver docker-container --name local --buildkitd-flags '--allow-insecure-entitlement security.insecure' --use
```

If you already have a compatible builder instance, you may use that instead.

> Note: The security.insecure entitlement is only required, and used by the unit-tests target and targets which build container images
for applications using `img` tool.

## Images

Images will be tagged with the
registry "$(IMAGE_REGISTRY)", username "$(USERNAME)", and a dynamic tag (e.g. $(REGISTRY_AND_USERNAME)/image:$(IMAGE_TAG)).
The registry and username can be overriden by exporting REGISTRY, and USERNAME
respectively.


endef

export HELP_MENU_HEADER

help: ## This help menu.
	@echo "$$HELP_MENU_HEADER"
	@grep -E '^[a-zA-Z0-9%_-]+:.*?## .*$$' $(MAKEFILE_LIST) | awk 'BEGIN {FS = ":.*?## "}; {printf "\033[36m%-30s\033[0m %s\n", $$1, $$2}'

# Build Abstractions

.PHONY:
target-%: ## Builds the specified target defined in the Dockerfile. The build result will only remain in the build cache.
	@$(BUILD) \
		--target=$* \
		$(COMMON_ARGS) \
		$(TARGET_ARGS) \
		$(CI_ARGS) .

local-target-%:
	@$(BUILD_LOCAL) \
		-t $(REGISTRY_AND_USERNAME)/$*:$(IMAGE_TAG) \
		--target=$* \
		.

local-%: ## Builds the specified target defined in the Dockerfile using the local output type. The build result will be output to the specified local destination.
	@$(MAKE) local-target-$*

docker-run-%:
	@$(MAKE) local-target-$*
	docker run --rm $(REGISTRY_AND_USERNAME)/$*:$(IMAGE_TAG)

registry-%: ## Builds the specified target defined in the Dockerfile using the image/registry output type. The build result will be pushed to the registry if PUSH=true.
	@$(MAKE) target-$* TARGET_ARGS="--output type=image,name=$(REGISTRY_AND_USERNAME)/$*:$(IMAGE_TAG) $(TARGET_ARGS)"


.PHONY: ultra-boost
ultra-boost: ## Builds the docker image for `ultra-boost` application. Images is loaded in build cache.
	@$(MAKE) registry-$@

# Code Quality
check-dirty: ## Verifies that source tree is not dirty
	@if test -n "`git status --porcelain`"; then echo "Source tree is dirty"; git status; exit 1 ; fi

# Tests

.PHONY: unit-tests
unit-tests: ## Performs unit tests.
	@$(MAKE) registry-$@ DEST=$(ARTIFACTS) TARGET_ARGS="--allow security.insecure" PLATFORM=linux/amd64

.PHONY: login
login: ## Logs in to the configured container registry.
ifeq ($(DOCKER_LOGIN_ENABLED), true)
	echo "$(GHCR_PASSWORD)" | docker login --username "$(USERNAME)" --password-stdin  $(IMAGE_REGISTRY)
endif

push: login ## Pushes the ultra-boost image to the configured container registry with the generated tag.
	@$(MAKE) ultra-boost PUSH=true

push-%: login ## Pushes the ultra-boost images to the configured container registry with the specified tag (e.g. push-latest).
	@$(MAKE) push IMAGE_TAG=$*

push-pr: login
	@$(MAKE) push IMAGE_TAG=pr-${DRONE_PULL_REQUEST}

KUSTOMIZE = $(shell pwd)/bin/kustomize
kustomize: ## Download kustomize locally if necessary.
	$(call go-get-tool,$(KUSTOMIZE),sigs.k8s.io/kustomize/kustomize/v3@v3.8.7)

build: ## Build ultra-boost binary.
	go build -o bin/ultra-boost main.go

run: build ## Run the ultra-boost binary locally
	bin/ultra-boost

manifest: kustomize ## Generates k8s manifests
	kustomize build kustomize > manifests/ultra-boost.yml

# go-get-tool will 'go get' any package $2 and install it to $1.
PROJECT_DIR := $(shell dirname $(abspath $(lastword $(MAKEFILE_LIST))))
define go-get-tool
@[ -f $(1) ] || { \
set -e ;\
TMP_DIR=$$(mktemp -d) ;\
cd $$TMP_DIR ;\
go mod init tmp ;\
echo "Downloading $(2)" ;\
GOBIN=$(PROJECT_DIR)/bin go get $(2) ;\
rm -rf $$TMP_DIR ;\
}
endef