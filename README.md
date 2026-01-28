# Storage Server - Installation Guide

## Overview

This is the lightweight storage node server that runs on each worker VPS. It handles:
- File storage and retrieval
- Health status reporting
- Storage capacity monitoring
- File uploads from main server

## Server Specifications

- **VPS IPs**: 156.251.65.275, 156.251.65.215, 156.251.65.251 (or any new VPS)
- **Subdomains**: server2.devmaxwell.site, server3.devmaxwell.site, etc.
- **RAM**: 1GB minimum
- **Storage**: 40GB SSD
- **OS**: Debian/Ubuntu Linux

## Prerequisites

- Root SSH access to your VPS
- Domain configured (e.g., server2.devmaxwell.site → 156.251.65.275)
- Main server already installed and running

## Step-by-Step Installation

### Step 1: Access Your Storage VPS

Replace with your actual IP:
```bash
ssh root@156.251.65.275
```

### Step 2: Update System

```bash
apt update && apt upgrade -y
```

### Step 3: Install Node.js 20

```bash
curl -fsSL https://deb.nodesource.com/setup_20.x | bash -
apt install -y nodejs
```

Verify:
```bash
node --version  # Should show v20.x.x
npm --version
```

### Step 4: Install PM2

```bash
npm install -g pm2
```

### Step 5: Install Nginx

```bash
apt install -y nginx
systemctl enable nginx
systemctl start nginx
```

### Step 6: Upload Storage Server Files

On your **local machine**:

```bash
scp -r storage-server root@156.251.65.275:/root/
```

### Step 7: Install Dependencies

SSH into the VPS:
```bash
cd /root/storage-server
npm install
```

### Step 8: Create Storage Directories

```bash
mkdir -p /var/media-storage/uploads
chmod -R 755 /var/media-storage
```

### Step 9: Configure Nginx

```bash
nano /etc/nginx/sites-available/storage-node
```

Paste this configuration (replace server2.devmaxwell.site with your subdomain):

```nginx
server {
    listen 80;
    server_name server2.devmaxwell.site;

    client_max_body_size 2G;

    location / {
        proxy_pass http://localhost:3001;
        proxy_http_version 1.1;
        proxy_set_header Upgrade $http_upgrade;
        proxy_set_header Connection 'upgrade';
        proxy_set_header Host $host;
        proxy_cache_bypass $http_upgrade;
        proxy_set_header X-Real-IP $remote_addr;
        proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
        
        proxy_connect_timeout 600s;
        proxy_send_timeout 600s;
        proxy_read_timeout 600s;
    }
}
```

Enable the site:
```bash
ln -s /etc/nginx/sites-available/storage-node /etc/nginx/sites-enabled/
rm /etc/nginx/sites-enabled/default  # Remove default
nginx -t
systemctl reload nginx
```

### Step 10: Start Storage Server

```bash
pm2 start server.js --name storage-node
pm2 save
pm2 startup  # Follow the command provided
```

### Step 11: Install SSL Certificate

```bash
apt install -y certbot python3-certbot-nginx
certbot --nginx -d server2.devmaxwell.site
```

Follow prompts and choose to redirect HTTP to HTTPS.

### Step 12: Test Storage Server

Check health endpoint:
```bash
curl https://server2.devmaxwell.site/health
```

You should see:
```json
{
  "status": "healthy",
  "timestamp": "2026-01-29T...",
  "storage": {
    "used": 0,
    "total": 42949672960,
    "available": 42949672960
  }
}
```

### Step 13: Add to Main Dashboard

