#!/bin/bash

#
# © 2024 Cloud Software Group, Inc.
# All Rights Reserved. Confidential & Proprietary.
#

# your ECR read-only token
if [[ -z ${ECR_TOKEN} ]]; then
  echo "ECR_TOKEN is not set"
  exit 1
fi

if [[ -z ${ECR_REPO} ]]; then
  echo "ECR_REPO is not set"
  exit 1
fi

# current GUI only support tekton 0.41.2
export TEKTON_PIPELINE_RELEASE="v0.41.2"
kubectl apply -f https://storage.googleapis.com/tekton-releases/pipeline/previous/${TEKTON_PIPELINE_RELEASE}/release.yaml

kubectl create namespace tekton-tasks

echo "sleep 30 seconds to wait for tekton to be ready"
sleep 30

# create service account for this pipeline
kubectl create -n tekton-tasks serviceaccount pipeline-cluster-admin
kubectl create clusterrolebinding pipeline-cluster-admin --clusterrole=cluster-admin --serviceaccount=tekton-tasks:pipeline-cluster-admin

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

# install provisioner config
helm upgrade --install -n ${PIPLINE_NAMESPACE} provisioner-config-local provisioner-config-local \
  --version ^1.0.0 --repo ${PLATFORM_PROVISIONER_PIPLINE_REPO}

K8S_REGISTRY_TOKEN=$(kubectl create secret docker-registry ecr \
  --docker-server="${ECR_REPO}" \
  --docker-username=AWS \
  --docker-password="${ECR_TOKEN}" \
  --dry-run=client -o yaml | yq '.data[".dockerconfigjson"]')

# install provisioner web ui
helm upgrade --install -n ${PIPLINE_NAMESPACE} platform-provisioner-ui platform-provisioner-ui --repo ${PLATFORM_PROVISIONER_PIPLINE_REPO} \
  --version ^1.0.0 \
  --set image.repository=${ECR_REPO}/stratosphere/cic2-provisioner-webui \
  --set image.tag=latest \
  --set imagePullSecrets[0].name=platform-provisioner-ui-image-pull \
  --set imagePullSecret.create=true \
  --set imagePullSecret.secret="${K8S_REGISTRY_TOKEN}" \
  --set guiConfig.onPremMode=true \
  --set guiConfig.pipelinesCleanUpEnabled=true \
  --set guiConfig.dataConfigMapName="provisioner-config-local-config"
