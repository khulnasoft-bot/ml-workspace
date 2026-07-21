.PHONY: help deps build build-all build-full build-light build-minimal build-gpu check test verify release clean

PYTHON ?= python3
BUILD_PY := $(CURDIR)/build.py
PIP_INSTALL := $(PYTHON) -m pip install -r build_requirements.txt

help:
	@echo "Available targets:"
	@echo "  make help          Show this help message."
	@echo "  make build         Build the default workspace image."
	@echo "  make build-all     Build all workspace flavors (minimal, light, full, gpu)."
	@echo "  make build-full    Build the full workspace image."
	@echo "  make build-light   Build the light workspace image."
	@echo "  make build-minimal Build the minimal workspace image."
	@echo "  make build-gpu     Build the GPU workspace image."
	@echo "  make check         Run lint/style checks."
	@echo "  make test          Run workspace integration tests."
	@echo "  make verify        Run check, build, and test."
	@echo "  make release       Build and release artifacts."
	@echo "  make clean         No-op placeholder for cleanup tasks."

deps: ## Install Python build dependencies.
	$(PIP_INSTALL)

build: deps ## Build the default workspace image (all flavors by default).
	$(PYTHON) $(BUILD_PY) --make

build-all: deps ## Build all workspace flavors (minimal, light, full, gpu).
	$(PYTHON) $(BUILD_PY) --make --flavor=all

build-full: ## Build the full workspace image.
	$(PYTHON) $(BUILD_PY) --make --flavor=full

build-light: ## Build the light workspace image.
	$(PYTHON) $(BUILD_PY) --make --flavor=light

build-minimal: ## Build the minimal workspace image.
	$(PYTHON) $(BUILD_PY) --make --flavor=minimal

build-gpu: ## Build the GPU workspace image.
	$(PYTHON) $(BUILD_PY) --make --flavor=gpu

check: ## Run linting and style checks via build.py.
	$(PYTHON) $(BUILD_PY) --check

test: ## Run integration tests via build.py.
	$(PYTHON) $(BUILD_PY) --test

verify: check build test ## Run all verification targets.
	@echo "Verification completed."

release: ## Build and release artifacts via build.py.
	$(PYTHON) $(BUILD_PY) --release

clean: ## No-op cleanup placeholder.
	@echo "Nothing to clean in this repository."