On the main server dashboard (https://server1.devmaxwell.site):

1. Navigate to **VPS Servers**
2. Click **"Add New Server"**
3. Fill in the form:
   - **Server Name**: Storage Server 2 (or descriptive name)
   - **IP Address**: 156.251.65.275
   - **Subdomain**: server2.devmaxwell.site
   - **Total Storage**: 40 (GB)
   - **Expiry Date**: Set to 30 days from today
4. Click **"Add Server"**

The main server will now:
- Monitor health of this storage node
- Use it for file storage
- Include it in migration options
- Track storage usage

## Installation on Additional Servers

Repeat steps 1-13 for each additional VPS:

**Server 3** (156.251.65.215):
- Use subdomain: server3.devmaxwell.site
- Same process

**Server 4** (156.251.65.251):
- Use subdomain: server4.devmaxwell.site
- Same process

**For any new VPS:**
- Point subdomain to the new IP
- Follow all installation steps
- Add via dashboard

## Useful Commands

### View Logs
```bash
pm2 logs storage-node
```

### Restart Server
```bash
pm2 restart storage-node
```

### Check Status
```bash
pm2 status
```

### Monitor Resources
```bash
pm2 monit
```

### Check Storage Usage
```bash
du -sh /var/media-storage/uploads
df -h
```

### View Stored Files
```bash
ls -lh /var/media-storage/uploads
```

## Troubleshooting

### Server Not Responding

Check if running:
```bash
pm2 status
```

Check logs:
```bash
pm2 logs storage-node --lines 50
```

Restart if needed:
```bash
pm2 restart storage-node
```

### Health Check Fails

Test locally:
```bash
curl http://localhost:3001/health
```

Check Nginx:
```bash
systemctl status nginx
nginx -t
```

Check firewall:
```bash
ufw status
```

### Can't Upload Files

Check permissions:
```bash
ls -la /var/media-storage
chmod -R 755 /var/media-storage
```

Check disk space:
```bash
df -h
```

### SSL Certificate Issues

Renew certificate:
```bash
certbot renew
```

Test renewal:
```bash
certbot renew --dry-run
```

## Security Checklist

- [ ] SSL certificate installed
- [ ] Firewall configured
- [ ] Storage directory permissions set
- [ ] Regular updates scheduled
- [ ] PM2 startup configured

### Configure Firewall

```bash
ufw allow 22/tcp    # SSH
ufw allow 80/tcp    # HTTP
ufw allow 443/tcp   # HTTPS
ufw enable
```

## Monitoring

### Check Health from Main Server

The main server automatically checks health every 5 minutes. You can also:

1. Go to main dashboard
2. Click on **VPS Servers**
3. Find your server
4. Click refresh icon to trigger manual health check

### Local Health Check

```bash
# Simple check
curl https://server2.devmaxwell.site/health

# Detailed check with formatting
curl -s https://server2.devmaxwell.site/health | python3 -m json.tool
```

## Maintenance

### Update System Packages

```bash
apt update && apt upgrade -y
```

### Update Node.js Application

```bash
cd /root/storage-server
git pull  # If using git
npm install
pm2 restart storage-node
```

### Clean Old Files (if needed)

```bash
# List files older than 30 days
find /var/media-storage/uploads -type f -mtime +30

# Delete files older than 30 days (use with caution!)
# find /var/media-storage/uploads -type f -mtime +30 -delete
```

### Before VPS Expiry

If your VPS is expiring:

1. **7 days before**: Main server will show warning
2. **Migrate data**: Use dashboard to migrate to new server
3. **Remove server**: After migration completes, remove from dashboard
4. **Cancel VPS**: Safe to cancel the expiring VPS

## File Structure

```
storage-server/
├── server.js          # Main application
├── package.json       # Dependencies
├── INSTALLATION.md    # This guide
└── SETUP.sh          # Automated setup script
```

## Environment Variables

Storage server uses minimal configuration:

- `PORT`: 3001 (default)
- `STORAGE_PATH`: /var/media-storage (default)

To customize:
```bash
export PORT=3001
export STORAGE_PATH=/var/media-storage
pm2 restart storage-node --update-env
```

## API Endpoints

The storage server provides these endpoints:

- `GET /health` - Health check with storage stats
- `POST /upload` - Upload file (called by main server)
- `GET /files/:id` - Download file
- `DELETE /files/:filename` - Delete file
- `GET /files` - List all files

These are primarily used by the main server, not directly by users.

## Next Steps

After installation:

1. ✅ Storage server is running
2. ✅ Added to main dashboard
3. → Test by uploading a video on main dashboard
4. → Verify file is distributed to this server
5. → Monitor health status on dashboard

## Support

For issues:
1. Check PM2 logs: `pm2 logs storage-node`
2. Check Nginx logs: `/var/log/nginx/error.log`
3. Test health endpoint: `curl http://localhost:3001/health`
4. Check main server can reach this server
