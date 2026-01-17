#!/bin/bash
# ═══════════════════════════════════════════════════════════════════
# Infrastructure Health Check Script
# Version: 1.0.0
# 
# Usage: ./health-check.sh [--verbose]
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
BOOKSTACK_VM_IP="${BOOKSTACK_VM_IP:-192.168.86.113}"
PFSENSE_LAN_IP="${PFSENSE_LAN_IP:-192.168.86.1}"

VERBOSE="${1:-}"

# URLs to check
URLS=(
    "https://therapeuticsociety.org"
    "https://therapeutic-society.org"
    "https://books.therapeuticsociety.org"
)

# ─────────────────────────────────────────────────────────────────────
# Colors
# ─────────────────────────────────────────────────────────────────────
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# ─────────────────────────────────────────────────────────────────────
# Functions
# ─────────────────────────────────────────────────────────────────────
log_pass() {
    echo -e "${GREEN}[✓]${NC} $1"
}

log_fail() {
    echo -e "${RED}[✗]${NC} $1"
}

log_warn() {
    echo -e "${YELLOW}[!]${NC} $1"
}

log_info() {
    echo -e "[ ] $1"
}

check_ping() {
    local host=$1
    local name=$2
    
    if ping -c 1 -W 2 "$host" &>/dev/null; then
        log_pass "$name ($host) - Ping OK"
        return 0
    else
        log_fail "$name ($host) - Ping FAILED"
        return 1
    fi
}

check_ssh() {
    local host=$1
    local name=$2
    
    if ssh -o ConnectTimeout=5 -o BatchMode=yes "root@$host" exit 2>/dev/null; then
        log_pass "$name ($host) - SSH OK"
        return 0
    else
        log_fail "$name ($host) - SSH FAILED"
        return 1
    fi
}

check_http() {
    local url=$1
    local expected_code="${2:-200}"
    
    local http_code
    http_code=$(curl -s -o /dev/null -w "%{http_code}" --max-time 10 "$url" 2>/dev/null || echo "000")
    
    if [[ "$http_code" == "$expected_code" ]] || [[ "$http_code" == "301" ]] || [[ "$http_code" == "302" ]]; then
        log_pass "$url - HTTP $http_code"
        return 0
    else
        log_fail "$url - HTTP $http_code (expected $expected_code)"
        return 1
    fi
}

check_ssl() {
    local domain=$1
    
    local expiry
    expiry=$(echo | openssl s_client -servername "$domain" -connect "$domain:443" 2>/dev/null | openssl x509 -noout -enddate 2>/dev/null | cut -d= -f2)
    
    if [[ -z "$expiry" ]]; then
        log_fail "$domain - SSL check FAILED"
        return 1
    fi
    
    local expiry_epoch
    expiry_epoch=$(date -d "$expiry" +%s 2>/dev/null || date -j -f "%b %d %T %Y %Z" "$expiry" +%s 2>/dev/null)
    local now_epoch
    now_epoch=$(date +%s)
    local days_left=$(( (expiry_epoch - now_epoch) / 86400 ))
    
    if [[ $days_left -lt 7 ]]; then
        log_fail "$domain - SSL expires in $days_left days!"
        return 1
    elif [[ $days_left -lt 30 ]]; then
        log_warn "$domain - SSL expires in $days_left days"
        return 0
    else
        log_pass "$domain - SSL valid ($days_left days remaining)"
        return 0
    fi
}

check_service() {
    local host=$1
    local service=$2
    
    local status
    status=$(ssh -o ConnectTimeout=5 "root@$host" "systemctl is-active $service" 2>/dev/null || echo "unknown")
    
    if [[ "$status" == "active" ]]; then
        log_pass "$service on $host - Running"
        return 0
    else
        log_fail "$service on $host - $status"
        return 1
    fi
}

# ─────────────────────────────────────────────────────────────────────
# Main Health Checks
# ─────────────────────────────────────────────────────────────────────
echo "═══════════════════════════════════════════════════════════════"
echo " Therapeutic Society Infrastructure Health Check"
echo " $(date)"
echo "═══════════════════════════════════════════════════════════════"
echo ""

FAILURES=0

# ─────────────────────────────────────────────────────────────────────
echo "📡 Network Connectivity"
echo "─────────────────────────────────────────────────────────────────"
check_ping "$PFSENSE_LAN_IP" "pfSense" || ((FAILURES++))
check_ping "$WORDPRESS_VM_IP" "WordPress VM" || ((FAILURES++))
check_ping "$BOOKSTACK_VM_IP" "BookStack VM" || ((FAILURES++))
echo ""

# ─────────────────────────────────────────────────────────────────────
echo "🔐 SSH Access"
echo "─────────────────────────────────────────────────────────────────"
check_ssh "$WORDPRESS_VM_IP" "WordPress VM" || ((FAILURES++))
check_ssh "$BOOKSTACK_VM_IP" "BookStack VM" || ((FAILURES++))
echo ""

# ─────────────────────────────────────────────────────────────────────
echo "🌐 Public URLs"
echo "─────────────────────────────────────────────────────────────────"
for url in "${URLS[@]}"; do
    check_http "$url" || ((FAILURES++))
done
echo ""

# ─────────────────────────────────────────────────────────────────────
echo "🔒 SSL Certificates"
echo "─────────────────────────────────────────────────────────────────"
check_ssl "therapeuticsociety.org" || ((FAILURES++))
check_ssl "therapeutic-society.org" || ((FAILURES++))
check_ssl "books.therapeuticsociety.org" || ((FAILURES++))
echo ""

# ─────────────────────────────────────────────────────────────────────
echo "⚙️  Services"
echo "─────────────────────────────────────────────────────────────────"
check_service "$WORDPRESS_VM_IP" "apache2" || ((FAILURES++))
check_service "$BOOKSTACK_VM_IP" "apache2" || ((FAILURES++))
check_service "$WORDPRESS_VM_IP" "mysql" || ((FAILURES++))
check_service "$BOOKSTACK_VM_IP" "mysql" || ((FAILURES++))
echo ""

# ─────────────────────────────────────────────────────────────────────
# Summary
# ─────────────────────────────────────────────────────────────────────
echo "═══════════════════════════════════════════════════════════════"
if [[ $FAILURES -eq 0 ]]; then
    echo -e "${GREEN}All checks passed!${NC}"
    exit 0
else
    echo -e "${RED}$FAILURES check(s) failed!${NC}"
    exit 1
fi
