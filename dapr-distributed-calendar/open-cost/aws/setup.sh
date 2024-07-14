#!/bin/bash
# https://www.opencost.io/docs/configuration/aws

set -e

# Sets up variables for the cluster name, region, namespace and account ID.
CLUSTER_NAME=mycluster
REGION=eu-central-1
NAMESPACE=external-dns
ACCOUNT_ID=$(aws sts get-caller-identity | python3 -c "import sys,json; print (json.load(sys.stdin)['Account'])")
ROUTE_53_ZONE_ID=<YOUR_ROUTE_53_ZONE_ID>
export AWS_PRICING_URL=$REGION

# Create a externeal-dns policy
aws iam create-policy --policy-name AllowExternalDNSUpdates --policy-document '{
    "Version": "2012-10-17",
    "Statement": [
        {
            "Effect": "Allow",
            "Action": [
                "route53:ChangeResourceRecordSets"
            ],
            "Resource": [
                "arn:aws:route53:::hostedzone/'$ROUTE_53_ZONE_ID'"
            ]
        },
        {
            "Effect": "Allow",
            "Action": [
                "route53:ListHostedZones",
                "route53:ListResourceRecordSets"
            ],
            "Resource": [
                "*"
            ]
        }
    ]
}'

# Updates the kubeconfig for the specified EKS cluster.
aws eks --region $REGION update-kubeconfig --name $CLUSTER_NAME

# Installs OpenSSL, downloads Helm 3, and makes it executable.
sudo yum install openssl -y
curl https://raw.githubusercontent.com/helm/helm/master/scripts/get-helm-3 > get_helm.sh
chmod 700 get_helm.sh
./get_helm.sh

# Creates a Kubernetes namespace.
kubectl create namespace $NAMESPACE

# for ARM systems, set ARCH to: `arm64`, `armv6` or `armv7`
ARCH=amd64
PLATFORM=$(uname -s)_$ARCH

# Downloads and extracts the eksctl utility.
curl -sLO "https://github.com/weaveworks/eksctl/releases/latest/download/eksctl_$PLATFORM.tar.gz"

# (Optional) Verify checksum
curl -sL "https://github.com/weaveworks/eksctl/releases/latest/download/eksctl_checksums.txt" | grep $PLATFORM | sha256sum --check

tar -xzf eksctl_$PLATFORM.tar.gz -C /tmp && rm eksctl_$PLATFORM.tar.gz

sudo mv /tmp/eksctl /usr/local/bin

# Associates the IAM OIDC provider with the EKS cluster.
eksctl utils associate-iam-oidc-provider \
    --region=$REGION \
    --cluster=$CLUSTER_NAME \
    --approve

# Creates IAM service accounts for external-dns and aws-load-balancer-controller, attaching the appropriate IAM policies.
eksctl create iamserviceaccount \
    --name external-dns \
    --cluster $CLUSTER_NAME \
    --attach-policy-arn arn:aws:iam::$ACCOUNT_ID:policy/AllowExternalDNSUpdates \
    --approve \
    --override-existing-serviceaccounts \
    --namespace $NAMESPACE

eksctl create iamserviceaccount \
    --name aws-load-balancer-controller \
    --cluster $CLUSTER_NAME \
    --attach-policy-arn arn:aws:iam::$ACCOUNT_ID:policy/AWSLoadBalancerControllerIAMPolicy \
    --region $REGION \
    --approve \
    --override-existing-serviceaccounts \
    --namespace=kube-system

# Adds the EKS Helm repository and updates the repositories.
helm repo add eks https://aws.github.io/eks-charts
helm repo update eks

# Installs the aws-load-balancer-controller using Helm, specifying the cluster name and service account details.
helm install aws-load-balancer-controller eks/aws-load-balancer-controller \
  -n kube-system \
  --set clusterName=$CLUSTER_NAME \
  --set serviceAccount.create=false \
  --set serviceAccount.name=aws-load-balancer-controller

# Applies Kubernetes resources (ClusterRole, ClusterRoleBinding, and Deployment) for external-dns.
# Configures the external-dns Deployment with necessary parameters, including the domain filter, AWS provider, and AWS zone type.
kubectl apply -f - <<EOF
apiVersion: rbac.authorization.k8s.io/v1
kind: ClusterRole
metadata:
  name: external-dns
  namespace: $NAMESPACE
rules:
- apiGroups: [""]
  resources: ["services"]
  verbs: ["get","watch","list"]
- apiGroups: [""]
  resources: ["pods"]
  verbs: ["get","watch","list"]
- apiGroups: ["networking","networking.k8s.io"]
  resources: ["ingresses"]
  verbs: ["get","watch","list"]
- apiGroups: [""]
  resources: ["nodes"]
  verbs: ["get","watch","list"]
- apiGroups: [""]
  resources: ["endpoints"]
  verbs: ["get","watch","list"]
---
apiVersion: rbac.authorization.k8s.io/v1
kind: ClusterRoleBinding
metadata:
  name: external-dns-viewer
  namespace: $NAMESPACE
roleRef:
  apiGroup: rbac.authorization.k8s.io
  kind: ClusterRole
  name: external-dns
subjects:
- kind: ServiceAccount
  name: external-dns
  namespace: wherebear
---
apiVersion: apps/v1
kind: Deployment
metadata:
  name: external-dns
  namespace: $NAMESPACE
spec:
  strategy:
    type: Recreate
  selector:
    matchLabels:
      app: external-dns
  template:
    metadata:
      labels:
        app: external-dns
    spec:
      serviceAccountName: external-dns
      containers:
      - name: external-dns
        image: k8s.gcr.io/external-dns/external-dns:v0.13.4
        args:
        - --source=service
        - --source=ingress
        - --domain-filter=wherebear.app # will make ExternalDNS see only the hosted zones matching provided domain, omit to process all available hosted zones
        - --provider=aws
        #- --policy=upsert-only # would prevent ExternalDNS from deleting any records, omit to enable full synchronization
        - --aws-zone-type=public # only look at public hosted zones (valid values are public, private or no value for both)
        - --registry=txt
        - --txt-owner-id=wherebear-eks-cluster-external-dns
      securityContext:
        fsGroup: 65534 # For ExternalDNS to be able to read Kubernetes and AWS token files
EOF

# Installs the OpenCost Helm chart, specifying the namespace and the Prometheus configuration.
helm install prometheus --repo https://prometheus-community.github.io/helm-charts prometheus \
  --namespace prometheus-system --create-namespace \
  --set prometheus-pushgateway.enabled=false \
  --set alertmanager.enabled=false \
  -f https://raw.githubusercontent.com/opencost/opencost/develop/kubernetes/prometheus/extraScrapeConfigs.yaml --wait

kubectl create namespace opencost

helm install opencost --repo https://opencost.github.io/opencost-helm-chart opencost \
  --namespace opencost --wait

kubectl apply -f ingress.yaml
