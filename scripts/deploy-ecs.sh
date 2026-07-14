#!/usr/bin/env bash
set -euo pipefail

DEPLOY_HOST="${DEPLOY_HOST:-39.105.41.7}"
DEPLOY_USER="${DEPLOY_USER:-root}"
DEPLOY_KEY="${DEPLOY_KEY:-}"
REMOTE_DIR="${REMOTE_DIR:-/var/www/react-redux-realworld}"
REMOTE_ARCHIVE="/tmp/react-redux-realworld-build.tar.gz"
LOCAL_ARCHIVE="/tmp/react-redux-realworld-build.tar.gz"
LOCAL_NGINX_CONF="deploy/ecs-nginx.conf"
REMOTE_NGINX_CONF="/etc/nginx/sites-available/react-redux-realworld"
REMOTE_NGINX_ENABLED="/etc/nginx/sites-enabled/react-redux-realworld"
SSH_CONTROL_PATH="${SSH_CONTROL_PATH:-/tmp/react-redux-realworld-ssh-%r@%h:%p}"
SSH_OPTS=(
  -o ControlMaster=auto
  -o ControlPersist=10m
  -o ControlPath="$SSH_CONTROL_PATH"
)

if [[ -n "$DEPLOY_KEY" ]]; then
  SSH_OPTS+=(-i "$DEPLOY_KEY")
fi

echo "==> Building React app"
npm run build

echo "==> Packaging build/"
tar -czf "$LOCAL_ARCHIVE" -C build .

echo "==> Preparing ECS: ${DEPLOY_USER}@${DEPLOY_HOST}"
ssh "${SSH_OPTS[@]}" "${DEPLOY_USER}@${DEPLOY_HOST}" "
  set -e
  if command -v apt-get >/dev/null 2>&1; then
    apt-get update
    DEBIAN_FRONTEND=noninteractive apt-get install -y nginx ca-certificates
  elif command -v yum >/dev/null 2>&1; then
    yum install -y nginx ca-certificates
  else
    echo 'Unsupported Linux distribution: apt-get/yum not found' >&2
    exit 1
  fi
  mkdir -p '${REMOTE_DIR}/html'
"

echo "==> Uploading build archive"
scp "${SSH_OPTS[@]}" "$LOCAL_ARCHIVE" "${DEPLOY_USER}@${DEPLOY_HOST}:${REMOTE_ARCHIVE}"

echo "==> Uploading Nginx config"
scp "${SSH_OPTS[@]}" "$LOCAL_NGINX_CONF" "${DEPLOY_USER}@${DEPLOY_HOST}:/tmp/react-redux-realworld.nginx.conf"

echo "==> Installing files and reloading Nginx"
ssh "${SSH_OPTS[@]}" "${DEPLOY_USER}@${DEPLOY_HOST}" "
  set -e
  rm -rf '${REMOTE_DIR}/html'
  mkdir -p '${REMOTE_DIR}/html'
  tar -xzf '${REMOTE_ARCHIVE}' -C '${REMOTE_DIR}/html'
  mv /tmp/react-redux-realworld.nginx.conf '${REMOTE_NGINX_CONF}'
  ln -sfn '${REMOTE_NGINX_CONF}' '${REMOTE_NGINX_ENABLED}'
  rm -f /etc/nginx/sites-enabled/default
  nginx -t
  if command -v systemctl >/dev/null 2>&1; then
    systemctl enable nginx
    systemctl restart nginx
  else
    service nginx restart
  fi
"

echo "==> Deployment complete"
echo "Open: http://${DEPLOY_HOST}/"
