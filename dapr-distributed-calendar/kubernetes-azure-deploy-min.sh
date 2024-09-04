#!/bin/sh

# Create ingress class
kubectl apply -f - <<EOF
apiVersion: networking.k8s.io/v1
kind: IngressClass
metadata:
  name: nginx-class
spec:
  controller: k8s.io/ingress-nginx
EOF

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
kubectl apply -f ./prometheus/azure/ingress.yaml

# install dapr
helm repo add dapr https://dapr.github.io/helm-charts/
helm repo update
helm upgrade --install dapr dapr/dapr \
    --namespace dapr-system \
    --create-namespace \
    --set global.logAsJson=true \
    --wait

# install KEDA for scaling
helm repo add kedacore https://kedacore.github.io/charts
helm repo update
helm install keda kedacore/keda --namespace keda --create-namespace --wait

# install redis
helm repo add bitnami https://charts.bitnami.com/bitnami
helm repo update
helm install redis bitnami/redis --namespace 12-factor-app --values redis/azure/values.yaml --wait

# set redis password as secret for kedascaledobject
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

# deploy the 12-factor-app
kubectl apply -f azure-kubernetes/.
kubectl wait --for=condition=ready pod --all --timeout=200s -n 12-factor-app

# setup OpenCost for cost monitoring OPTIONAL
helm install opencost --repo https://opencost.github.io/opencost-helm-chart opencost \
  --namespace opencost -f open-cost/values.yaml --wait
kubectl apply -f open-cost/azure/ingress.yaml

# setup locust for loadgeneration OPTIONAL
kubectl create configmap my-loadtest-locustfile --from-file locust/main.py -n 12-factor-app
helm repo add deliveryhero https://charts.deliveryhero.io/
helm repo update
helm install locust deliveryhero/locust \
  --namespace 12-factor-app \
  --values locust/azure/values.yaml \
  --wait
kubectl apply -f locust/azure/ingress.yaml

# get redis password (for manual interactions with the redis cli) OPTIONAL
redis_pwd=$(kubectl get secret redis -n 12-factor-app -o jsonpath='{.data.redis-password}' | base64 --decode)
echo The redis password is $redis_pwd
echo To authenticate use: redis-cli -a $redis_pwd
