#!/bin/bash
# Web server setup: Node.js 18, PM2, nginx, TravelMemory MERN app
set -euo pipefail

DB_PRIVATE_IP="10.0.2.5"
MONGO_DB="travelmemory"
MONGO_APP_USER="travelmemory_user"
MONGO_APP_PASS="umC6LP8eju0aJOt1x4Om0Ypb"
BACKEND_PORT="3001"
APP_DIR="/opt/travelmemory"
REPO_URL="https://github.com/UnpredictablePrashant/TravelMemory.git"
WEB_PUBLIC_IP=$(curl -s https://checkip.amazonaws.com)

echo "==> [1/10] System update"
sudo apt-get update -y -qq

echo "==> [2/10] Install system packages"
sudo apt-get install -y -qq curl git nginx ufw build-essential

echo "==> [3/10] Install Node.js 18.x"
curl -fsSL https://deb.nodesource.com/setup_18.x | sudo -E bash -
sudo apt-get install -y -qq nodejs
node --version

echo "==> [4/10] Install PM2"
sudo npm install -g pm2 --quiet

echo "==> [5/10] Clone TravelMemory repository"
sudo mkdir -p "$APP_DIR"
sudo chown ubuntu:ubuntu "$APP_DIR"
if [ -d "$APP_DIR/.git" ]; then
  cd "$APP_DIR" && git pull
else
  git clone "$REPO_URL" "$APP_DIR"
fi

echo "==> [6/10] Install backend dependencies and configure"
cd "$APP_DIR/backend"
npm install --quiet

cat > "$APP_DIR/backend/.env" <<ENV
PORT=$BACKEND_PORT
MONGO_URI=mongodb://$MONGO_APP_USER:$MONGO_APP_PASS@$DB_PRIVATE_IP:27017/$MONGO_DB
ENV
echo "  Backend .env written"

echo "==> [7/10] Install frontend dependencies and build"
cd "$APP_DIR/frontend"
npm install --quiet

cat > "$APP_DIR/frontend/.env" <<ENV
REACT_APP_BACKEND_URL=http://$WEB_PUBLIC_IP/api
ENV
echo "  Frontend .env written (backend URL: http://$WEB_PUBLIC_IP/api)"

CI=false npm run build
echo "  React build complete"

echo "==> [8/10] Start backend with PM2"
pm2 delete travelmemory-backend 2>/dev/null || true
pm2 start "$APP_DIR/backend/index.js" --name travelmemory-backend --cwd "$APP_DIR/backend"
pm2 save
sudo env PATH="$PATH:/usr/bin" pm2 startup systemd -u ubuntu --hp /home/ubuntu | tail -1 | sudo bash || true

echo "==> [9/10] Configure nginx"
sudo tee /etc/nginx/sites-available/travelmemory > /dev/null <<'NGINX'
server {
    listen 80;
    server_name _;

    root /opt/travelmemory/frontend/build;
    index index.html;

    location / {
        try_files $uri $uri/ /index.html;
    }

    location /api/ {
        proxy_pass         http://127.0.0.1:3001/;
        proxy_http_version 1.1;
        proxy_set_header   Upgrade $http_upgrade;
        proxy_set_header   Connection 'upgrade';
        proxy_set_header   Host $host;
        proxy_set_header   X-Real-IP $remote_addr;
        proxy_set_header   X-Forwarded-For $proxy_add_x_forwarded_for;
        proxy_cache_bypass $http_upgrade;
    }

    gzip on;
    gzip_types text/plain text/css application/json application/javascript text/xml;

    add_header X-Frame-Options "SAMEORIGIN" always;
    add_header X-Content-Type-Options "nosniff" always;
}
NGINX

sudo rm -f /etc/nginx/sites-enabled/default
sudo ln -sf /etc/nginx/sites-available/travelmemory /etc/nginx/sites-enabled/travelmemory
sudo nginx -t
sudo systemctl restart nginx
sudo systemctl enable nginx

echo "==> [10/10] Configure firewall"
sudo ufw allow 22/tcp
sudo ufw allow 80/tcp
sudo ufw allow 443/tcp
sudo ufw --force enable

echo ""
echo "=============================="
echo " Web server setup complete!"
echo " App URL: http://$WEB_PUBLIC_IP"
echo "=============================="
