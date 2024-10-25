#!/bin/bash

# Variables
RG_NAME="tuagye-dev-rg"
PREFIX="tuagye-dev"

# Colors for output
GREEN='\033[0;32m'
RED='\033[0;31m'
NC='\033[0m'

# Test Frontend
echo "Testing Frontend connectivity..."
FRONTEND_URL="${PREFIX}-frontend.azurewebsites.net"
if curl -s -o /dev/null -w "%{http_code}" "https://$FRONTEND_URL" | grep -q "200\|301\|302"; then
    echo -e "${GREEN}✅ Frontend is accessible${NC}"
else
    echo -e "${RED}❌ Frontend is not accessible${NC}"
fi

# Test API
echo "Testing API connectivity..."
API_URL=$(az containerapp show --name "${PREFIX}-api" --resource-group $RG_NAME --query "properties.configuration.ingress.fqdn" -o tsv)
if curl -s -o /dev/null -w "%{http_code}" "https://$API_URL/health" | grep -q "200"; then
    echo -e "${GREEN}✅ API is accessible${NC}"
else
    echo -e "${RED}❌ API is not accessible${NC}"
fi

# Test Cosmos DB
echo "Testing Cosmos DB connection..."
COSMOS_CONNECTION=$(az cosmosdb keys list --type connection-strings \
  --name "${PREFIX}-cosmos" \
  --resource-group $RG_NAME \
  --query connectionStrings[0].connectionString -o tsv)

if mongosh "$COSMOS_CONNECTION" --eval "db.runCommand({ ping: 1 })" &>/dev/null; then
    echo -e "${GREEN}✅ Cosmos DB is accessible${NC}"
else
    echo -e "${RED}❌ Cosmos DB is not accessible${NC}"
fi

# Test Redis
echo "Testing Redis connection..."
REDIS_HOST="${PREFIX}-redis.redis.cache.windows.net"
REDIS_KEY=$(az redis list-keys \
  --name "${PREFIX}-redis" \
  --resource-group $RG_NAME \
  --query primaryKey -o tsv)
REDIS_CONNECTION="redis://:${REDIS_KEY}@${REDIS_HOST}:6380?ssl=true"

if redis-cli -u "$REDIS_CONNECTION" ping | grep -q "PONG"; then
    echo -e "${GREEN}✅ Redis is accessible${NC}"
else
    echo -e "${RED}❌ Redis is not accessible${NC}"
fi

# Test Front Door
echo "Testing Front Door endpoints..."
FRONTEND_FD="${PREFIX}-fd-frontend.azurefd.net"
API_FD="${PREFIX}-fd-api.azurefd.net"

if curl -s -o /dev/null -w "%{http_code}" "https://$FRONTEND_FD" | grep -q "200\|301\|302"; then
    echo -e "${GREEN}✅ Front Door Frontend endpoint is accessible${NC}"
else
    echo -e "${RED}❌ Front Door Frontend endpoint is not accessible${NC}"
fi

if curl -s -o /dev/null -w "%{http_code}" "https://$API_FD/health" | grep -q "200"; then
    echo -e "${GREEN}✅ Front Door API endpoint is accessible${NC}"
else
    echo -e "${RED}❌ Front Door API endpoint is not accessible${NC}"
fi

# Additional Checks
echo -e "\nResource Status:"
echo "===================="

# Check App Service Status
APP_STATUS=$(az webapp show --name "${PREFIX}-frontend" --resource-group $RG_NAME --query "state" -o tsv)
echo -e "Frontend App Service: ${GREEN}$APP_STATUS${NC}"

# Check Container App Status
CONTAINER_STATUS=$(az containerapp show --name "${PREFIX}-api" --resource-group $RG_NAME --query "properties.runningStatus" -o tsv)
echo -e "API Container App: ${GREEN}$CONTAINER_STATUS${NC}"

# Check Redis Status
REDIS_STATUS=$(az redis show --name "${PREFIX}-redis" --resource-group $RG_NAME --query "provisioningState" -o tsv)
echo -e "Redis Cache: ${GREEN}$REDIS_STATUS${NC}"

# Check Cosmos DB Status
COSMOS_STATUS=$(az cosmosdb show --name "${PREFIX}-cosmos" --resource-group $RG_NAME --query "provisioningState" -o tsv)
echo -e "Cosmos DB: ${GREEN}$COSMOS_STATUS${NC}"