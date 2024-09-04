#!/bin/bash
# set -e

# Sets up variables for the cluster name, region and subscription id
CLUSTER_NAME=loadgen-test
RESOURCE_GROUP=loadgen-test
SUBSCRIPTION_ID=d0ab8612-6be4-4ebf-84f3-50c2771cc912
TENANT_ID=f05ae7d3-dff8-4e99-b4c7-09990343e55e

# Updates the kubeconfig for the specified AKS cluster.
az login
az account set --subscription $SUBSCRIPTION_ID
az aks get-credentials --resource-group $RESOURCE_GROUP --name $CLUSTER_NAME --overwrite-existing

# Installs the NGINX Ingress Controller for the specified AKS cluster.
kubectl apply -f https://raw.githubusercontent.com/kubernetes/ingress-nginx/controller-v1.11.1/deploy/static/provider/cloud/deploy.yaml

# Configure the cluster for OpenCost
kubectl create namespace opencost
az role definition create --verbose --role-definition '{
    "Name": "OpenCostRole",
    "IsCustom": true,
    "Description": "Rate Card query role",
    "Actions": [
        "Microsoft.Compute/virtualMachines/vmSizes/read",
        "Microsoft.Resources/subscriptions/locations/read",
        "Microsoft.Resources/providers/read",
        "Microsoft.ContainerService/containerServices/read",
        "Microsoft.Commerce/RateCard/read"
    ],
    "AssignableScopes": [
        "/subscriptions/'$SUBSCRIPTION_ID'"
    ]
}'

service_principle=$(az ad sp create-for-rbac \
  --name "OpenCostAccess" \
  --role "OpenCostRole" \
  --scope "/subscriptions/$SUBSCRIPTION_ID" \
  --output json)

app_id=$(echo $service_principle | jq -r '.appId')
client_secret=$(echo $service_principle | jq -r '.password')

service_key_json=$(cat <<EOF
{
    "subscriptionId": "$SUBSCRIPTION_ID",
    "serviceKey": {
        "appId": "$app_id",
        "displayName": "OpenCostAccess",
        "password": "$client_secret",
        "tenant": "$TENANT_ID"
    }
}
EOF
)

echo "$service_key_json" > "service-key.json"

kubectl create secret generic azure-service-key -n opencost --from-file=service-key.json
