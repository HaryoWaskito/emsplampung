#!/bin/bash

# Simple deployment script - just fill in your server details and run!
# This is the easiest way to deploy to your remote server

# ?? CONFIGURATION - UPDATE THESE VALUES
SERVER_IP="103.127.134.226"              # e.g., "203.0.113.1" or "waskito.my.id"
SERVER_USER="waskito"            # e.g., "ubuntu", "root", "centos"
SSH_KEY="~/.ssh/id_rsa"                # e.g., "~/.ssh/id_rsa" (leave empty for default)

# Advanced settings (usually don't need to change)
DEPLOY_PATH="/opt/ocpi-version-module"

# Colors for pretty output
GREEN='\033[0;32m'
BLUE='\033[0;34m'
RED='\033[0;31m'
YELLOW='\033[1;33m'
NC='\033[0m'

echo -e "${BLUE}?? OCPI Version Module - Simple Remote Deployment${NC}"
echo "=================================================="

# Check if configuration is filled
if [[ -z "$SERVER_IP" || -z "$SERVER_USER" ]]; then
    echo -e "${RED}? Configuration Required!${NC}"
    echo ""
    echo "Please edit this script and fill in:"
    echo "  SERVER_IP=\"your-server-ip-or-domain\""
    echo "  SERVER_USER=\"your-ssh-username\""
    echo "  SSH_KEY=\"path-to-your-ssh-key\" (optional)"
    echo ""
    echo "Example:"
    echo "  SERVER_IP=\"203.0.113.1\""
    echo "  SERVER_USER=\"ubuntu\""
    echo "  SSH_KEY=\"~/.ssh/id_rsa\""
    exit 1
fi

# Build SSH command
if [[ -n "$SSH_KEY" ]]; then
    SSH_CMD="ssh -i $SSH_KEY"
    SCP_CMD="scp -i $SSH_KEY"
else
    SSH_CMD="ssh"
    SCP_CMD="scp"
fi

echo -e "${BLUE}?? Deployment Configuration:${NC}"
echo "  Server: $SERVER_USER@$SERVER_IP"
echo "  Path: $DEPLOY_PATH"
echo "  SSH Key: ${SSH_KEY:-"default"}"
echo ""

# Test SSH connection
echo -e "${BLUE}?? Testing SSH connection...${NC}"
if $SSH_CMD -o ConnectTimeout=10 $SERVER_USER@$SERVER_IP "echo 'Connection OK'" >/dev/null 2>&1; then
    echo -e "${GREEN}? SSH connection successful${NC}"
else
    echo -e "${RED}? Cannot connect to server!${NC}"
    echo ""
    echo "Please check:"
    echo "  1. Server IP/domain is correct"
    echo "  2. SSH service is running"
    echo "  3. SSH key is correct"
    echo "  4. User has access"
    echo ""
    echo "Test manually: $SSH_CMD $SERVER_USER@$SERVER_IP"
    exit 1
fi

# Create remote directory
echo -e "${BLUE}?? Creating remote directory...${NC}"
$SSH_CMD $SERVER_USER@$SERVER_IP "sudo mkdir -p $DEPLOY_PATH && sudo chown \$USER:\$USER $DEPLOY_PATH"

# Create deployment package
echo -e "${BLUE}?? Creating deployment package...${NC}"
tar czf deploy-package.tar.gz \
    Program.cs \
    OcpiVersionModule.csproj \
    appsettings.json \
    Dockerfile \
    Caddyfile \
    docker-compose.yml \
    deploy.sh \
    setup-podman.sh 2>/dev/null || {
    echo -e "${RED}? Failed to create package. Missing files?${NC}"
    echo ""
    echo "Required files:"
    echo "  - Program.cs"
    echo "  - OcpiVersionModule.csproj"
    echo "  - appsettings.json"
    echo "  - Dockerfile"
    echo "  - Caddyfile"
    echo "  - docker-compose.yml"
    echo "  - deploy.sh"
    echo "  - setup-podman.sh"
    exit 1
}

# Transfer package
echo -e "${BLUE}?? Transferring files to server...${NC}"
$SCP_CMD deploy-package.tar.gz $SERVER_USER@$SERVER_IP:$DEPLOY_PATH/

