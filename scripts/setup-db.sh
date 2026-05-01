#!/bin/bash
# MongoDB 7 setup — idempotent, non-interactive SSH safe
export DEBIAN_FRONTEND=noninteractive
set -euo pipefail

MONGO_ADMIN_PASS="SiEajuHk67zewcKXOjCYxJ6m"
MONGO_APP_PASS="umC6LP8eju0aJOt1x4Om0Ypb"
MONGO_DB="travelmemory"
MONGO_APP_USER="travelmemory_user"

echo "==> [1/8] System update"
sudo apt-get update -y -qq

echo "==> [2/8] Install prerequisites"
sudo apt-get install -y -qq gnupg curl ufw

echo "==> [3/8] Add MongoDB 7.0 repo (if not already added)"
if [ ! -f /usr/share/keyrings/mongodb-server-7.0.gpg ]; then
  curl -fsSL https://www.mongodb.org/static/pgp/server-7.0.asc \
    | sudo gpg --yes --batch --dearmor -o /usr/share/keyrings/mongodb-server-7.0.gpg
fi
echo "deb [ arch=amd64,arm64 signed-by=/usr/share/keyrings/mongodb-server-7.0.gpg ] \
https://repo.mongodb.org/apt/ubuntu jammy/mongodb-org/7.0 multiverse" \
  | sudo tee /etc/apt/sources.list.d/mongodb-org-7.0.list > /dev/null

echo "==> [4/8] Install MongoDB"
sudo apt-get update -y -qq
sudo apt-get install -y -qq mongodb-org

echo "==> [5/8] Configure MongoDB (no auth yet)"
sudo tee /etc/mongod.conf > /dev/null <<'MONGOCFG'
storage:
  dbPath: /var/lib/mongodb
systemLog:
  destination: file
  logAppend: true
  path: /var/log/mongodb/mongod.log
net:
  port: 27017
  bindIp: 0.0.0.0
processManagement:
  timeZoneInfo: /usr/share/zoneinfo
security:
  authorization: disabled
MONGOCFG

sudo systemctl enable mongod
sudo systemctl restart mongod
echo -n "  Waiting for MongoDB"
for i in $(seq 1 30); do
  if mongosh --quiet --eval "db.adminCommand('ping')" >/dev/null 2>&1; then
    echo " ready"
    break
  fi
  echo -n "."
  sleep 3
done

echo "==> [6/8] Create admin user (skip if exists)"
mongosh --quiet --eval "
  var db = db.getSiblingDB('admin');
  if (!db.getUser('admin')) {
    db.createUser({ user: 'admin', pwd: '$MONGO_ADMIN_PASS', roles: [{ role: 'root', db: 'admin' }] });
    print('Created admin user');
  } else { print('Admin user already exists'); }
"

echo "==> [7/8] Enable authentication"
sudo sed -i 's/authorization: disabled/authorization: enabled/' /etc/mongod.conf
sudo systemctl restart mongod
echo -n "  Waiting for MongoDB with auth"
for i in $(seq 1 30); do
  if mongosh --quiet -u admin -p "$MONGO_ADMIN_PASS" \
      --authenticationDatabase admin \
      --eval "db.adminCommand('ping')" >/dev/null 2>&1; then
    echo " ready"
    break
  fi
  echo -n "."
  sleep 3
done

echo "==> [8/8] Create app DB user and configure firewall"
mongosh --quiet -u admin -p "$MONGO_ADMIN_PASS" \
  --authenticationDatabase admin --eval "
  var db = db.getSiblingDB('$MONGO_DB');
  if (!db.getUser('$MONGO_APP_USER')) {
    db.createUser({ user: '$MONGO_APP_USER', pwd: '$MONGO_APP_PASS',
      roles: [{ role: 'readWrite', db: '$MONGO_DB' }] });
    print('App user created');
  } else { print('App user already exists'); }
"

# Firewall
sudo ufw --force reset > /dev/null
sudo ufw default deny incoming > /dev/null
sudo ufw default allow outgoing > /dev/null
sudo ufw allow 22/tcp > /dev/null
sudo ufw allow from 10.0.0.0/16 to any port 27017 proto tcp > /dev/null
sudo ufw --force enable

echo ""
echo "=============================="
echo " MongoDB setup complete!"
echo " DB: $MONGO_DB  User: $MONGO_APP_USER"
echo "=============================="
