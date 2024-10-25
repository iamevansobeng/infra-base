# Variables
RG_NAME="tuagye-dev-rg"
LOCATION="uksouth"
PREFIX="tuagye-dev"
ACR_NAME="tuagyedevacr"

echo "🚀 Starting deployment..."

# 1. Create Resource Group
echo "Creating Resource Group..."
az group create --name $RG_NAME --location $LOCATION

# 2. Create Virtual Network
echo "Creating Virtual Network..."
az network vnet create \
  --name "${PREFIX}-vnet" \
  --resource-group $RG_NAME \
  --address-prefix 10.0.0.0/16 \
  --subnet-name frontend-subnet \
  --subnet-prefix 10.0.1.0/24

echo "Adding API subnet..."
az network vnet subnet create \
  --name api-subnet \
  --resource-group $RG_NAME \
  --vnet-name "${PREFIX}-vnet" \
  --address-prefix 10.0.2.0/24

echo "Adding data subnet..."
az network vnet subnet create \
  --name data-subnet \
  --resource-group $RG_NAME \
  --vnet-name "${PREFIX}-vnet" \
  --address-prefix 10.0.3.0/24

# 3. Create Container Registry
echo "Creating Container Registry..."
az acr create \
  --name $ACR_NAME \
  --resource-group $RG_NAME \
  --sku Basic \
  --admin-enabled true

# 4. Create Log Analytics Workspace
echo "Creating Log Analytics Workspace..."
az monitor log-analytics workspace create \
  --name "${PREFIX}-workspace" \
  --resource-group $RG_NAME

# 5. Create Application Insights
echo "Creating Application Insights..."
az monitor app-insights component create \
  --app "${PREFIX}-appinsights" \
  --location $LOCATION \
  --resource-group $RG_NAME \
  --workspace "${PREFIX}-workspace"

# 6. Create Redis Cache
# Update Redis to disable public access
az redis update \
  --name "${PREFIX}-redis" \
  --resource-group $RG_NAME \
  --public-network-access Disabled

# Add Redis private endpoint
az network private-endpoint create \
  --name "${PREFIX}-redis-pe" \
  --resource-group $RG_NAME \
  --vnet-name "${PREFIX}-vnet" \
  --subnet data-subnet \
  --private-connection-resource-id $(az redis show --name "${PREFIX}-redis" --resource-group $RG_NAME --query id -o tsv) \
  --group-id "redisCache" \
  --connection-name "redis-connection"

# Create DNS Zone for Redis
az network private-dns zone create \
  --name "privatelink.redis.cache.windows.net" \
  --resource-group $RG_NAME

# Link DNS Zone to VNET
az network private-dns link vnet create \
  --name "${PREFIX}-redis-dns-link" \
  --resource-group $RG_NAME \
  --zone-name "privatelink.redis.cache.windows.net" \
  --virtual-network "${PREFIX}-vnet" \
  --registration-enabled false
# Wait for Redis to be ready
echo "Waiting for Redis to be ready..."
sleep 60

# 7. Create Cosmos DB with MongoDB API
echo "Creating Cosmos DB..."
az cosmosdb create \
  --name "${PREFIX}-cosmos" \
  --resource-group $RG_NAME \
  --kind MongoDB \
  --server-version 4.2 \
  --default-consistency-level Session \
  --locations regionName=$LOCATION failoverPriority=0 isZoneRedundant=false

# Wait for Cosmos DB to be ready
echo "Waiting for Cosmos DB to be ready..."
sleep 60

echo "Creating Cosmos DB Database..."
az cosmosdb mongodb database create \
  --account-name "${PREFIX}-cosmos" \
  --name tuagye \
  --resource-group $RG_NAME

# Update Container Apps Environment with VNET integration
az containerapp env update \
  --name "${PREFIX}-env" \
  --resource-group $RG_NAME \
  --vnet-name "${PREFIX}-vnet" \
  --infrastructure-subnet-name api-subnet

# Update the Container App with environment variables and networking
az containerapp update \
  --name "${PREFIX}-api" \
  --resource-group $RG_NAME \
  --env-vars \
    MONGODB_URI=$(az cosmosdb keys list --type connection-strings --name "${PREFIX}-cosmos" --resource-group $RG_NAME --query connectionStrings[0].connectionString -o tsv) \
    REDIS_URL="redis://${PREFIX}-redis.redis.cache.windows.net:6380?ssl=true&password=$(az redis list-keys --name "${PREFIX}-redis" --resource-group $RG_NAME --query primaryKey -o tsv)" \
  --ingress external \
  --target-port 3000 \
  --min-replicas 1 \
  --max-replicas 2

# Create DNS Zone for Cosmos DB
az network private-dns zone create \
  --name "privatelink.mongo.cosmos.azure.com" \
  --resource-group $RG_NAME

# Link DNS Zone to VNET
az network private-dns link vnet create \
  --name "${PREFIX}-cosmos-dns-link" \
  --resource-group $RG_NAME \
  --zone-name "privatelink.mongo.cosmos.azure.com" \
  --virtual-network "${PREFIX}-vnet" \
  --registration-enabled false

# 8. Create App Service Plan
echo "Creating App Service Plan..."
az appservice plan create \
  --name "${PREFIX}-plan" \
  --resource-group $RG_NAME \
  --sku B1 \
  --is-linux

# 9. Create Frontend App Service
echo "Creating Frontend App Service..."
az webapp create \
  --name "${PREFIX}-frontend" \
  --resource-group $RG_NAME \
  --plan "${PREFIX}-plan" \
  --runtime "NODE|18-lts"

# 10. Create Container Apps Environment
echo "Creating Container Apps Environment..."
az containerapp env create \
  --name "${PREFIX}-env" \
  --resource-group $RG_NAME \
  --location $LOCATION

# 11. Create API Container App
echo "Creating API Container App..."
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
echo "Creating Front Door..."
az afd profile create \
  --profile-name "${PREFIX}-fd" \
  --resource-group $RG_NAME \
  --sku Standard_AzureFrontDoor

echo "Creating Frontend Endpoint..."
az afd endpoint create \
  --endpoint-name frontend \
  --profile-name "${PREFIX}-fd" \
  --resource-group $RG_NAME

echo "Creating API Endpoint..."
az afd endpoint create \
  --endpoint-name api \
  --profile-name "${PREFIX}-fd" \
  --resource-group $RG_NAME

echo "🎉 Deployment completed! Getting connection details..."

# Get connection strings and other details
echo "=== Connection Details ==="
echo "Redis Key:"
az redis list-keys --name "${PREFIX}-redis" --resource-group $RG_NAME

echo "Cosmos DB Connection String:"
az cosmosdb keys list --name "${PREFIX}-cosmos" --resource-group $RG_NAME --type connection-strings

echo "App Insights Key:"
az monitor app-insights component show --app "${PREFIX}-appinsights" --resource-group $RG_NAME --query instrumentationKey