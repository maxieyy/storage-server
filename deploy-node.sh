#!/bin/bash

# Deployment script for storage node VPS servers
# Run this on each worker VPS (156.251.65.275, 156.251.65.215, 156.251.65.251)

set -e

echo "🚀 Deploying Storage Node..."

# Update system
echo "📦 Updating system packages..."
sudo apt update && sudo apt upgrade -y

# Install Node.js
if ! command -v node &> /dev/null; then
    echo "📥 Installing Node.js..."
    curl -fsSL https://deb.nodesource.com/setup_20.x | sudo -E bash -
    sudo apt install -y nodejs
fi

# Install PM2 globally
if ! command -v pm2 &> /dev/null; then
    echo "📥 Installing PM2..."
    sudo npm install -g pm2
fi

# Create storage directories
echo "📁 Creating storage directories..."
sudo mkdir -p /var/media-storage/uploads
sudo chmod -R 755 /var/media-storage

# Navigate to storage-node directory
cd storage-node || exit 1

# Install dependencies
echo "📦 Installing dependencies..."
npm install

# Start storage node with PM2
echo "🚀 Starting storage node..."
pm2 delete storage-node 2>/dev/null || true
pm2 start server.js --name storage-node
pm2 save
pm2 startup

# Install Nginx if not present
if ! command -v nginx &> /dev/null; then
    echo "📥 Installing Nginx..."
    sudo apt install -y nginx
    sudo systemctl enable nginx
fi

echo "✅ Storage node deployment complete!"
echo ""
echo "Next steps:"
echo "1. Set up SSL with: sudo certbot --nginx -d serverX.devmaxwell.site"
echo "2. Add this server to the main dashboard"
echo "3. Access health endpoint at: http://your-server-ip:3001/health"
