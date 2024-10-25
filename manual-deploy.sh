# Variables
RG_NAME="tuagye-dev-rg"
LOCATION="uksouth"
PREFIX="tuagye-dev"
ACR_NAME="tuagyedevacr"  # Changed: removed hyphen

# First, install the required extension
az extension add --name application-insights

# 1. Create Resource Group (if not exists)
az group create --name $RG_NAME --location $LOCATION

# 2. Create Virtual Network
az network vnet create \
  --name "${PREFIX}-vnet" \
  --resource-group $RG_NAME \
  --address-prefix 10.0.0.0/16 \
  --subnet-name frontend-subnet \
  --subnet-prefix 10.0.1.0/24

# Add API subnet
az network vnet subnet create \
  --name api-subnet \
  --resource-group $RG_NAME \
  --vnet-name "${PREFIX}-vnet" \
  --address-prefix 10.0.2.0/24

# Add data subnet
az network vnet subnet create \
  --name data-subnet \
  --resource-group $RG_NAME \
  --vnet-name "${PREFIX}-vnet" \
  --address-prefix 10.0.3.0/24

# 3. Create Container Registry (Fixed name)
az acr create \
  --name $ACR_NAME \
  --resource-group $RG_NAME \
  --sku Basic \
  --admin-enabled true

# 4. Create Log Analytics Workspace
az monitor log-analytics workspace create \
  --name "${PREFIX}-workspace" \
  --resource-group $RG_NAME

# 5. Create Application Insights
az monitor app-insights component create \
  --app "${PREFIX}-appinsights" \
  --location $LOCATION \
  --resource-group $RG_NAME \
  --workspace "${PREFIX}-workspace"

# 6. Create Redis Cache
az redis create \
  --name "${PREFIX}-redis" \
  --resource-group $RG_NAME \
  --location $LOCATION \
  --sku Basic \
  --vm-size c0

# 7. Create Cosmos DB
az cosmosdb create \
  --name "${PREFIX}-cosmos" \
  --resource-group $RG_NAME \
  --kind MongoDB \
  --capabilities EnableServerless \
  --default-consistency-level Session

# Create Database
az cosmosdb mongodb database create \
  --account-name "${PREFIX}-cosmos" \
  --name tuagye \
  --resource-group $RG_NAME

# Create Collection
az cosmosdb mongodb collection create \
  --account-name "${PREFIX}-cosmos" \
  --database-name tuagye \
  --name addresses \
  --resource-group $RG_NAME \
  --shard region

# 8. Create App Service Plan
az appservice plan create \
  --name "${PREFIX}-plan" \
  --resource-group $RG_NAME \
  --sku B1 \
  --is-linux

# 9. Create Frontend App Service
az webapp create \
  --name "${PREFIX}-frontend" \
  --resource-group $RG_NAME \
  --plan "${PREFIX}-plan" \
  --runtime "NODE|18-lts"

# 10. Create Container Apps Environment
az containerapp env create \
  --name "${PREFIX}-env" \
  --resource-group $RG_NAME \
  --location $LOCATION

# 11. Create API Container App
az containerapp create \
  --name "${PREFIX}-api" \
  --resource-group $RG_NAME \
  --environment "${PREFIX}-env" \
  --image mcr.microsoft.com/azuredocs/containerapps-helloworld:latest \
  --target-port 3000 \
  --ingress external \
  --min-replicas 0 \
  --max-replicas 2

# 12. Create Front Door
az afd profile create \
  --profile-name "${PREFIX}-fd" \
  --resource-group $RG_NAME \
  --sku Standard_AzureFrontDoor

# Create endpoint for frontend
az afd endpoint create \
  --endpoint-name frontend \
  --profile-name "${PREFIX}-fd" \
  --resource-group $RG_NAME

# Create endpoint for API
az afd endpoint create \
  --endpoint-name api \
  --profile-name "${PREFIX}-fd" \
  --resource-group $RG_NAME

# Get connection strings and other details
echo "=== Connection Details ==="
echo "Redis Key:"
az redis list-keys --name "${PREFIX}-redis" --resource-group $RG_NAME

echo "Cosmos DB Connection String:"
az cosmosdb keys list --name "${PREFIX}-cosmos" --resource-group $RG_NAME --type connection-strings

echo "App Insights Key:"
az monitor app-insights component show --app "${PREFIX}-appinsights" --resource-group $RG_NAME --query instrumentationKey