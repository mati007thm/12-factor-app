#!/bin/bash
# https://www.opencost.io/docs/configuration/azure

# Custom Names
mySubscription="Azure subscription 1"
desired_tenant="TENANT_ID"

# Check if logged in
if az account show &> /dev/null; then
    current_tenant=$(az account show --query "tenantId" --output tsv | tr -d '\r')

    # Check if logged into the correct tenant
    if [[ "$current_tenant" == "$desired_tenant" ]]; then
        echo "Already logged in to the correct tenant: $desired_tenant"
    else
        # Log out and log in with the correct tenant
        echo "Logging out from the current session..."
        az logout

        echo "Logging in to the desired tenant: $desired_tenant"
        az login --tenant $desired_tenant
        # az login --scope https://graph.microsoft.com//.default --tenant $desired_tenant
    fi
else
    # Not logged in, log in to the desired tenant
    echo "Not logged in. Logging in to the desired tenant: $desired_tenant"
    az login --tenant $desired_tenant
fi

# Global vars
subscriptionId=$(az account show \
        --subscription "$mySubscription" \
        --query id \
        --output tsv)

az account set --subscription $subscriptionId


helm install prometheus --repo https://prometheus-community.github.io/helm-charts prometheus \
  --namespace prometheus-system --create-namespace \
  --set prometheus-pushgateway.enabled=false \
  --set alertmanager.enabled=false \
  -f https://raw.githubusercontent.com/opencost/opencost/develop/kubernetes/prometheus/extraScrapeConfigs.yaml --wait

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
        "/subscriptions/'$subscriptionId'"
    ]
}'

service_principle=$(az ad sp create-for-rbac \
  --name "OpenCostAccess" \
  --role "OpenCostRole" \
  --scope "/subscriptions/$subscriptionId" \
  --output json)

app_id=$(echo $service_principle | jq -r '.appId')
client_secret=$(echo $service_principle | jq -r '.password')

service_key_json=$(cat <<EOF
{
    "subscriptionId": "$subscriptionId",
    "serviceKey": {
        "appId": "$app_id",
        "displayName": "OpenCostAccess",
        "password": "$client_secret",
        "tenant": "$desired_tenant"
    }
}
EOF
)

echo "$service_key_json" > "service-key.json"

kubectl create secret generic azure-service-key -n opencost --from-file=service-key.json

# cloud_integration_json=$(cat <<EOF
# {
#   "azure": {
#     "storage": [
#       {
#         "subscriptionID": "$subscriptionId",
#         "account": "<STORAGE_ACCOUNT>",
#         "container": "<STORAGE_CONTAINER>",
#         "path": "<CONTAINER_PATH>",
#         "cloud": "<CLOUD>",
#         "authorizer": {
#           "accessKey": "<STORAGE_ACCESS_KEY>",
#           "account": "<ACCOUNT>",
#           "authorizerType": "AzureAccessKey"
#         }
#       },
#       {
#         "subscriptionID": "$subscriptionId",
#         "account": "<ACCOUNT>",
#         "container": "<EXPORT_CONTAINER>",
#         "path": "",
#         "cloud": "<CLOUD>",
#         "authorizer": {
#           "accessKey": "<ACCOUNT_ACCESS_KEY>",
#           "account": "<ACCOUNT>",
#           "authorizerType": "AzureAccessKey"
#         }
#       }
#     ]
#   }
# }
# EOF
# )

# echo "$cloud_integration_json" > "cloud-integration.json"

# kubectl create secret generic cloud-costs --from-file=cloud-integration.json --namespace opencost

helm install opencost --repo https://opencost.github.io/opencost-helm-chart opencost \
  --namespace opencost -f values.yaml --wait

kubectl apply -f ingress.yaml
