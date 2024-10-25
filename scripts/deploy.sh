#!/bin/bash

# Configuration
PROJECT_NAME="tuagye"
LOCATION="uksouth"
ENVIRONMENT=${1:-"dev"}  # Default to dev if not specified

# Colors for output
GREEN='\033[0;32m'
BLUE='\033[0;34m'
RED='\033[0;31m'
NC='\033[0m'

echo -e "${BLUE}🚀 Deploying Tuagye ($ENVIRONMENT) Infrastructure...${NC}"

# Login to Azure (if not already logged in)
if ! az account show >/dev/null; then
    echo "Please login to Azure..."
    az login
fi

# Create or update ACR if it doesn't exist
echo -e "${BLUE}Setting up Azure Container Registry...${NC}"
az acr create \
  --name "${PROJECT_NAME}acr" \
  --resource-group "${PROJECT_NAME}-${ENVIRONMENT}-rg" \
  --sku Basic \
  --admin-enabled true

# Build and push API image
echo -e "${BLUE}Building and pushing API image...${NC}"
az acr build \
  --registry "${PROJECT_NAME}acr" \
  --image "${PROJECT_NAME}-api:latest" \
  ./api

# Deploy infrastructure
echo -e "${BLUE}Deploying main infrastructure...${NC}"
az deployment sub create \
  --location $LOCATION \
  --template-file ../main.bicep \
  --parameters "@../parameters/${ENVIRONMENT}.parameters.json" \
  --parameters apiImageTag=latest

if [ $? -eq 0 ]; then
    echo -e "${GREEN}✅ Infrastructure deployment successful!${NC}"
else
    echo -e "${RED}❌ Infrastructure deployment failed!${NC}"
    exit 1
fi

# Run connectivity tests
echo -e "${BLUE}Running connectivity tests...${NC}"
./test-connectivity.sh

echo -e "${GREEN}✅ Deployment complete!${NC}"

# Get connection strings and endpoints
echo -e "\n${BLUE}Connection Details:${NC}"
az deployment sub show \
  --name main \
  --query properties.outputs \
  --output table

# Setup custom domain if in production
if [ "$ENVIRONMENT" = "prod" ]; then
    echo -e "\n${BLUE}Custom Domain Configuration:${NC}"
    echo "Please configure the following DNS records for tuagye.com:"
    echo "1. CNAME www -> $(az deployment sub show --name main --query properties.outputs.frontendEndpoint.value -o tsv)"
    echo "2. CNAME api -> $(az deployment sub show --name main --query properties.outputs.apiEndpoint.value -o tsv)"
fi