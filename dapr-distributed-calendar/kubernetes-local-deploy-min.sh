#!/bin/sh

# create 12-factor-app namespace
kubectl create namespace 12-factor-app

# install OTel Operator
# Breaking changes to the OTEL operator helm chart need to review the changes
# kubectl create namespace opentelemetry
# helm repo add open-telemetry https://open-telemetry.github.io/opentelemetry-helm-charts
# helm repo update
# helm install my-opentelemetry-operator open-telemetry/opentelemetry-operator \
#   --set "manager.collectorImage.repository=otel/opentelemetry-collector-k8s" \
#   --set admissionWebhooks.certManager.enabled=false \
#   --namespace opentelemetry \
#   --create-namespace \
#   --wait

# create OTel collector and instrumentation
# kubectl apply -f otel/.

# install cert-manager OPTIONAL
# helm repo add jetstack https://charts.jetstack.io
# helm repo update
# helm upgrade --install \
#   cert-manager jetstack/cert-manager \
#   --namespace cert-manager \
#   --create-namespace \
#   --version v1.7.1 \
#   --set installCRDs=true \
#   --wait

# install jaeger (requires cert-manager) OPTIONAL
# kubectl create namespace observability
# kubectl create -f https://github.com/jaegertracing/jaeger-operator/releases/download/v1.38.0/jaeger-operator.yaml -n observability
# kubectl wait --for=condition=ready pod --all --timeout=200s -n observability
# kubectl apply -f jaeger/.

# install prometheus OPTIONAL
# helm repo add prometheus-community https://prometheus-community.github.io/helm-charts
# helm repo update
# helm install prometheus prometheus-community/kube-prometheus-stack \
#         --namespace observability \
#         --values prometheus/kube-prometheus-stack-values.yaml \
#         --wait
# kubectl apply -f ./prometheus/ingress.yaml

# install elastic (requires namespace 'observability') OPTIONAL
# helm repo add elastic https://helm.elastic.co
# helm repo update
# helm install elasticsearch elastic/elasticsearch --version 7.17.3 -n observability --set replicas=1 --wait
# helm install kibana elastic/kibana --version 7.17.3 -n observability --wait
# kubectl apply -f ./fluent/fluentd-config-map.yaml
# kubectl apply -f ./fluent/fluentd-dapr-with-rbac.yaml
# kubectl wait --for=condition=ready pod --all --timeout=200s -n observability
# kubectl apply -f ./fluent/ingress.yaml

# install dapr
helm repo add dapr https://dapr.github.io/helm-charts/
helm repo update
helm upgrade --install dapr dapr/dapr \
    --namespace dapr-system \
    --create-namespace \
    --set global.logAsJson=true \
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
# kubectl wait --for=condition=ready pod --all --timeout=200s -n 12-factor-app

# setup OpenCost for cost monitoring OPTIONAL
# kubectl create namespace opencost
# helm install opencost --repo https://opencost.github.io/opencost-helm-chart opencost \
#   --namespace opencost -f open-cost/local.yaml --wait
# kubectl apply -f open-cost/ingress.yaml

# setup kubecost for cost monitoring OPTIONAL
# helm upgrade --install kubecost \
#   --repo https://kubecost.github.io/cost-analyzer/ cost-analyzer \
#   --namespace kubecost --create-namespace \
#   --set global.prometheus.fqdn=http://prometheus-kube-prometheus-prometheus.observability.svc:9090 \
#   --set global.prometheus.enabled=false \
#   --set kubecostToken="bWF0dGhpYXMudGhldWVybWFubkBpY2xvdWQuY29txm343yadf98" --wait
# helm upgrade --install kubecost cost-analyzer \
#   --repo https://kubecost.github.io/cost-analyzer/ \
#   --namespace kubecost --create-namespace \
#   --set kubecostToken="bWF0dGhpYXMudGhldWVybWFubkBpY2xvdWQuY29txm343yadf98" --wait
# kubectl apply -f kubecost/ingress.yaml

# setup locust for loadgeneration OPTIONAL
# https://github.com/deliveryhero/helm-charts/tree/master/stable/locust
# https://medium.com/teamsnap-engineering/load-testing-a-service-with-20-000-requests-per-second-with-locust-helm-and-kustomize-ea9bea02ae28
kubectl create configmap my-loadtest-locustfile --from-file locust/main.py -n 12-factor-app
helm repo add deliveryhero https://charts.deliveryhero.io/
helm repo update
helm install locust deliveryhero/locust \
  --set loadtest.name=my-loadtest \
  --set loadtest.locust_locustfile_configmap=my-loadtest-locustfile \
  --set loadtest.locust_host=http://controller.12-factor-app:3000 \
  --set master.environment.LOCUST_RUN_TIME=1m \
  --set loadtest.environment.LOCUST_AUTOSTART="true" \
  --namespace 12-factor-app \
  --values locust/values.yaml \
  --wait
kubectl apply -f locust/ingress.yaml

# get redis password (for manual interactions with the redis cli) OPTIONAL
redis_pwd=$(kubectl get secret redis -n 12-factor-app -o jsonpath='{.data.redis-password}' | base64 --decode)
echo The redis password is $redis_pwd
echo To authenticate use: redis-cli -a $redis_pwd
