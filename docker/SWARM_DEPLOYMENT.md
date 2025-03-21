# Docker Swarm Deployment Guide

This guide explains how to deploy Bitcoin Stamps to a Docker Swarm cluster.

## Prerequisites

1. A working Docker Swarm cluster
2. Access to Docker Hub for pulling images
3. Existing MySQL/MariaDB database accessible from the Swarm
4. Docker secrets created for sensitive information

## Required Docker Secrets

The following secrets must be configured in your Docker Swarm:

- `rds_password`: Database password
- `rpc_password`: Bitcoin RPC password
- `aws_secret_key`: AWS secret key for S3 storage (if using S3)

Create these secrets in your swarm if they don't exist:

```bash
echo "your-db-password" | docker secret create rds_password -
echo "your-rpc-password" | docker secret create rpc_password -
echo "your-aws-secret-key" | docker secret create aws_secret_key -
```

## Deployment

Use the provided deployment script:

```bash
# Basic deployment with latest images
./deploy-to-swarm.sh production

# Deployment with specific images and options
./deploy-to-swarm.sh production \
  --stack-name btc-stamps-prod \
  --indexer-image btcstamps/indexer:1.8.26 \
  --app-image btcstamps/app:latest \
  --app-replicas 3 \
  --app-port 8080
```

### Options

- `--stack-name`: The name of the Docker stack (default: btc-stamps)
- `--no-test`: Skip testing the Docker image before deployment
- `--indexer-image`: Specific indexer image to use
- `--app-image`: Specific app image to use
- `--app-replicas`: Number of app replicas to run (default: 2)
- `--app-port`: Port to expose the app on (default: 8080)

### Environment Variables

The deployment script will use environment variables from your shell if available:

- `RDS_HOSTNAME`: Database hostname
- `RDS_PORT`: Database port (default: 3306)
- `RDS_USER`: Database username
- `RDS_DATABASE`: Database name (default: btc_stamps)
- `RPC_IP`: Bitcoin node IP or hostname
- `RPC_PORT`: Bitcoin RPC port (default: 8332)
- `RPC_USER`: Bitcoin RPC username
- `AWS_ACCESS_KEY_ID`: AWS access key ID
- `AWS_S3_BUCKETNAME`: S3 bucket name
- `AWS_S3_IMAGE_DIR`: S3 image directory
- `AWS_CLOUDFRONT_DISTRIBUTION_ID`: Cloudfront distribution ID

You can set these environment variables before running the script:

```bash
export RDS_HOSTNAME=my-db-server.example.com
export RPC_IP=my-btc-node.example.com
./deploy-to-swarm.sh production
```

## Verifying Deployment

Check the status of your deployment:

```bash
# List services in the stack
docker stack services btc-stamps

# Check running tasks
docker stack ps btc-stamps

# View logs
docker service logs btc-stamps_indexer
docker service logs btc-stamps_app
```

## Updating the Deployment

To update your deployment, simply run the deployment script again with updated parameters:

```bash
./deploy-to-swarm.sh production --indexer-image btcstamps/indexer:1.8.26-new
```

## Removing the Deployment

To remove the deployment:

```bash
docker stack rm btc-stamps
```