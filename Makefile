# Makefile for ML Workspace Docker builds
# Usage: make [target] [FLAVOR=full] [VERSION=0.0.1] [BUILDX=true] [CACHE_FROM=...] [CACHE_TO=...]

.PHONY: help build build-all test push release clean

# Default values
FLAVOR ?= full
VERSION ?= 0.0.1-dev
BUILDX ?= false
CACHE_FROM ?=
CACHE_TO ?=
DOCKER_IMAGE_PREFIX ?= khulnasoft/

# Build arguments
BUILD_ARGS = --version $(VERSION) --flavor $(FLAVOR)
ifeq ($(BUILDX),true)
    BUILD_ARGS += --buildx
    ifneq ($(CACHE_FROM),)
        BUILD_ARGS += --cache-from $(CACHE_FROM)
    endif
    ifneq ($(CACHE_TO),)
        BUILD_ARGS += --cache-to $(CACHE_TO)
    endif
endif

help:
	@echo "ML Workspace Build Targets"
	@echo ""
	@echo "Build targets:"
	@echo "  make build              - Build single flavor (default: full)"
	@echo "  make build-minimal      - Build minimal flavor"
	@echo "  make build-light        - Build light flavor"
	@echo "  make build-full         - Build full flavor"
	@echo "  make build-gpu          - Build GPU flavor"
	@echo "  make build-all          - Build all flavors"
	@echo ""
	@echo "Test targets:"
	@echo "  make test               - Test single flavor"
	@echo "  make test-all           - Test all flavors"
	@echo ""
	@echo "Release targets:"
	@echo "  make push               - Push single flavor"
	@echo "  make push-all           - Push all flavors"
	@echo "  make release            - Create release (bump versions, tag, push)"
	@echo ""
	@echo "Utility targets:"
	@echo "  make clean              - Clean build artifacts"
	@echo "  make lint               - Lint Dockerfiles"
	@echo ""
	@echo "Variables:"
	@echo "  FLAVOR=full|minimal|light|gpu  (default: full)"
	@echo "  VERSION=0.0.1                (default: 0.0.1-dev)"
	@echo "  BUILDX=true|false            (default: false)"
	@echo "  CACHE_FROM=registry/cache    (for buildx cache)"
	@echo "  CACHE_TO=registry/cache      (for buildx cache)"
	@echo ""
	@echo "Examples:"
	@echo "  make build FLAVOR=full VERSION=1.0.0"
	@echo "  make build BUILDX=true CACHE_FROM=ghcr.io/org/cache CACHE_TO=ghcr.io/org/cache"
	@echo "  make build-all VERSION=1.0.0 BUILDX=true"

build:
	python3 build.py --make $(BUILD_ARGS)

build-minimal:
	python3 build.py --flavor minimal --make $(BUILD_ARGS)

build-light:
	python3 build.py --flavor light --make $(BUILD_ARGS)

build-full:
	python3 build.py --flavor full --make $(BUILD_ARGS)

build-gpu:
	python3 build.py --flavor gpu --make $(BUILD_ARGS)

build-all:
	python3 build.py --flavor all --version $(VERSION) $(if $(filter true,$(BUILDX)),--buildx,) $(if $(CACHE_FROM),--cache-from $(CACHE_FROM),) $(if $(CACHE_TO),--cache-to $(CACHE_TO),) --make

test:
	python3 build.py --flavor $(FLAVOR) --version $(VERSION) --test

test-all:
	python3 build.py --flavor all --version $(VERSION) --test

push:
	python3 build.py --flavor $(FLAVOR) --version $(VERSION) --release

push-all:
	python3 build.py --flavor all --version $(VERSION) --release

release:
	python3 build.py --flavor all --version $(VERSION) --release

clean:
	docker system prune -f
	docker builder prune -f

lint:
	docker run --rm -i hadolint/hadolint < Dockerfile
	docker run --rm -i hadolint/hadolint < gpu-flavor/Dockerfile

# Development shortcuts
dev-build:
	DOCKER_BUILDKIT=1 docker build --target conda-bootstrap -t ml-workspace:conda-base .

dev-build-full:
	DOCKER_BUILDKIT=1 docker build -t ml-workspace:dev .

dev-build-gpu:
	DOCKER_BUILDKIT=1 docker build -f gpu-flavor/Dockerfile -t ml-workspace:gpu-dev .

# CI/CD targets
ci-build:
	$(MAKE) build-all VERSION=0.0.1-$(shell git rev-parse --short HEAD) BUILDX=true CACHE_FROM=ghcr.io/khulnasoft/ml-workspace-cache CACHE_TO=ghcr.io/khulnasoft/ml-workspace-cache

ci-test:
	$(MAKE) test-all VERSION=$(shell git describe --tags --always)

ci-push:
	$(MAKE) push-all VERSION=$(shell git describe --tags --always)

# Print effective build command
print-build-cmd:
	@echo "python3 build.py --make $(BUILD_ARGS)"