# Extract and setup
echo -e "${BLUE}?? Extracting and setting up on server...${NC}"
$SSH_CMD $SERVER_USER@$SERVER_IP "
    cd $DEPLOY_PATH && 
    tar xzf deploy-package.tar.gz && 
    rm deploy-package.tar.gz && 
    chmod +x *.sh
"

# Setup Podman if needed
echo -e "${BLUE}?? Setting up Podman on server...${NC}"
if ! $SSH_CMD $SERVER_USER@$SERVER_IP "command -v podman >/dev/null 2>&1"; then
    echo -e "${YELLOW}??  Installing Podman...${NC}"
    $SSH_CMD $SERVER_USER@$SERVER_IP "cd $DEPLOY_PATH && ./setup-podman.sh"
else
    echo -e "${GREEN}? Podman already installed${NC}"
fi

# Deploy application
echo -e "${BLUE}?? Deploying application...${NC}"
$SSH_CMD $SERVER_USER@$SERVER_IP "cd $DEPLOY_PATH && ./deploy.sh"

# Verify deployment
echo -e "${BLUE}?? Verifying deployment...${NC}"
sleep 10

if $SSH_CMD $SERVER_USER@$SERVER_IP "podman ps --format '{{.Names}}' | grep -q 'ocpi-version-module\|caddy-proxy'"; then
    echo ""
    echo -e "${GREEN}?? DEPLOYMENT SUCCESSFUL!${NC}"
    echo "================================="
    echo ""
    echo -e "${GREEN}?? Your OCPI API is now live at:${NC}"
    echo "  ?? https://$SERVER_IP/versions"
    echo "  ?? https://$SERVER_IP/versions/2.2.1"
    echo "  ??  https://$SERVER_IP/health"
    echo ""
    echo -e "${BLUE}???  Management Commands:${NC}"
    echo "  SSH to server:    $SSH_CMD $SERVER_USER@$SERVER_IP"
    echo "  View containers:  $SSH_CMD $SERVER_USER@$SERVER_IP 'podman ps'"
    echo "  View API logs:    $SSH_CMD $SERVER_USER@$SERVER_IP 'podman logs -f ocpi-version-module'"
    echo "  View Caddy logs:  $SSH_CMD $SERVER_USER@$SERVER_IP 'podman logs -f caddy-proxy'"
    echo "  Stop services:    $SSH_CMD $SERVER_USER@$SERVER_IP 'cd $DEPLOY_PATH && podman-compose down'"
    echo ""
    
    # Test the API
    echo -e "${BLUE}?? Testing API endpoints...${NC}"
    if curl -f -s -k "https://$SERVER_IP/health" >/dev/null; then
        echo -e "${GREEN}? Health endpoint responding${NC}"
    else
        echo -e "${YELLOW}??  Health endpoint test failed (SSL might still be setting up)${NC}"
    fi
    
    echo ""
    echo -e "${GREEN}?? SSL certificates will be automatically obtained by Caddy${NC}"
    echo -e "${BLUE}?? Make sure your domain points to this server IP for HTTPS to work${NC}"
    
else
    echo ""
    echo -e "${RED}? DEPLOYMENT FAILED!${NC}"
    echo "======================"
    echo ""
    echo -e "${YELLOW}?? Troubleshooting steps:${NC}"
    echo "  1. Check container logs:"
    echo "     $SSH_CMD $SERVER_USER@$SERVER_IP 'podman logs ocpi-version-module'"
    echo "     $SSH_CMD $SERVER_USER@$SERVER_IP 'podman logs caddy-proxy'"
    echo ""
    echo "  2. Check container status:"
    echo "     $SSH_CMD $SERVER_USER@$SERVER_IP 'podman ps -a'"
    echo ""
    echo "  3. Try manual deployment:"
    echo "     $SSH_CMD $SERVER_USER@$SERVER_IP"
    echo "     cd $DEPLOY_PATH"
    echo "     ./deploy.sh"
    exit 1
fi

# Cleanup
rm -f deploy-package.tar.gz

echo ""
echo -e "${GREEN}? Deployment completed successfully!${NC}"