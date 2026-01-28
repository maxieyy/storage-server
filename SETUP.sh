#!/bin/bash

# Automated setup script for Storage Server
# This script automates the installation process

set -e

echo "🚀 Starting Storage Server Setup..."
echo ""

# Check if running as root
if [ "$EUID" -ne 0 ]; then
    echo "❌ Please run as root (use: sudo bash SETUP.sh)"
    exit 1
fi

# Get server details
read -p "Enter subdomain (e.g., server2.devmaxwell.site): " SUBDOMAIN
read -p "Enter server IP address: " SERVER_IP

echo ""
echo "Setting up storage server for:"
echo "  Subdomain: $SUBDOMAIN"
echo "  IP: $SERVER_IP"
echo ""
read -p "Continue? (y/n) " -n 1 -r
echo
if [[ ! $REPLY =~ ^[Yy]$ ]]; then
    exit 1
fi

# Update system
echo "📦 Updating system packages..."
apt update && apt upgrade -y

# Install Node.js if not present
if ! command -v node &> /dev/null; then
    echo "📥 Installing Node.js 20..."
    curl -fsSL https://deb.nodesource.com/setup_20.x | bash -
    apt install -y nodejs
else
    echo "✓ Node.js already installed: $(node --version)"
fi

# Install PM2 if not present
if ! command -v pm2 &> /dev/null; then
    echo "📥 Installing PM2..."
    npm install -g pm2
else
    echo "✓ PM2 already installed"
fi

# Install Nginx if not present
if ! command -v nginx &> /dev/null; then
    echo "📥 Installing Nginx..."
    apt install -y nginx
    systemctl enable nginx
    systemctl start nginx
else
    echo "✓ Nginx already installed"
fi

# Create storage directories
echo "📁 Creating storage directories..."
mkdir -p /var/media-storage/uploads
chmod -R 755 /var/media-storage

# Install application dependencies
echo "📦 Installing application dependencies..."
npm install

# Configure Nginx
echo "⚙️  Configuring Nginx..."
cat > /etc/nginx/sites-available/storage-node <<EOF
server {
    listen 80;
    server_name $SUBDOMAIN;

    client_max_body_size 2G;

    location / {
        proxy_pass http://localhost:3001;
        proxy_http_version 1.1;
        proxy_set_header Upgrade \$http_upgrade;
        proxy_set_header Connection 'upgrade';
        proxy_set_header Host \$host;
        proxy_cache_bypass \$http_upgrade;
        proxy_set_header X-Real-IP \$remote_addr;
        proxy_set_header X-Forwarded-For \$proxy_add_x_forwarded_for;
        
        proxy_connect_timeout 600s;
        proxy_send_timeout 600s;
        proxy_read_timeout 600s;
    }
}
EOF

# Enable site
ln -sf /etc/nginx/sites-available/storage-node /etc/nginx/sites-enabled/
rm -f /etc/nginx/sites-enabled/default
nginx -t && systemctl reload nginx

# Start application with PM2
echo "🚀 Starting storage server..."
pm2 delete storage-node 2>/dev/null || true
pm2 start server.js --name storage-node
pm2 save
pm2 startup

echo ""
echo "✅ Storage server setup complete!"
echo ""
echo "Next steps:"
echo "1. Install SSL: sudo certbot --nginx -d $SUBDOMAIN"
echo "2. Test health: curl http://$SERVER_IP:3001/health"
echo "3. Add server to main dashboard at https://server1.devmaxwell.site"
echo ""
echo "Server details:"
echo "  - IP: $SERVER_IP"
echo "  - Subdomain: $SUBDOMAIN"
echo "  - Port: 3001"
echo "  - Storage: /var/media-storage/uploads"
echo ""
echo "Useful commands:"
echo "  pm2 logs storage-node    # View logs"
echo "  pm2 restart storage-node # Restart"
echo "  pm2 status              # Check status"
echo ""
