#!/bin/bash
set -e  # Exit on any error

# Configuration
BRANCH="master"

# Print status function
status() {
    echo "===> $1"
}

# Check if .env exists
if [ ! -f ".env" ]; then
    echo "Error: .env file not found in current directory"
    echo "Please create a .env file with your environment variables:"
    exit 1
fi

# Start deployment
status "Starting deployment process..."

# Pull latest code
status "Fetching latest code..."
git fetch origin
git checkout $BRANCH
git pull origin $BRANCH

# Build frontend (outputs into src/main/resources/static, which mvn then bundles
# into the jar). Requires Node >= 20.19 (Vite 8) - the server runs Node 22.
status "Building frontend..."
( cd frontend && npm ci && npm run build )

# Build application
status "Building application..."
./mvnw clean package -DskipTests

# Stop current containers
status "Stopping current containers..."
docker-compose -f compose-prod.yaml down

# Start new containers
status "Starting new containers..."
docker-compose -f compose-prod.yaml up -d --build

# Show recent logs (bounded so remote-triggered deploys return instead of hanging)
status "Deployment complete! Showing recent logs..."
docker-compose -f compose-prod.yaml logs --tail=80 webapp
