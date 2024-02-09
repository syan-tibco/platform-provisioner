#!/bin/bash

#
# © 2024 Cloud Software Group, Inc.
# All Rights Reserved. Confidential & Proprietary.
#

#######################################
# build.sh this will docker image for platform-provisioner
# Globals:
#   IMAGE_TAG: tag to use for the image. If not specified, latest will be used
#   DOCKER_REGISTRY: docker registry to push the image to. If not specified, image will be built locally
#   PUSH_DOCKER_IMAGE: if true, image will be pushed to DOCKER_REGISTRY
#   PLATFORM: platform to build the image for. If not specified, linux/amd64,linux/arm64 will be used for multiarch build, linux/amd64 for local build
#   BUILD_ARGS: build args to pass to docker build
# Arguments:
#   None
# Returns:
#   0 if thing was deleted, non-zero on error
# Notes:
#   None
# Samples:
#   ./build.sh
#######################################

# build-push-multiarch build and push multiarch image
function build-push-multiarch() {
  local _platforms=$1
  local _image_name=$2
  local _dockerfile=$3
  local _build_args=$4
  # create a build to use docker-container driver
  local _builder="multiarch-linux"
  if ! docker buildx create --name ${_builder} --driver docker-container; then
    echo "Failed to create builder ${_builder}"
    return 1
  fi
  # add build and push flags
  _build_args="${_build_args} --builder=${_builder}"
  _build_args="${_build_args} --push"
  # shellcheck disable=SC2086
  # we have to disable SC2086 because we want to pass the build args one by one
  if ! docker buildx build --platform="${_platforms}" --progress=plain \
    ${_build_args} \
    -t "${_image_name}" -f "${_dockerfile}" .; then
    echo "Failed to build image ${_image_name}"
    if ! docker buildx rm ${_builder}; then
      echo "Failed to remove builder ${_builder}"
      return 1
    fi
    return 1
  fi

  if ! docker buildx rm ${_builder}; then
    echo "Failed to remove builder ${_builder}"
    return 1
  fi
}

# build-local build image locally
function build-local() {
  local _platform=$1
  local _image_name=$2
  local _dockerfile=$3
  local _build_args=$4
  # shellcheck disable=SC2086
  # we have to disable SC2086 because we want to pass the build args one by one
  if ! docker buildx build --platform=${_platform} --progress=plain \
    ${_build_args} \
    -t "${_image_name}" --load -f "${_dockerfile}" .; then
    echo "Failed to build image ${_image_name}"
    return 1
  fi
}

# main
function main() {
  IMAGE_TAG=${IMAGE_TAG:-"latest"}
  IMAGE_NAME="platform-provisioner:${IMAGE_TAG}"
  DOCKERFILE="Dockerfile"
  BUILD_ARGS=${BUILD_ARGS:-"--build-arg AWS_CLI_VERSION=${AWS_CLI_VERSION} --build-arg EKSCTL_VERSION=${EKSCTL_VERSION}"}

  if [[ "${DOCKER_REGISTRY}" != "" ]]; then
    IMAGE_NAME="${DOCKER_REGISTRY}/${IMAGE_NAME}"
  fi

  if [[ "${PUSH_DOCKER_IMAGE}" == "true" ]] && [[ "${DOCKER_REGISTRY}" != "" ]]; then
    # more infor about platform flag: https://docs.docker.com/engine/reference/commandline/buildx_build/#platform
    PLATFORM=${PLATFORM:-"linux/amd64,linux/arm64"}
    echo "Building and pushing to ${DOCKER_REGISTRY}/${IMAGE_NAME}"
    if ! build-push-multiarch "${PLATFORM}" "${IMAGE_NAME}" "${DOCKERFILE}" "${BUILD_ARGS}"; then
      echo "Failed to build and push image ${IMAGE_NAME}"
      return 1
    fi
  else
    if [[ -z "${PLATFORM}" ]]; then
      machine=$(uname -m)
      if [[ "${machine}" == "x86_64" ]]; then
        PLATFORM="linux/amd64"
      else
        # including armv7l (pi), aarch64 (mac m processor)
        PLATFORM="linux/arm64"
      fi
    fi
    echo "Building locally for ${PLATFORM}"
    if ! build-local "${PLATFORM}" "${IMAGE_NAME}" "${DOCKERFILE}" "${BUILD_ARGS}"; then
      echo "Failed to build image ${IMAGE_NAME}"
      return 1
    fi
  fi
}

if ! main; then
  echo "Failed to build image"
  exit 1
fi
