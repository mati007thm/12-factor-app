#!/bin/bash
# https://www.opencost.io/docs/configuration/aws

set -e

# Sets up variables for the cluster name, region, namespace and account ID.
CLUSTER_NAME=loadgen-test
REGION=eu-central-1

kubectl apply -f https://raw.githubusercontent.com/kubernetes/ingress-nginx/controller-v1.11.1/deploy/static/provider/aws/deploy.yaml

# Updates the kubeconfig for the specified EKS cluster.
aws eks --region $REGION update-kubeconfig --name $CLUSTER_NAME

oidc_id=$(aws eks describe-cluster --name $CLUSTER_NAME --query "cluster.identity.oidc.issuer" --output text | cut -d '/' -f 5)
echo $oidc_id
aws iam list-open-id-connect-providers | grep $oidc_id | cut -d "/" -
eksctl utils associate-iam-oidc-provider --cluster $CLUSTER_NAME --approve
