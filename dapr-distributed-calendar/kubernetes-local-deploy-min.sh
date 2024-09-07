#!/bin/sh

# Create storage class
kubectl apply -f - <<EOF
apiVersion: storage.k8s.io/v1
kind: StorageClass
metadata:
  name: local-storage
provisioner: kubernetes.io/no-provisioner
volumeBindingMode: WaitForFirstConsumer
EOF

# install OpenEBS
# helm repo add openebs https://openebs.github.io/openebs
# helm repo update
# helm upgrade --install openebs --namespace openebs openebs/openebs --set mayastor.etcd.replicaCount=1 --create-namespace --wait

# create 12-factor-app namespace
kubectl create namespace 12-factor-app

# install prometheus OPTIONAL
kubectl create namespace observability
helm repo add prometheus-community https://prometheus-community.github.io/helm-charts
helm repo update
helm install prometheus prometheus-community/kube-prometheus-stack \
        --namespace observability \
        --values prometheus/kube-prometheus-stack-values.yaml \
        --wait

# install dapr
helm repo add dapr https://dapr.github.io/helm-charts/
helm repo update
helm upgrade --install dapr dapr/dapr \
    --namespace dapr-system \
    --create-namespace \
    --set global.logAsJson=true \
    --set dapr_scheduler.cluster.storageClassName=local-storage \
    --wait

# install dapr dashboard OPTIONAL
helm install dapr-dashboard dapr/dapr-dashboard --namespace dapr-system --wait

helm repo add kedacore https://kedacore.github.io/charts
helm repo update
helm install keda kedacore/keda --namespace keda --create-namespace --wait

# install redis
helm repo add bitnami https://charts.bitnami.com/bitnami
helm repo update
helm install redis bitnami/redis --namespace 12-factor-app --values redis/values.yaml --wait

# deploy the 12-factor-app
redis_encoded_pwd=$(kubectl get secret redis -n 12-factor-app -o jsonpath='{.data.redis-password}')
kubectl apply -f - <<EOF
apiVersion: v1
kind: Secret
metadata:
  name: redis-streams-auth
  namespace: 12-factor-app
type: Opaque
data:
  redis_username: ""
  redis_password: $redis_encoded_pwd
EOF
kubectl apply -f kubernetes/.
kubectl wait --for=condition=ready pod --all --timeout=200s -n 12-factor-app

# setup OpenCost for cost monitoring OPTIONAL
kubectl create namespace opencost
helm install opencost --repo https://opencost.github.io/opencost-helm-chart opencost \
  --namespace opencost -f open-cost/values.yaml --wait

# get redis password (for manual interactions with the redis cli) OPTIONAL
redis_pwd=$(kubectl get secret redis -n 12-factor-app -o jsonpath='{.data.redis-password}' | base64 --decode)
echo The redis password is $redis_pwd
echo To authenticate use: redis-cli -a $redis_pwd
