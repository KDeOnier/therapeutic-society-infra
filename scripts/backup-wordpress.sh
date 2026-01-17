#!/bin/bash
# ═══════════════════════════════════════════════════════════════════
# WordPress Backup Script
# Version: 1.0.0
# 
# Usage: ./backup-wordpress.sh [destination]
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

# Defaults (can be overridden by .env)
WORDPRESS_VM_IP="${WORDPRESS_VM_IP:-192.168.86.214}"
BACKUP_DESTINATION="${1:-${BACKUP_DESTINATION:-$PROJECT_ROOT/backups}}"
BACKUP_RETENTION_DAYS="${BACKUP_RETENTION_DAYS:-30}"
TIMESTAMP=$(date +%Y%m%d_%H%M%S)
BACKUP_NAME="wordpress_backup_${TIMESTAMP}"

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
log "Starting WordPress backup..."
log "Target VM: $WORDPRESS_VM_IP"
log "Backup destination: $BACKUP_DESTINATION"

# Create backup directory if it doesn't exist
mkdir -p "$BACKUP_DESTINATION"

# Test SSH connectivity
if ! ssh -o ConnectTimeout=5 -o BatchMode=yes "root@$WORDPRESS_VM_IP" exit 2>/dev/null; then
    error "Cannot connect to WordPress VM at $WORDPRESS_VM_IP"
fi

# ─────────────────────────────────────────────────────────────────────
# Backup Process
# ─────────────────────────────────────────────────────────────────────
log "Creating backup on remote server..."

# Run backup commands on WordPress VM
ssh "root@$WORDPRESS_VM_IP" bash << 'REMOTE_SCRIPT'
set -euo pipefail

TIMESTAMP=$(date +%Y%m%d_%H%M%S)
BACKUP_DIR="/tmp/wp_backup_${TIMESTAMP}"
mkdir -p "$BACKUP_DIR"

echo "Backing up WordPress files..."
tar -czf "$BACKUP_DIR/wordpress_files.tar.gz" -C /var/www wordpress

echo "Backing up database..."
# Get DB credentials from wp-config.php
DB_NAME=$(grep "DB_NAME" /var/www/wordpress/wp-config.php | cut -d "'" -f 4)
DB_USER=$(grep "DB_USER" /var/www/wordpress/wp-config.php | cut -d "'" -f 4)
DB_PASS=$(grep "DB_PASSWORD" /var/www/wordpress/wp-config.php | cut -d "'" -f 4)

mysqldump -u"$DB_USER" -p"$DB_PASS" "$DB_NAME" | gzip > "$BACKUP_DIR/wordpress_db.sql.gz"

echo "Creating final archive..."
tar -czf "/tmp/wordpress_backup_${TIMESTAMP}.tar.gz" -C "$BACKUP_DIR" .

# Cleanup temp directory
rm -rf "$BACKUP_DIR"

echo "/tmp/wordpress_backup_${TIMESTAMP}.tar.gz"
REMOTE_SCRIPT

# Get the backup filename from remote
REMOTE_BACKUP=$(ssh "root@$WORDPRESS_VM_IP" "ls -t /tmp/wordpress_backup_*.tar.gz | head -1")

log "Downloading backup: $REMOTE_BACKUP"
scp "root@$WORDPRESS_VM_IP:$REMOTE_BACKUP" "$BACKUP_DESTINATION/$BACKUP_NAME.tar.gz"

# Cleanup remote backup
ssh "root@$WORDPRESS_VM_IP" "rm -f $REMOTE_BACKUP"

# ─────────────────────────────────────────────────────────────────────
# Cleanup Old Backups
# ─────────────────────────────────────────────────────────────────────
log "Cleaning up backups older than $BACKUP_RETENTION_DAYS days..."
find "$BACKUP_DESTINATION" -name "wordpress_backup_*.tar.gz" -mtime +$BACKUP_RETENTION_DAYS -delete 2>/dev/null || true

# ─────────────────────────────────────────────────────────────────────
# Summary
# ─────────────────────────────────────────────────────────────────────
BACKUP_SIZE=$(du -h "$BACKUP_DESTINATION/$BACKUP_NAME.tar.gz" | cut -f1)
log "Backup completed successfully!"
log "  File: $BACKUP_DESTINATION/$BACKUP_NAME.tar.gz"
log "  Size: $BACKUP_SIZE"
