#!/bin/bash
set -e

# Sets up variables for the cluster name and region
CLUSTER_NAME=loadgen-test
REGION=eu-central-1

# Updates the kubeconfig for the specified EKS cluster.
aws eks --region $REGION update-kubeconfig --name $CLUSTER_NAME

# Installs the NGINX Ingress Controller for the specified EKS cluster.
kubectl apply -f https://raw.githubusercontent.com/kubernetes/ingress-nginx/controller-v1.11.1/deploy/static/provider/aws/deploy.yaml

# Associates the IAM OIDC provider for the specified EKS cluster.
oidc_id=$(aws eks describe-cluster --name $CLUSTER_NAME --query "cluster.identity.oidc.issuer" --output text | cut -d '/' -f 5)
echo $oidc_id
eksctl utils associate-iam-oidc-provider --cluster $CLUSTER_NAME --approve
