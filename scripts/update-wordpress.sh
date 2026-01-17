#!/bin/bash
# ═══════════════════════════════════════════════════════════════════
# WordPress Update Script
# Version: 1.0.0
# 
# Usage: ./update-wordpress.sh [--backup]
# ═══════════════════════════════════════════════════════════════════

set -euo pipefail

# ─────────────────────────────────────────────────────────────────────
# Configuration
# ─────────────────────────────────────────────────────────────────────
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(dirname "$SCRIPT_DIR")"

# Load environment variables if .env exists
if [[ -f "$PROJECT_ROOT/.env" ]]; then
    source "$PROJECT_ROOT/.env"
fi

# Defaults
WORDPRESS_VM_IP="${WORDPRESS_VM_IP:-192.168.86.214}"
DO_BACKUP="${1:-}"

# ─────────────────────────────────────────────────────────────────────
# Functions
# ─────────────────────────────────────────────────────────────────────
log() {
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] $1"
}

error() {
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] ERROR: $1" >&2
    exit 1
}

# ─────────────────────────────────────────────────────────────────────
# Pre-flight Checks
# ─────────────────────────────────────────────────────────────────────
log "WordPress Update Script"
log "Target VM: $WORDPRESS_VM_IP"

# Test SSH connectivity
if ! ssh -o ConnectTimeout=5 -o BatchMode=yes "root@$WORDPRESS_VM_IP" exit 2>/dev/null; then
    error "Cannot connect to WordPress VM at $WORDPRESS_VM_IP"
fi

# ─────────────────────────────────────────────────────────────────────
# Optional Backup
# ─────────────────────────────────────────────────────────────────────
if [[ "$DO_BACKUP" == "--backup" ]]; then
    log "Creating backup before update..."
    "$SCRIPT_DIR/backup-wordpress.sh"
    log "Backup completed."
fi

# ─────────────────────────────────────────────────────────────────────
# Update Process
# ─────────────────────────────────────────────────────────────────────
log "Connecting to WordPress VM and running updates..."

ssh "root@$WORDPRESS_VM_IP" bash << 'REMOTE_SCRIPT'
set -euo pipefail

cd /var/www/wordpress

echo "═══════════════════════════════════════════════════════════════"
echo " WordPress Update Process"
echo "═══════════════════════════════════════════════════════════════"

echo ""
echo "Current versions:"
echo "─────────────────────────────────────────────────────────────────"
wp core version --allow-root
echo ""

echo "Checking for core updates..."
echo "─────────────────────────────────────────────────────────────────"
wp core check-update --allow-root || true
echo ""

echo "Updating WordPress core..."
echo "─────────────────────────────────────────────────────────────────"
wp core update --allow-root || echo "Core already up to date"
echo ""

echo "Updating database if needed..."
echo "─────────────────────────────────────────────────────────────────"
wp core update-db --allow-root || true
echo ""

echo "Checking for plugin updates..."
echo "─────────────────────────────────────────────────────────────────"
wp plugin list --update=available --allow-root || echo "All plugins up to date"
echo ""

echo "Updating all plugins..."
echo "─────────────────────────────────────────────────────────────────"
wp plugin update --all --allow-root || echo "Plugins already up to date"
echo ""

echo "Checking for theme updates..."
echo "─────────────────────────────────────────────────────────────────"
wp theme list --update=available --allow-root || echo "All themes up to date"
echo ""

echo "Updating all themes..."
echo "─────────────────────────────────────────────────────────────────"
wp theme update --all --allow-root || echo "Themes already up to date"
echo ""

echo "Clearing cache..."
echo "─────────────────────────────────────────────────────────────────"
wp cache flush --allow-root 2>/dev/null || true
echo ""

echo "═══════════════════════════════════════════════════════════════"
echo " Update Complete!"
echo "═══════════════════════════════════════════════════════════════"
echo ""
echo "Final versions:"
echo "─────────────────────────────────────────────────────────────────"
wp core version --allow-root
echo ""
wp plugin list --allow-root
REMOTE_SCRIPT

log "WordPress update completed successfully!"
log "Please verify the site is working: https://therapeuticsociety.org"
