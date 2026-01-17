#!/bin/bash
# ═══════════════════════════════════════════════════════════════════
# BookStack Backup Script
# Version: 1.0.0
# 
# Usage: ./backup-bookstack.sh [destination]
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
BOOKSTACK_VM_IP="${BOOKSTACK_VM_IP:-192.168.86.113}"
BACKUP_DESTINATION="${1:-${BACKUP_DESTINATION:-$PROJECT_ROOT/backups}}"
BACKUP_RETENTION_DAYS="${BACKUP_RETENTION_DAYS:-30}"
TIMESTAMP=$(date +%Y%m%d_%H%M%S)
BACKUP_NAME="bookstack_backup_${TIMESTAMP}"

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
log "Starting BookStack backup..."
log "Target VM: $BOOKSTACK_VM_IP"
log "Backup destination: $BACKUP_DESTINATION"

# Create backup directory if it doesn't exist
mkdir -p "$BACKUP_DESTINATION"

# Test SSH connectivity
if ! ssh -o ConnectTimeout=5 -o BatchMode=yes "root@$BOOKSTACK_VM_IP" exit 2>/dev/null; then
    error "Cannot connect to BookStack VM at $BOOKSTACK_VM_IP"
fi

# ─────────────────────────────────────────────────────────────────────
# Backup Process
# ─────────────────────────────────────────────────────────────────────
log "Creating backup on remote server..."

# Run backup commands on BookStack VM
ssh "root@$BOOKSTACK_VM_IP" bash << 'REMOTE_SCRIPT'
set -euo pipefail

TIMESTAMP=$(date +%Y%m%d_%H%M%S)
BACKUP_DIR="/tmp/bs_backup_${TIMESTAMP}"
mkdir -p "$BACKUP_DIR"

echo "Backing up BookStack files..."
tar -czf "$BACKUP_DIR/bookstack_files.tar.gz" -C /var/www bookstack

echo "Backing up database..."
# Get DB credentials from .env
source /var/www/bookstack/.env
DB_DATABASE="${DB_DATABASE:-bookstack}"
DB_USERNAME="${DB_USERNAME:-bookstack}"
DB_PASSWORD="${DB_PASSWORD}"

mysqldump -u"$DB_USERNAME" -p"$DB_PASSWORD" "$DB_DATABASE" | gzip > "$BACKUP_DIR/bookstack_db.sql.gz"

echo "Backing up uploaded files..."
if [[ -d /var/www/bookstack/public/uploads ]]; then
    tar -czf "$BACKUP_DIR/bookstack_uploads.tar.gz" -C /var/www/bookstack/public uploads
fi

if [[ -d /var/www/bookstack/storage/uploads ]]; then
    tar -czf "$BACKUP_DIR/bookstack_storage_uploads.tar.gz" -C /var/www/bookstack/storage uploads
fi

echo "Creating final archive..."
tar -czf "/tmp/bookstack_backup_${TIMESTAMP}.tar.gz" -C "$BACKUP_DIR" .

# Cleanup temp directory
rm -rf "$BACKUP_DIR"

echo "/tmp/bookstack_backup_${TIMESTAMP}.tar.gz"
REMOTE_SCRIPT

# Get the backup filename from remote
REMOTE_BACKUP=$(ssh "root@$BOOKSTACK_VM_IP" "ls -t /tmp/bookstack_backup_*.tar.gz | head -1")

log "Downloading backup: $REMOTE_BACKUP"
scp "root@$BOOKSTACK_VM_IP:$REMOTE_BACKUP" "$BACKUP_DESTINATION/$BACKUP_NAME.tar.gz"

# Cleanup remote backup
ssh "root@$BOOKSTACK_VM_IP" "rm -f $REMOTE_BACKUP"

# ─────────────────────────────────────────────────────────────────────
# Cleanup Old Backups
# ─────────────────────────────────────────────────────────────────────
log "Cleaning up backups older than $BACKUP_RETENTION_DAYS days..."
find "$BACKUP_DESTINATION" -name "bookstack_backup_*.tar.gz" -mtime +$BACKUP_RETENTION_DAYS -delete 2>/dev/null || true

# ─────────────────────────────────────────────────────────────────────
# Summary
# ─────────────────────────────────────────────────────────────────────
BACKUP_SIZE=$(du -h "$BACKUP_DESTINATION/$BACKUP_NAME.tar.gz" | cut -f1)
log "Backup completed successfully!"
log "  File: $BACKUP_DESTINATION/$BACKUP_NAME.tar.gz"
log "  Size: $BACKUP_SIZE"
