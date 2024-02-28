#!/bin/bash

#
# © 2024 Cloud Software Group, Inc.
# All Rights Reserved. Confidential & Proprietary.
#

#######################################
# platform-provisioner-ui.sh: this will deploy platform-provisioner-ui and all supporting components
# Globals:
#   ECR_TOKEN: the read-only token for ECR to pull Platform Provisioner images
#   ECR_REPO: the ECR repo to pull Platform Provisioner images
#   PIPLINE_NAMESPACE: the namespace to deploy the pipeline and provisioner GUI
#   PLATFORM_PROVISIONER_PIPLINE_REPO: the repo to pull the pipeline and provisioner GUI helm charts
# Arguments:
#   None
# Returns:
#   0 if thing was deleted, non-zero on error
# Notes:
#   None
# Samples:
#    export ECR_TOKEN="your-ecr-token"
#    export ECR_REPO="your-ecr-repo"
#   ./platform-provisioner-ui.sh
#######################################

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

export PLATFORM_PROVISIONER_PIPLINE_REPO=${PLATFORM_PROVISIONER_PIPLINE_REPO:-"https://syan-tibco.github.io/platform-provisioner"}
export PIPLINE_NAMESPACE=${PIPLINE_NAMESPACE:-"tekton-tasks"}

# install a sample pipeline with docker image that can run locally
helm upgrade --install -n "${PIPLINE_NAMESPACE}" common-dependency common-dependency \
  --version ^1.0.0 --repo "${PLATFORM_PROVISIONER_PIPLINE_REPO}"

helm upgrade --install -n "${PIPLINE_NAMESPACE}" generic-runner generic-runner \
  --version ^1.0.0 --repo "${PLATFORM_PROVISIONER_PIPLINE_REPO}" \
  --set serviceAccount=pipeline-cluster-admin \
  --set pipelineImage=syantibco/platform-provisioner:latest

helm upgrade --install -n "${PIPLINE_NAMESPACE}" helm-install helm-install \
  --version ^1.0.0 --repo "${PLATFORM_PROVISIONER_PIPLINE_REPO}" \
  --set serviceAccount=pipeline-cluster-admin \
  --set pipelineImage=syantibco/platform-provisioner:latest

# install provisioner config
helm upgrade --install -n "${PIPLINE_NAMESPACE}" provisioner-config-local provisioner-config-local \
  --version ^1.0.0 --repo "${PLATFORM_PROVISIONER_PIPLINE_REPO}"

# create secret for pulling images from ECR
_image_pull_secret_name="platform-provisioner-ui-image-pull"
if kubectl get secret -n "${PIPLINE_NAMESPACE}" ${_image_pull_secret_name} > /dev/null 2>&1; then
  kubectl delete secret -n "${PIPLINE_NAMESPACE}" ${_image_pull_secret_name}
fi
kubectl create secret docker-registry -n "${PIPLINE_NAMESPACE}" ${_image_pull_secret_name} \
  --docker-server="${ECR_REPO}" \
  --docker-username=AWS \
  --docker-password="${ECR_TOKEN}"

# install provisioner web ui
helm upgrade --install -n "${PIPLINE_NAMESPACE}" platform-provisioner-ui platform-provisioner-ui --repo "${PLATFORM_PROVISIONER_PIPLINE_REPO}" \
  --version ^1.0.0 \
  --set image.repository="${ECR_REPO}"/stratosphere/cic2-provisioner-webui \
  --set image.tag=latest \
  --set imagePullSecrets[0].name=${_image_pull_secret_name} \
  --set guiConfig.onPremMode=true \
  --set guiConfig.pipelinesCleanUpEnabled=true \
  --set guiConfig.dataConfigMapName="provisioner-config-local-config"
