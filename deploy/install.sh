#!/usr/bin/env bash
set -euo pipefail

##############################################################################
##  SignalDeck Landing Page — Nginx Installer
##
##  Usage:
##    sudo bash install.sh <domain> [git-repo-url] [cert-path] [key-path]
##
##  Example:
##    sudo bash install.sh example.com https://github.com/you/repo.git
##    sudo bash install.sh example.com "" /etc/ssl/cloudflare/origin.pem /etc/ssl/cloudflare/origin.key
##
##  SSL uses a Cloudflare Origin Certificate. Before running this script:
##    1. Generate an Origin Certificate in Cloudflare Dashboard
##       → SSL/TLS → Origin Server → Create Certificate
##    2. Save the certificate to:   /etc/ssl/cloudflare/origin.pem
##    3. Save the private key to:   /etc/ssl/cloudflare/origin.key
##    4. Set Cloudflare SSL mode to "Full (strict)"
##
##  If no repo URL is given the script assumes it's being run from inside
##  the already-cloned project directory.
##############################################################################

# ─── Colours ──────────────────────────────────────────────────────────────────
GREEN='\033[0;32m'
CYAN='\033[0;36m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m'

ok()   { echo -e "  ${GREEN}✓${NC}  $*"; }
info() { echo -e "  ${CYAN}→${NC}  $*"; }
warn() { echo -e "  ${YELLOW}!${NC}  $*"; }
die()  { echo -e "  ${RED}✗${NC}  $*" >&2; exit 1; }

