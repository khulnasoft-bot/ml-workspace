# Docker Build Performance Improvements - Summary

## Changes Made

### 1. BuildKit & Buildx Support (`build.py`)
- Added `--buildx` flag to enable Docker BuildKit builds
- Added `--cache-from` and `--cache-to` flags for registry cache support
- New `_build_with_buildx()` function handles cache mounts and buildx arguments
- Usage: `python build.py --flavor full --version 0.0.1 --buildx --cache-from ghcr.io/org/cache --cache-to ghcr.io/org/cache --make`

### 2. Main Dockerfile Optimizations (`Dockerfile`)
- **BuildKit syntax**: Added `# syntax = docker/dockerfile:1.4` header
- **Multi-stage build**: Separated conda bootstrap into its own stage
- **Cache mounts**: Added `--mount=type=cache` for:
  - `/var/cache/apt`, `/var/lib/apt/lists` (apt cache)
  - `/root/.cache/pip` (pip cache)
  - `/opt/conda/pkgs` (conda package cache)
  - `/tmp`, `/var/tmp` (temp directories)
  - `/root/.npm`, `/root/.node-gyp` (npm cache)
- **Dependency layering**: Copy requirements files BEFORE installing packages:
  - `requirements-base.txt` (stable, rarely changing)
  - `requirements-dev.txt` (dev tools, frequently changing)
  - `requirements-minimal.txt`, `requirements-light.txt`, `requirements-full.txt`
- **Optimized layer ordering**: Install stable dependencies first for better cache hits

### 3. Requirements Split (`resources/libraries/`)
- **requirements-base.txt**: Core stable dependencies (requests, urllib3, PyYAML, click, tqdm, etc.)
- **requirements-dev.txt**: Development tools (pytest, black, mypy, py-spy, etc.)
- **requirements-minimal.txt**: Unchanged (minimal flavor)
- **requirements-light.txt**: Unchanged (light flavor)
- **requirements-full.txt**: Unchanged (full flavor)

### 4. Clean Layer Script (`resources/scripts/clean-layer.sh`)
- Improved error handling with `command -v` instead of `which`
- Better permission handling
- More robust cleanup

### 5. GPU Dockerfile (`gpu-flavor/Dockerfile`)
- **Base image**: Changed from manual CUDA install to `nvidia/cuda:11.2.2-cudnn8-devel-ubuntu20.04`
- **Eliminated manual CUDA/cuDNN installation** (saves ~5-10 min per build)
- **BuildKit cache mounts** for pip, conda, apt caches
- **Pre-configured NVIDIA runtime** environment variables

## Expected Performance Improvements

| Optimization | Expected Impact |
|-------------|----------------|
| BuildKit cache mounts | 30-50% faster rebuilds |
| Dependency layering (requirements split) | 50-70% faster incremental builds |
| NVIDIA base image (GPU) | 5-10 min faster GPU builds |
| Registry cache (buildx) | Near-instant CI rebuilds |

## Usage Examples

### Local Development Build (with BuildKit)
```bash
DOCKER_BUILDKIT=1 docker build -t ml-workspace:dev .
```

### Using Build Script with Cache
```bash
python build.py --flavor full --version 0.0.1 --buildx --cache-from ghcr.io/khulnasoft/ml-workspace-cache --cache-to ghcr.io/khulnasoft/ml-workspace-cache --make
```

### GPU Flavor Build
```bash
python build.py --flavor gpu --version 0.0.1 --buildx --make
```

### CI/CD with Persistent Cache
```yaml
# GitHub Actions example
- name: Build with cache
  run: |
    docker buildx create --use --name mlbuilder
    python build.py --flavor full --version ${{ github.sha }} \
      --buildx \
      --cache-from ghcr.io/${{ github.repository }}/cache \
      --cache-to ghcr.io/${{ github.repository }}/cache,mode=max \
      --make
```

## Verification

To verify improvements:
1. Run initial build: `python build.py --flavor full --version test --buildx --make`
2. Make small change to source code
3. Rebuild: `python build.py --flavor full --version test --buildx --make`
4. Compare build times - should be significantly faster due to cached layers

## Files Modified
- `build.py` - Added buildx and cache support
- `Dockerfile` - BuildKit syntax, cache mounts, dependency layering, multi-stage
- `gpu-flavor/Dockerfile` - NVIDIA base image, cache mounts
- `resources/scripts/clean-layer.sh` - Improved cleanup
- `resources/libraries/requirements-base.txt` - New (stable deps)
- `resources/libraries/requirements-dev.txt` - New (dev tools)