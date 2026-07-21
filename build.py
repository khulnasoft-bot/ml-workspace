import argparse
import datetime
import os
import subprocess

import docker
from ml_buildkit import build_utils
from ml_buildkit.helpers import build_docker

REMOTE_IMAGE_PREFIX = "khulnasoft/"
COMPONENT_NAME = "ml-workspace"
FLAG_FLAVOR = "flavor"
FLAG_BUILDX = "buildx"
FLAG_CACHE_FROM = "cache-from"
FLAG_CACHE_TO = "cache-to"

parser = argparse.ArgumentParser(add_help=False)
parser.add_argument(
    "--" + FLAG_FLAVOR,
    help="Flavor (full, light, minimal, gpu) used for docker container",
    default="all",
)
parser.add_argument(
    "--" + FLAG_BUILDX,
    help="Use docker buildx for building with BuildKit",
    action="store_true",
    default=False,
)
parser.add_argument(
    "--" + FLAG_CACHE_FROM,
    help="Cache source for buildx (e.g., registry cache)",
    default="",
)
parser.add_argument(
    "--" + FLAG_CACHE_TO,
    help="Cache destination for buildx (e.g., registry cache)",
    default="",
)

args = build_utils.parse_arguments(argument_parser=parser)

VERSION = str(args.get(build_utils.FLAG_VERSION))
docker_image_prefix = args.get(build_docker.FLAG_DOCKER_IMAGE_PREFIX)

if not docker_image_prefix:
    docker_image_prefix = REMOTE_IMAGE_PREFIX


def _remove_existing_container(client, name):
    try:
        existing = client.containers.get(name)
        existing.remove(force=True)
    except docker.errors.NotFound:
        pass


if not args.get(FLAG_FLAVOR):
    args[FLAG_FLAVOR] = "all"

flavor = str(args[FLAG_FLAVOR]).lower().strip()

if flavor == "all":
    args[FLAG_FLAVOR] = "minimal"
    build_utils.build(".", args)

    args[FLAG_FLAVOR] = "light"
    build_utils.build(".", args)

    args[FLAG_FLAVOR] = "full"
    build_utils.build(".", args)

    args[FLAG_FLAVOR] = "gpu"
    build_utils.build("gpu-flavor", args)

    build_utils.exit_process(0)

# unknown flavor -> try to build from subdirectory
if flavor not in ["full", "minimal", "light"]:
    # assume that flavor has its own directory with build.py
    build_utils.build(flavor + "-flavor", args)
    build_utils.exit_process(0)

docker_image_name = COMPONENT_NAME
# Build full image without suffix if the flavor is not minimal or light
if flavor in ["minimal", "light"]:
    docker_image_name += "-" + flavor

# docker build
git_rev = "unknown"
try:
    git_rev = (
        subprocess.check_output(["git", "rev-parse", "--short", "HEAD"])
        .decode("ascii")
        .strip()
    )
except Exception:
    pass

build_date = datetime.datetime.utcnow().isoformat("T") + "Z"
try:
    build_date = (
        subprocess.check_output(["date", "-u", "+%Y-%m-%dT%H:%M:%SZ"])
        .decode("ascii")
        .strip()
    )
except Exception:
    pass

vcs_ref_build_arg = " --build-arg ARG_VCS_REF=" + str(git_rev)
build_date_build_arg = " --build-arg ARG_BUILD_DATE=" + str(build_date)
flavor_build_arg = " --build-arg ARG_WORKSPACE_FLAVOR=" + str(flavor)
version_build_arg = " --build-arg ARG_WORKSPACE_VERSION=" + VERSION

def _build_with_buildx(docker_image_name, build_args, dockerfile_path=".", flavor="full"):
    """Build using docker buildx with BuildKit and cache support."""
    buildx_args = [
        "docker", "buildx", "build",
        "--progress=plain",
        "--load",
    ]
    
    if args.get(FLAG_CACHE_FROM):
        buildx_args.extend(["--cache-from", f"type=registry,ref={args[FLAG_CACHE_FROM]}"])
    
    if args.get(FLAG_CACHE_TO):
        buildx_args.extend(["--cache-to", f"type=registry,ref={args[FLAG_CACHE_TO]},mode=max"])
    
    buildx_args.extend(["-t", f"{docker_image_name}:{VERSION}"])
    
    if flavor in ["minimal", "light"]:
        buildx_args.extend(["--build-arg", f"ARG_WORKSPACE_FLAVOR={flavor}"])
    
    buildx_args.extend(build_args.split())
    buildx_args.append(dockerfile_path)
    
    env = os.environ.copy()
    env["DOCKER_BUILDKIT"] = "1"
    
    completed_process = subprocess.run(buildx_args, env=env)
    return completed_process


if args[build_utils.FLAG_MAKE]:
    build_args = (
        version_build_arg
        + " "
        + flavor_build_arg
        + " "
        + vcs_ref_build_arg
        + " "
        + build_date_build_arg
    )
    
    dockerfile_path = "."
    if flavor == "gpu":
        dockerfile_path = "gpu-flavor"
    
    if args.get(FLAG_BUILDX):
        completed_process = _build_with_buildx(docker_image_name, build_args, dockerfile_path, flavor)
    else:
        completed_process = build_docker.build_docker_image(
            docker_image_name, version=VERSION, build_args=build_args
        )
    
    if completed_process.returncode > 0:
        build_utils.exit_process(1)

if args[build_utils.FLAG_TEST]:
    workspace_name = f"workspace-test-{flavor}"
    workspace_port = "8080"
    client = docker.from_env()
    _remove_existing_container(client, workspace_name)
    container = None
    completed_process = None
    try:
        container = client.containers.run(
            f"{docker_image_name}:{VERSION}",
            name=workspace_name,
            environment={
                "WORKSPACE_NAME": workspace_name,
                "WORKSPACE_ACCESS_PORT": workspace_port,
            },
            detach=True,
        )
        container.reload()
        container_ip = container.attrs["NetworkSettings"]["Networks"]["bridge"]["IPAddress"]
        completed_process = build_utils.run(
            f"docker exec --env WORKSPACE_IP={container_ip} {workspace_name} pytest '/resources/tests'",
            exit_on_error=False,
        )
    finally:
        if container is not None:
            container.remove(force=True)

    if completed_process is not None and completed_process.returncode > 0:
        build_utils.exit_process(1)

if args[build_utils.FLAG_RELEASE]:
    # Bump all versions in some filess
    previous_version = build_utils.get_latest_version()
    if previous_version:
        build_utils.replace_in_files(
            previous_version,
            VERSION,
            file_paths=["./README.md", "./deployment/google-cloud-run/Dockerfile"],
            regex=False,
            exit_on_error=True,
        )

    build_docker.release_docker_image(
        docker_image_name,
        VERSION,
        docker_image_prefix,
    )
