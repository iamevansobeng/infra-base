#!/bin/bash

# Colors for output
GREEN='\033[0;32m'
RED='\033[0;31m'
NC='\033[0m'

# Get deployment outputs
FRONTEND_URL=$(az deployment sub show --name main --query properties.outputs.frontendUrl.value -o tsv)
API_URL=$(az deployment sub show --name main --query properties.outputs.apiUrl.value -o tsv)

# Test Frontend
echo "Testing Frontend connectivity..."
if curl -s -o /dev/null -w "%{http_code}" "https://$FRONTEND_URL" | grep -q "200\|301\|302"; then
    echo -e "${GREEN}✅ Frontend is accessible${NC}"
else
    echo -e "${RED}❌ Frontend is not accessible${NC}"
fi

# Test API
echo "Testing API connectivity..."
if curl -s -o /dev/null -w "%{http_code}" "https://$API_URL/health" | grep -q "200"; then
    echo -e "${GREEN}✅ API is accessible${NC}"
else
    echo -e "${RED}❌ API is not accessible${NC}"
fi

# Test Cosmos DB connection
echo "Testing Cosmos DB connection..."
COSMOS_CONNECTION=$(az deployment sub show --name main --query properties.outputs.cosmosConnectionString.value -o tsv)
if mongosh "$COSMOS_CONNECTION" --eval "db.runCommand({ ping: 1 })" &>/dev/null; then
    echo -e "${GREEN}✅ Cosmos DB is accessible${NC}"
else
    echo -e "${RED}❌ Cosmos DB is not accessible${NC}"
fi

# Test Redis connection
echo "Testing Redis connection..."
REDIS_CONNECTION=$(az deployment sub show --name main --query properties.outputs.redisConnectionString.value -o tsv)
if redis-cli -u "$REDIS_CONNECTION" ping | grep -q "PONG"; then
    echo -e "${GREEN}✅ Redis is accessible${NC}"
else
    echo -e "${RED}❌ Redis is not accessible${NC}"
fi