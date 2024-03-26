<!-- TOC -->
* [Platform Provisioner](#platform-provisioner)
  * [Get recipes from TIBCO GitHub](#get-recipes-from-tibco-github)
  * [Run the platform-provisioner in headless mode with docker container](#run-the-platform-provisioner-in-headless-mode-with-docker-container)
    * [Prerequisite](#prerequisite)
    * [Run the platform-provisioner in headless mode](#run-the-platform-provisioner-in-headless-mode)
  * [Run the platform-provisioner in headless mode with tekton pipeline](#run-the-platform-provisioner-in-headless-mode-with-tekton-pipeline)
    * [Prerequisite](#prerequisite-1)
      * [1. install tekton](#1-install-tekton)
      * [2. install pipeline](#2-install-pipeline)
    * [Run the platform-provisioner in headless mode](#run-the-platform-provisioner-in-headless-mode-1)
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

## Run the platform-provisioner in headless mode with docker container

The platform-provisioner can be run in headless mode with docker container. The docker container contains all the necessary tools to run the pipeline scripts.
The `platform-provisioner.sh` script will create a docker container and run the pipeline scripts with the given recipe.

### Prerequisite

* Docker installed
* Bash shell

### Run the platform-provisioner in headless mode

Go to the directory where you save the recipe and run the following command
```bash
export PIPELINE_INPUT_RECIPE="<path to recipe>"

source <(curl -s https://raw.githubusercontent.com/syan-tibco/platform-provisioner/main/dev/platform-provisioner.sh)
```

> [!Note]
> By default, the script will download the latest docker image from dockerhub.
> We have a pre-built docker image at [dockerhub](https://hub.docker.com/repository/docker/syantibco/platform-provisioner/general).

## Run the platform-provisioner in headless mode with tekton pipeline

The platform-provisioner can be run in headless mode with tekton installed in the target Kubernetes cluster. 
In this case the recipe and pipeline will be schedualed by tekton and run in the target Kubernetes cluster.

### Prerequisite

#### 1. install tekton
```
# current GUI only support tekton 0.41.2
export TEKTON_PIPELINE_RELEASE="v0.41.2"
kubectl apply -f https://storage.googleapis.com/tekton-releases/pipeline/previous/${TEKTON_PIPELINE_RELEASE}/release.yaml
```

#### 2. install pipeline
* create a service account for pipelines to run
```bash
kubectl create namespace tekton-tasks
# create service account for this pipeline
kubectl create -n tekton-tasks serviceaccount pipeline-cluster-admin
kubectl create clusterrolebinding pipeline-cluster-admin --clusterrole=cluster-admin --serviceaccount=tekton-tasks:pipeline-cluster-admin
```

* you can install open-sourced pipelines
```bash
export PLATFORM_PROVISIONER_PIPLINE_REPO="https://syan-tibco.github.io/platform-provisioner"
export PIPLINE_NAMESPACE="tekton-tasks"

# install a sample pipeline with docker image that can run locally
helm upgrade --install -n ${PIPLINE_NAMESPACE} common-dependency common-dependency \
  --version ^1.0.0 --repo ${PLATFORM_PROVISIONER_PIPLINE_REPO}

helm upgrade --install -n ${PIPLINE_NAMESPACE} generic-runner generic-runner \
  --version ^1.0.0 --repo ${PLATFORM_PROVISIONER_PIPLINE_REPO} \
  --set serviceAccount=pipeline-cluster-admin \
  --set pipelineImage=syantibco/platform-provisioner:latest

helm upgrade --install -n ${PIPLINE_NAMESPACE} helm-install helm-install \
  --version ^1.0.0 --repo ${PLATFORM_PROVISIONER_PIPLINE_REPO} \
  --set serviceAccount=pipeline-cluster-admin \
  --set pipelineImage=syantibco/platform-provisioner:latest
```

### Run the platform-provisioner in headless mode

Go to the directory where you save the recipe and run the following command
```bash
export PIPELINE_INPUT_RECIPE="<path to recipe>"

source <(curl -s https://raw.githubusercontent.com/syan-tibco/platform-provisioner/main/dev/platform-provisioner-pipelinerun.sh)
```

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

