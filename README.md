<!-- TOC -->
* [Platform Provisioner](#platform-provisioner)
  * [Get recipes from TIBCO GitHub](#get-recipes-from-tibco-github)
  * [Run the platform-provisioner in headless mode](#run-the-platform-provisioner-in-headless-mode)
    * [Prerequisite](#prerequisite)
  * [Docker image for Platform Provisioner](#docker-image-for-platform-provisioner)
<!-- TOC -->

# Platform Provisioner

Platform Provisioner is a system that can provision a platform on any cloud provider (AWS, Azure) or on-prem. It consists of the following components:
* A runtime Docker image: The docker image that contains all the supporting tools to run a pipeline with given recipe.
* Pipelines: The script that can run inside the docker image to parse and run the recipe. Normally, the pipelines encapsulate as a helm chart.
* Recipes: contains all the information to provision a platform.
* Platform Provisioner GUI: The GUI that is used to manage the recipes, pipelines, and runtime backend system. (docker for on-prem, tekton for Kubernetes)

## Get recipes from TIBCO GitHub

This repo provides some recipes to test the pipeline and cloud connection. It is located under [recipes](recipes) folder.

For TIBCO Platform recipes, please see [TIBCO GitHub](https://github.com/tibco/cicinfra-devops/tree/main/recipes/cp-platform-dev/DataPlane/environments).

## Run the platform-provisioner in headless mode

### Prerequisite

* Docker installed
* Bash shell

Go to the directory where you save the recipe and run the following command
```bash
export PIPELINE_INPUT_RECIPE="<path to recipe>"

source <(curl -s https://raw.githubusercontent.com/syan-tibco/platform-provisioner/main/dev/platform-provisioner.sh)
```

> [!Note]
> By default, the script will download the latest docker image from dockerhub.
> We have a pre-built docker image at [dockerhub](https://hub.docker.com/repository/docker/syantibco/platform-provisioner/general).

## Docker image for Platform Provisioner

We provide a Dockerfile to build the docker image. The docker image is used to run the pipeline. It contains the necessary tools to run the pipeline scripts.

<details>
<summary>Steps to build docker image</summary>
To build docker image locally, run the following command:

```bash
cd docker
./build.sh
```

This will build the docker image called `platform-provisioner:latest`.

To build multi-arch docker image and push to remote docker registry, run the following command:

```bash
export DOCKER_REGISTRY="<your docker registry repo>"
export PUSH_DOCKER_IMAGE=true
cd docker
./build.sh
```
This will build the docker image called `<your docker registry repo>/platform-provisioner:latest` and push to remote docker registry.

</details>

> [!Note]
> For other options, please see [docker/build.sh](docker/build.sh).

