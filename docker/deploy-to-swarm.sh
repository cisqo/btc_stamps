#!/bin/bash
# Script to deploy Bitcoin Stamps to Docker Swarm
# Usage: ./deploy-to-swarm.sh <environment> [options]
# Example: ./deploy-to-swarm.sh production --no-test

set -e # Exit on any error

# Define colors for output
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m' # No Color

# Default values
ENVIRONMENT="production"
STACK_NAME="btc-stamps"
TEST_BEFORE_DEPLOY=true
INDEX_IMAGE="btcstamps/indexer:latest"
APP_IMAGE="btcstamps/app:latest"
APP_REPLICAS=2
APP_PORT=8080

# Parse arguments
if [ $# -ge 1 ]; then
  ENVIRONMENT="$1"
  shift
fi

while [[ "$#" -gt 0 ]]; do
  case $1 in
    --stack-name) STACK_NAME="$2"; shift 2 ;;
    --no-test) TEST_BEFORE_DEPLOY=false; shift ;;
    --indexer-image) INDEX_IMAGE="$2"; shift 2 ;;
    --app-image) APP_IMAGE="$2"; shift 2 ;;
    --app-replicas) APP_REPLICAS="$2"; shift 2 ;;
    --app-port) APP_PORT="$2"; shift 2 ;;
    *) echo -e "${RED}Unknown parameter: $1${NC}"; exit 1 ;;
  esac
done

# Display banner
echo -e "${GREEN}===========================================${NC}"
echo -e "${GREEN}   Bitcoin Stamps Swarm Deployment Tool   ${NC}"
echo -e "${GREEN}===========================================${NC}"
echo

# Check if we're in the right directory
if [ ! -f "docker-compose.swarm.yml" ]; then
    echo -e "${RED}Error: docker-compose.swarm.yml not found!${NC}"
    echo -e "${YELLOW}Please run this script from the docker directory.${NC}"
    exit 1
fi

# Ensure we're logged into Docker Hub
echo -e "${YELLOW}Checking Docker Hub authentication...${NC}"
if ! docker info | grep -q "Username"; then
    echo -e "${YELLOW}Please login to Docker Hub:${NC}"
    docker login
fi

# Pull latest images
echo -e "${YELLOW}Pulling latest images...${NC}"
docker pull "$INDEX_IMAGE"
docker pull "$APP_IMAGE"

# Test the indexer image if requested
if [ "$TEST_BEFORE_DEPLOY" = true ]; then
    echo -e "${YELLOW}Testing indexer image before deployment...${NC}"
    cd ..
    cd indexer
    if [ -f "run-container.sh" ]; then
        ./run-container.sh --test --custom-image "$INDEX_IMAGE"
        if [ $? -ne 0 ]; then
            echo -e "${RED}Image test failed! Aborting deployment.${NC}"
            exit 1
        fi
        echo -e "${GREEN}Image test successful!${NC}"
    else
        echo -e "${YELLOW}Warning: run-container.sh not found, skipping test.${NC}"
    fi
    cd ../docker
fi

# Create deployment environment file for variable substitution
echo -e "${YELLOW}Creating deployment configuration...${NC}"
cat > .env.swarm.deploy <<EOF
# Environment: $ENVIRONMENT
# Generated: $(date)
INDEXER_IMAGE=$INDEX_IMAGE
APP_IMAGE=$APP_IMAGE
APP_REPLICAS=$APP_REPLICAS
APP_PORT=$APP_PORT

# Database settings
RDS_HOSTNAME=${RDS_HOSTNAME:-db-host}
RDS_PORT=${RDS_PORT:-3306}
RDS_USER=${RDS_USER:-btc_stamps}
RDS_DATABASE=${RDS_DATABASE:-btc_stamps}

# Bitcoin node settings
RPC_IP=${RPC_IP:-bitcoin-node}
RPC_PORT=${RPC_PORT:-8332}
RPC_USER=${RPC_USER:-bitcoinrpc}

# Other settings
DOMAINNAME=${DOMAINNAME:-stampchain.io}
BACKEND_POLL_INTERVAL=${BACKEND_POLL_INTERVAL:-0.5}
STORE_FILES=${STORE_FILES:-true}
USE_ASYNC_UPLOADS=${USE_ASYNC_UPLOADS:-true}

# AWS settings
AWS_ACCESS_KEY_ID=${AWS_ACCESS_KEY_ID:-}
AWS_S3_BUCKETNAME=${AWS_S3_BUCKETNAME:-stamps}
AWS_S3_IMAGE_DIR=${AWS_S3_IMAGE_DIR:-images}
AWS_CLOUDFRONT_DISTRIBUTION_ID=${AWS_CLOUDFRONT_DISTRIBUTION_ID:-}

# Debug settings
DEBUG=${DEBUG:-false}
DEBUG_VALIDATION=${DEBUG_VALIDATION:-false}
DEBUG_PROFILING=${DEBUG_PROFILING:-false}
EOF

# Check if secrets exist in the swarm, create them if missing
echo -e "${YELLOW}Checking required secrets...${NC}"
required_secrets=("rpc_password" "aws_secret_key" "rds_password")
existing_secrets=$(docker secret ls --format "{{.Name}}")

for secret in "${required_secrets[@]}"; do
    if ! echo "$existing_secrets" | grep -q "^$secret$"; then
        echo -e "${YELLOW}Secret '$secret' not found in swarm.${NC}"
        echo -e "${YELLOW}Please create this secret:${NC}"
        echo -e "${GREEN}Example: echo \"my-secret-value\" | docker secret create $secret -${NC}"
        exit 1
    fi
done

# Deploy to swarm
echo -e "${YELLOW}Deploying to Docker Swarm...${NC}"
docker stack deploy -c docker-compose.swarm.yml --with-registry-auth --env-file .env.swarm.deploy "$STACK_NAME"

# Verify deployment
echo -e "${YELLOW}Verifying deployment...${NC}"
sleep 5
docker stack services "$STACK_NAME"

echo
echo -e "${GREEN}===========================================${NC}"
echo -e "${GREEN}   Deployment completed successfully!     ${NC}"
echo -e "${GREEN}===========================================${NC}"
echo
echo -e "${YELLOW}To view service logs:${NC}"
echo -e "${GREEN}docker service logs ${STACK_NAME}_indexer${NC}"
echo -e "${GREEN}docker service logs ${STACK_NAME}_app${NC}"
echo
echo -e "${YELLOW}To check service status:${NC}"
echo -e "${GREEN}docker stack ps $STACK_NAME${NC}"
echo 
echo -e "${YELLOW}To remove the stack:${NC}"
echo -e "${GREEN}docker stack rm $STACK_NAME${NC}"