# ─── Args ─────────────────────────────────────────────────────────────────────
if [[ $# -lt 1 ]]; then
    die "Usage: sudo bash install.sh <domain> [git-repo-url] [cert-path] [key-path]"
fi

DOMAIN="${1}"
GIT_REPO="${2:-}"
SSL_CERT="${3:-/etc/ssl/cloudflare/origin.pem}"
SSL_KEY="${4:-/etc/ssl/cloudflare/origin.key}"

APP_USER="www-cypress-site"
APP_DIR="/var/www/cypress-dashboard-site"
NGINX_AVAILABLE="/etc/nginx/sites-available/cypress-dashboard-site"
NGINX_ENABLED="/etc/nginx/sites-enabled/cypress-dashboard-site"

# ─── Root check ───────────────────────────────────────────────────────────────
if [[ $EUID -ne 0 ]]; then
    die "This script must be run as root (use sudo)"
fi

echo ""
echo -e "${CYAN}╔══════════════════════════════════════════════════════╗${NC}"
echo -e "${CYAN}║   SignalDeck Site — Installer                        ║${NC}"
echo -e "${CYAN}╚══════════════════════════════════════════════════════╝${NC}"
echo ""
info "Domain    : ${DOMAIN}"
info "Directory : ${APP_DIR}"
info "User      : ${APP_USER}"
info "SSL cert  : ${SSL_CERT}"
info "SSL key   : ${SSL_KEY}"
echo ""

# ─── Check dependencies ───────────────────────────────────────────────────────
info "Checking dependencies..."

for cmd in nginx node npm; do
    if ! command -v "$cmd" &>/dev/null; then
        die "'$cmd' is not installed. Please install it and re-run."
    fi
    ok "$cmd found ($(${cmd} --version 2>&1 | head -1))"
done

# ─── Verify Cloudflare Origin Certificate ─────────────────────────────────────
info "Checking Cloudflare Origin Certificate..."

if [[ ! -f "$SSL_CERT" ]]; then
    echo ""
    die "Certificate not found at: ${SSL_CERT}

  Generate one in Cloudflare Dashboard:
    SSL/TLS → Origin Server → Create Certificate

  Then save the files:
    Certificate → ${SSL_CERT}
    Private key → ${SSL_KEY}

  And set Cloudflare SSL/TLS mode to: Full (strict)"
fi

if [[ ! -f "$SSL_KEY" ]]; then
    die "Private key not found at: ${SSL_KEY}"
fi

# Verify the key is not world-readable
chmod 600 "$SSL_KEY"
ok "Certificate: ${SSL_CERT}"
ok "Private key: ${SSL_KEY}"

# ─── System user ──────────────────────────────────────────────────────────────
info "Creating system user '${APP_USER}'..."
if id "$APP_USER" &>/dev/null; then
    ok "User '${APP_USER}' already exists"
else
    useradd \
        --system \
        --no-create-home \
        --shell /usr/sbin/nologin \
        --comment "Cypress Site Static Serve" \
        "$APP_USER"
    ok "User '${APP_USER}' created"
fi

# Add www-data to app user's group so Nginx can read the files
usermod -aG "$APP_USER" www-data 2>/dev/null || true

# ─── Application directory ────────────────────────────────────────────────────
info "Setting up application directory..."
mkdir -p "$APP_DIR"

if [[ -n "$GIT_REPO" ]]; then
    info "Cloning from ${GIT_REPO}..."
    if [[ -d "${APP_DIR}/.git" ]]; then
        warn "Directory already contains a git repo — pulling latest instead"
        git -C "$APP_DIR" pull
    else
        git clone "$GIT_REPO" "$APP_DIR"
    fi
else
    SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
    PROJECT_DIR="$(dirname "$SCRIPT_DIR")"
    info "No repo URL given — copying from ${PROJECT_DIR}..."
    rsync -a \
        --exclude='.git' \
        --exclude='node_modules' \
        --exclude='public/css/style.css' \
        "${PROJECT_DIR}/" "${APP_DIR}/"
fi

ok "Files in place"

# ─── Build ────────────────────────────────────────────────────────────────────
info "Installing npm dependencies..."
cd "$APP_DIR"
npm install --prefer-offline 2>&1 | sed 's/^/    /'
chmod +x "${APP_DIR}/node_modules/.bin/"*
ok "npm install complete"

info "Building Tailwind CSS..."
npm run build 2>&1 | sed 's/^/    /'
ok "CSS built"

# ─── Permissions ──────────────────────────────────────────────────────────────
info "Setting permissions..."
chown -R "${APP_USER}:www-data" "$APP_DIR"
find "$APP_DIR" -type d -exec chmod 750 {} \;
find "$APP_DIR" -type f -exec chmod 640 {} \;
ok "Permissions set"

# ─── Nginx config ─────────────────────────────────────────────────────────────
info "Writing Nginx configuration..."

cat > "$NGINX_AVAILABLE" <<NGINX
##
## Generated by install.sh on $(date -u '+%Y-%m-%d %H:%M UTC')
## Domain:   ${DOMAIN}
## SSL:      Cloudflare Origin Certificate
##

# Redirect HTTP → HTTPS
# Cloudflare will only send HTTPS traffic, but this catches anything direct.
server {
    listen 80;
    listen [::]:80;
    server_name ${DOMAIN};
    return 301 https://\$host\$request_uri;
}

server {
    listen 443 ssl http2;
    listen [::]:443 ssl http2;
    server_name ${DOMAIN};

    # Cloudflare Origin Certificate
    ssl_certificate     ${SSL_CERT};
    ssl_certificate_key ${SSL_KEY};

    # Strong TLS settings
    ssl_protocols       TLSv1.2 TLSv1.3;
    ssl_ciphers         ECDHE-ECDSA-AES128-GCM-SHA256:ECDHE-RSA-AES128-GCM-SHA256:ECDHE-ECDSA-AES256-GCM-SHA384:ECDHE-RSA-AES256-GCM-SHA384:ECDHE-ECDSA-CHACHA20-POLY1305:ECDHE-RSA-CHACHA20-POLY1305;
    ssl_prefer_server_ciphers off;
    ssl_session_cache   shared:SSL:10m;
    ssl_session_timeout 1d;

    root  ${APP_DIR}/public;
    index index.html;

    access_log /var/log/nginx/cypress-site.access.log;
    error_log  /var/log/nginx/cypress-site.error.log warn;

    location / {
        try_files \$uri \$uri/ /index.html;
    }

    # Long-lived cache for content-hashed assets
    location ~* \.(css|js|woff|woff2|ttf|eot)\$ {
        expires 1y;
        add_header Cache-Control "public, immutable";
        access_log off;
    }

    location ~* \.(jpg|jpeg|png|gif|ico|svg|webp)\$ {
        expires 30d;
        add_header Cache-Control "public";
        access_log off;
    }

    add_header X-Frame-Options        "SAMEORIGIN"                   always;
    add_header X-Content-Type-Options "nosniff"                      always;
    add_header Referrer-Policy        "strict-origin-when-cross-origin" always;

    gzip on;
    gzip_vary on;
    gzip_types text/plain text/css application/javascript image/svg+xml;
    gzip_min_length 1024;
}
NGINX

ok "Nginx config written to ${NGINX_AVAILABLE}"

# Enable site
ln -sf "$NGINX_AVAILABLE" "$NGINX_ENABLED"
ok "Site enabled"

# Test config
info "Testing Nginx configuration..."
if nginx -t 2>&1; then
    ok "Nginx config valid"
else
    die "Nginx config test failed — check the output above"
fi

# Reload
info "Reloading Nginx..."
systemctl reload nginx
ok "Nginx reloaded"

# ─── Done ─────────────────────────────────────────────────────────────────────
echo ""
echo -e "${GREEN}╔══════════════════════════════════════════════════════╗${NC}"
echo -e "${GREEN}║   Installation complete!                             ║${NC}"
echo -e "${GREEN}╚══════════════════════════════════════════════════════╝${NC}"
echo ""
echo -e "  ${GREEN}→${NC}  https://${DOMAIN}"
echo ""
echo -e "  Reminder: Cloudflare SSL/TLS mode must be set to ${CYAN}Full (strict)${NC}"
echo -e "  in your Cloudflare dashboard for the Origin Certificate to work."
echo ""
echo -e "  To rebuild CSS after changes:"
echo -e "    cd ${APP_DIR} && npm run build"
echo ""
