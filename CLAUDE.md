# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

---

# README

[![Infrastructure](https://img.shields.io/badge/Infrastructure-Self--Hosted-blue)]()
[![pfSense](https://img.shields.io/badge/Firewall-pfSense-orange)]()
[![WordPress](https://img.shields.io/badge/CMS-WordPress-21759b)]()
[![BookStack](https://img.shields.io/badge/Wiki-BookStack-0288d1)]()

Self-hosted web infrastructure for Therapeutic Society organization.

## Live Sites

| Site | URL | Purpose |
|------|-----|---------|
| Main Website | [therapeuticsociety.org](https://therapeuticsociety.org) | Public website |
| Alternate Domain | [therapeutic-society.org](https://therapeutic-society.org) | Secondary domain |
| Knowledge Base | [books.therapeuticsociety.org](https://books.therapeuticsociety.org) | Documentation wiki |

## Architecture

```
Internet → Cloudflare (DNS/CDN) → pfSense (HAProxy) → Internal VMs
                                         │
                     ┌───────────────────┴───────────────────┐
                     │                                       │
              WordPress VM                            BookStack VM
            192.168.86.214:80                       192.168.86.113:80
```

## Project Structure

```
therapeutic-society-infra/
├── README.md                 # This file
├── docs/
│   └── THERAPEUTIC_SOCIETY_PROJECT.md  # Full documentation
├── scripts/
│   ├── backup-wordpress.sh   # WordPress backup script
│   ├── backup-bookstack.sh   # BookStack backup script
│   ├── update-wordpress.sh   # WordPress update script
│   └── health-check.sh       # Infrastructure health check
├── configs/
│   ├── haproxy/              # HAProxy configuration snippets
│   ├── wordpress/            # WordPress config templates
│   ├── bookstack/            # BookStack config templates
│   └── pfsense/              # pfSense export configs
└── templates/
    └── new-backend.md        # Template for adding new backends
```

## Quick Start

### Prerequisites

- pfSense with HAProxy and ACME packages installed
- Cloudflare account with domain(s) configured
- Turnkey Linux VMs (WordPress, BookStack)

### Initial Setup

See [Full Documentation](docs/THERAPEUTIC_SOCIETY_PROJECT.md) for complete setup instructions.

### Common Tasks

```bash
# SSH into WordPress
ssh root@192.168.86.214

# SSH into BookStack
ssh root@192.168.86.113

# Update WordPress (on WordPress VM)
cd /var/www/wordpress
wp core update --allow-root
wp plugin update --all --allow-root

# Restart HAProxy (on pfSense)
/usr/local/etc/rc.d/haproxy.sh restart
```

## Configuration

### Environment Variables

Copy the example env file and fill in your values:

```bash
cp .env.example .env
```

### Sensitive Data

**Never commit sensitive data!** Store credentials in:
- Password manager
- `.env` file (gitignored)
- Encrypted vault

## Documentation

- [Full Project Documentation](docs/THERAPEUTIC_SOCIETY_PROJECT.md)
- [Adding New Backends](templates/new-backend.md)

## Maintenance

### Backups

```bash
# Run WordPress backup
./scripts/backup-wordpress.sh

# Run BookStack backup
./scripts/backup-bookstack.sh
```

### Health Checks

```bash
# Check all services
./scripts/health-check.sh
```

## Changelog

See [CHANGELOG.md](CHANGELOG.md) for version history.

## License

Private infrastructure - Not for public distribution.

---

# Therapeutic Society Web Hosting Infrastructure

> **Project Documentation for VS Code + Claude CLI**
>
> Version: 1.0.0
> Last Updated: 2025-01-17

---

## Table of Contents

1. [Project Overview](#project-overview)
2. [Architecture Diagram](#architecture-diagram)
3. [Infrastructure Components](#infrastructure-components)
4. [Network Configuration](#network-configuration)
5. [Domain & DNS Configuration](#domain--dns-configuration)
6. [SSL/TLS Certificates](#ssltls-certificates)
7. [HAProxy Configuration](#haproxy-configuration)
8. [WordPress Configuration](#wordpress-configuration)
9. [BookStack Configuration](#bookstack-configuration)
10. [Firewall Rules](#firewall-rules)
11. [WordPress Plugins](#wordpress-plugins)
12. [Maintenance & Troubleshooting](#maintenance--troubleshooting)
13. [Future Enhancements](#future-enhancements)

---

## Project Overview

### Purpose
Web hosting infrastructure for Therapeutic Society organization, providing:
- Public-facing WordPress website
- Knowledge management via BookStack
- Multi-domain support with SSL/TLS termination
- Dynamic DNS for residential ISP with changing IP

### Domains
| Domain | Purpose | Backend |
|--------|---------|---------|
| `therapeuticsociety.org` | Primary website | WordPress |
| `therapeutic-society.org` | Alternate domain | WordPress (same instance) |
| `books.therapeuticsociety.org` | Knowledge base | BookStack |

### Key Design Decisions
- **Cost-effective**: Free SSL via Let's Encrypt, free Cloudflare tier, free WordPress plugins
- **Self-hosted**: Running on local infrastructure behind pfSense
- **Scalable**: HAProxy architecture supports adding more backends easily
- **Secure**: SSL termination at edge, Cloudflare proxy protection

---

## Architecture Diagram

```
┌─────────────────────────────────────────────────────────────────────────────┐
│                              INTERNET                                        │
└─────────────────────────────────────────────────────────────────────────────┘
                                    │
                                    ▼
┌─────────────────────────────────────────────────────────────────────────────┐
│                           CLOUDFLARE                                         │
│  ┌─────────────────┐  ┌─────────────────┐  ┌─────────────────┐              │
│  │therapeuticsociety│  │therapeutic-     │  │books.therapeutic│              │
│  │.org (A record)   │  │society.org      │  │society.org      │              │
│  │                  │  │(A record)       │  │(CNAME)          │              │
│  └────────┬─────────┘  └────────┬────────┘  └────────┬────────┘              │
│           │                     │                    │                       │
│           └──────────────┬──────┴────────────────────┘                       │
│                          │                                                   │
│              SSL/TLS: Full (strict)                                          │
│              Proxy: Enabled (orange cloud)                                   │
└──────────────────────────┼───────────────────────────────────────────────────┘
                           │
                           ▼ Dynamic DNS updates WAN IP
┌─────────────────────────────────────────────────────────────────────────────┐
│                         pfSense Firewall                                     │
│                         WAN: Dynamic IP                                      │
│                                                                              │
│  ┌─────────────────────────────────────────────────────────────────────┐    │
│  │                        HAProxy                                       │    │
│  │                                                                      │    │
│  │  Frontend: shared_https_frontend (port 443)                         │    │
│  │  Frontend: http_redirect (port 80 → 443)                            │    │
│  │                                                                      │    │
│  │  SSL Certificates (ACME/Let's Encrypt):                             │    │
│  │    - therapeuticsociety_cert                                        │    │
│  │    - therapeutic_society_hyphen_cert                                │    │
│  │    - books_therapeuticsociety_cert                                  │    │
│  │                                                                      │    │
│  │  ACLs (evaluated in order):                                         │    │
│  │    1. acl_books → bookstack_backend                                 │    │
│  │    2. acl_therapeuticsociety → wordpress_therapeuticsociety         │    │
│  │    3. acl_therapeutic_society_hyphen → wordpress_therapeuticsociety │    │
│  └─────────────────────────────────────────────────────────────────────┘    │
│                                                                              │
│  Dynamic DNS:                                                                │
│    - therapeuticsociety.org                                                  │
│    - therapeutic-society.org                                                 │
└──────────────────────────┼───────────────────────────────────────────────────┘
                           │
                           ▼ LAN: 192.168.86.0/24
┌─────────────────────────────────────────────────────────────────────────────┐
│                          Internal Network                                    │
│                                                                              │
│  ┌─────────────────────────┐       ┌─────────────────────────┐              │
│  │   WordPress VM          │       │   BookStack VM          │              │
│  │   (Turnkey Linux)       │       │   (Turnkey Linux)       │              │
│  │                         │       │                         │              │
│  │   IP: 192.168.86.214    │       │   IP: 192.168.86.113    │              │
│  │   Port: 80              │       │   Port: 80              │              │
│  │                         │       │                         │              │
│  │   Path: /var/www/       │       │   Path: /var/www/       │              │
│  │         wordpress/      │       │         bookstack/      │              │
│  └─────────────────────────┘       └─────────────────────────┘              │
│                                                                              │
└─────────────────────────────────────────────────────────────────────────────┘
```

---

## Infrastructure Components

### Hardware/VM Summary

| Component | Type | IP Address | Port | Notes |
|-----------|------|------------|------|-------|
| pfSense | Firewall/Router | Gateway | 80, 443 | HAProxy, ACME, DDNS |
| WordPress | Turnkey VM | 192.168.86.214 | 80 | Apache |
| BookStack | Turnkey VM | 192.168.86.113 | 80 | Apache |

### Software Stack

| Layer | Technology | Version | Purpose |
|-------|------------|---------|---------|
| DNS/CDN | Cloudflare | - | DNS, DDoS protection, CDN |
| Firewall | pfSense | 2.7.x | Routing, firewall, reverse proxy |
| Reverse Proxy | HAProxy | 2.9.14 | SSL termination, load balancing |
| SSL | ACME/Let's Encrypt | - | Free SSL certificates |
| CMS | WordPress | Latest | Public website |
| Wiki | BookStack | Latest | Knowledge management |

---

## Network Configuration

### Subnet Details

```
Network:     192.168.86.0/24
Gateway:     192.168.86.1 (pfSense LAN)
DHCP Range:  192.168.86.100 - 192.168.86.200 (example)
Static IPs:  192.168.86.2 - 192.168.86.99 (servers)
```

### Static IP Assignments

| IP Address | Hostname | Service |
|------------|----------|---------|
| 192.168.86.214 | wordpress-vm | WordPress |
| 192.168.86.113 | bookstack-vm | BookStack |

---

## Domain & DNS Configuration

### Cloudflare DNS Records

#### therapeuticsociety.org

| Type | Name | Value | Proxy | TTL |
|------|------|-------|-------|-----|
| A | @ | (WAN IP via DDNS) | Proxied | Auto |
| CNAME | www | therapeuticsociety.org | Proxied | Auto |
| CNAME | books | therapeuticsociety.org | Proxied | Auto |

#### therapeutic-society.org

| Type | Name | Value | Proxy | TTL |
|------|------|-------|-------|-----|
| A | @ | (WAN IP via DDNS) | Proxied | Auto |

### Cloudflare SSL/TLS Settings

- **Encryption Mode**: Full (strict)
- **Always Use HTTPS**: Enabled
- **Minimum TLS Version**: TLS 1.2

### pfSense Dynamic DNS

```
# therapeuticsociety.org
Service Type:  Cloudflare
Interface:     WAN
Hostname:      @
Domain:        therapeuticsociety.org
Username:      token
Password:      <CLOUDFLARE_API_TOKEN>
Proxied:       ✓ Checked

# therapeutic-society.org
Service Type:  Cloudflare
Interface:     WAN
Hostname:      @
Domain:        therapeutic-society.org
Username:      token
Password:      <CLOUDFLARE_API_TOKEN>
Proxied:       ✓ Checked
```

---

## SSL/TLS Certificates

### ACME Account Key

```
Name:         letsencrypt-prod
ACME Server:  Let's Encrypt Production
Email:        <YOUR_EMAIL>
```

### Certificates

#### therapeuticsociety_cert

```yaml
Name: therapeuticsociety_cert
Status: Active
ACME Account: letsencrypt-prod
Private Key: 256-bit ECDSA
Domain SAN List:
  - Domainname: therapeuticsociety.org
  - Method: DNS-Cloudflare
  - Token: <API_TOKEN>
  - Account ID: <ACCOUNT_ID>
  - Zone ID: <ZONE_ID_therapeuticsociety>
Actions:
  - Command: /usr/local/etc/rc.d/haproxy.sh restart
```

#### therapeutic_society_hyphen_cert

```yaml
Name: therapeutic_society_hyphen_cert
Status: Active
ACME Account: letsencrypt-prod
Private Key: 256-bit ECDSA
Domain SAN List:
  - Domainname: therapeutic-society.org
  - Method: DNS-Cloudflare
  - Token: <API_TOKEN>
  - Account ID: <ACCOUNT_ID>
  - Zone ID: <ZONE_ID_therapeutic-society>
Actions:
  - Command: /usr/local/etc/rc.d/haproxy.sh restart
```

#### books_therapeuticsociety_cert

```yaml
Name: books_therapeuticsociety_cert
Status: Active
ACME Account: letsencrypt-prod
Private Key: 256-bit ECDSA
Domain SAN List:
  - Domainname: books.therapeuticsociety.org
  - Method: DNS-Cloudflare
  - Token: <API_TOKEN>
  - Account ID: <ACCOUNT_ID>
  - Zone ID: <ZONE_ID_therapeuticsociety>
Actions:
  - Command: /usr/local/etc/rc.d/haproxy.sh restart
```

---

## HAProxy Configuration

### Backends

#### wordpress_therapeuticsociety

```yaml
Name: wordpress_therapeuticsociety
Mode: HTTP
Server List:
  - Name: wordpress-vm
  - Address: 192.168.86.214
  - Port: 80
  - SSL: Unchecked
Health Check:
  Method: None  # Disabled for reliability
```

#### bookstack_backend

```yaml
Name: bookstack_backend
Mode: HTTP
Server List:
  - Name: bookstack-vm
  - Address: 192.168.86.113
  - Port: 80
  - SSL: Unchecked
Health Check:
  Method: None
```

### Frontends

#### http_redirect (Port 80)

```yaml
Name: http_redirect
Status: Active
External Address: WAN address (IPv4)
Port: 80
Type: HTTP / HTTPS (offloading)
Default Backend: None
Advanced Pass Thru: |
  http-request redirect scheme https code 301
```

#### shared_https_frontend (Port 443)

```yaml
Name: shared_https_frontend
Status: Active
External Address: WAN address (IPv4)
Port: 443
Type: HTTP / HTTPS (offloading)
SSL Offloading:
  Certificate: therapeuticsociety_cert
  Additional Certificates:
    - therapeutic_society_hyphen_cert
    - books_therapeuticsociety_cert
  Add ACL for certificates: Checked
```

### Access Control Lists (Order Matters!)

| Order | Name | Expression | Value |
|-------|------|------------|-------|
| 1 | acl_books | Host matches | books.therapeuticsociety.org |
| 2 | acl_therapeuticsociety | Host matches | therapeuticsociety.org |
| 3 | acl_therapeutic_society_hyphen | Host matches | therapeutic-society.org |

### Actions (Order Matches ACLs!)

| Order | Action | Condition | Backend |
|-------|--------|-----------|---------|
| 1 | Use Backend | acl_books | bookstack_backend |
| 2 | Use Backend | acl_therapeuticsociety | wordpress_therapeuticsociety |
| 3 | Use Backend | acl_therapeutic_society_hyphen | wordpress_therapeuticsociety |

> **IMPORTANT**: Subdomain ACLs MUST come before root domain ACLs!

---

## WordPress Configuration

### File Locations

```
Document Root:  /var/www/wordpress/
Config File:    /var/www/wordpress/wp-config.php
```

### wp-config.php Modifications

Add these lines after `<?php` and before database settings:

```php
<?php
// Force HTTPS behind reverse proxy
// Added for HAProxy SSL termination
if (isset($_SERVER['HTTP_X_FORWARDED_PROTO']) && $_SERVER['HTTP_X_FORWARDED_PROTO'] === 'https') {
    $_SERVER['HTTPS'] = 'on';
}

// Dynamic site URL based on request (supports multiple domains)
if (isset($_SERVER['HTTP_HOST'])) {
    define('WP_HOME', 'https://' . $_SERVER['HTTP_HOST']);
    define('WP_SITEURL', 'https://' . $_SERVER['HTTP_HOST']);
}

// ... rest of wp-config.php
```

### Alternative: Single Domain (Better for SEO)

If you prefer one canonical domain with redirect:

```php
<?php
// Force HTTPS behind reverse proxy
if (isset($_SERVER['HTTP_X_FORWARDED_PROTO']) && $_SERVER['HTTP_X_FORWARDED_PROTO'] === 'https') {
    $_SERVER['HTTPS'] = 'on';
}

// Single canonical domain
define('WP_HOME', 'https://therapeuticsociety.org');
define('WP_SITEURL', 'https://therapeuticsociety.org');
```

---

## BookStack Configuration

### File Locations

```
Document Root:  /var/www/bookstack/
Config File:    /var/www/bookstack/.env
```

### .env Modifications

```bash
# Edit config
nano /var/www/bookstack/.env

# Update APP_URL
APP_URL=https://books.therapeuticsociety.org

# Add trusted proxy (for HAProxy)
TRUSTED_PROXIES=*

# Restart Apache
systemctl restart apache2
```

---

## Firewall Rules

### WAN Rules (pfSense)

| Action | Interface | Protocol | Source | Destination | Port | Description |
|--------|-----------|----------|--------|-------------|------|-------------|
| Pass | WAN | TCP | Any* | WAN address | 443 | Allow HTTPS to HAProxy |
| Pass | WAN | TCP | Any* | WAN address | 80 | Allow HTTP to HAProxy (redirect) |

> *Optionally restrict to Cloudflare IPs only (see Security Hardening)

### Security Hardening: Cloudflare IP Restriction

```
# Create Alias
Firewall → Aliases → Add
  Name: Cloudflare_IPs
  Type: URL Table (IPs)
  URL: https://www.cloudflare.com/ips-v4

# Update WAN rules
  Source: Cloudflare_IPs (instead of Any)
```

---

## WordPress Plugins

### Recommended Free Stack

| Category | Plugin | Purpose |
|----------|--------|---------|
| **Page Builder** | Elementor (Free) | Drag-and-drop page building |
| **Templates** | Starter Templates | Pre-built website designs |
| **SEO** | Rank Math (Free) | Sitemaps, schema, keyword tracking |
| **Security** | Wordfence (Free) | Firewall, malware scanning |
| **Performance** | LiteSpeed Cache | Caching (works on any server) |
| **Images** | Smush (Free) | Image compression |
| **Forms** | Fluent Forms (Free) | Contact forms |
| **Backups** | UpdraftPlus (Free) | Backup to cloud storage |
| **Downloads** | Download Monitor | File download management |
| **Spam** | Akismet | Spam protection |

### Installation Commands (SSH)

```bash
# SSH into WordPress VM
ssh root@192.168.86.214

# Install WP-CLI if not present
cd /var/www/wordpress

# Install plugins via WP-CLI
wp plugin install elementor --activate --allow-root
wp plugin install starter-templates --activate --allow-root
wp plugin install seo-by-rank-math --activate --allow-root
wp plugin install wordfence --activate --allow-root
wp plugin install litespeed-cache --activate --allow-root
wp plugin install updraftplus --activate --allow-root
wp plugin install fluent-forms --activate --allow-root
wp plugin install download-monitor --activate --allow-root
wp plugin install akismet --activate --allow-root
wp plugin install wp-smushit --activate --allow-root
```

---

## Maintenance & Troubleshooting

### Common Commands

```bash
# ═══════════════════════════════════════════════════════════════════
# WordPress VM Commands
# ═══════════════════════════════════════════════════════════════════

# SSH into WordPress
ssh root@192.168.86.214

# Restart Apache
systemctl restart apache2

# Check Apache status
systemctl status apache2

# View Apache error log
tail -f /var/log/apache2/error.log

# Edit wp-config.php
nano /var/www/wordpress/wp-config.php

# WP-CLI: Update WordPress
wp core update --allow-root
wp plugin update --all --allow-root
wp theme update --all --allow-root

# ═══════════════════════════════════════════════════════════════════
# BookStack VM Commands
# ═══════════════════════════════════════════════════════════════════

# SSH into BookStack
ssh root@192.168.86.113

# Restart Apache
systemctl restart apache2

# Edit .env
nano /var/www/bookstack/.env

# Clear BookStack cache
cd /var/www/bookstack
php artisan cache:clear
php artisan view:clear

# ═══════════════════════════════════════════════════════════════════
# pfSense Commands (via SSH or Console)
# ═══════════════════════════════════════════════════════════════════

# Restart HAProxy
/usr/local/etc/rc.d/haproxy.sh restart

# Test HAProxy config
haproxy -c -f /var/etc/haproxy/haproxy.cfg

# View HAProxy logs
clog /var/log/haproxy.log

# Renew all ACME certificates
# (via GUI: Services → ACME → Certificates → Issue/Renew)
```

### Troubleshooting Checklist

#### 503 Service Unavailable

1. Check HAProxy status: **Status → HAProxy**
2. Verify backend server is running: `systemctl status apache2`
3. Test connectivity from pfSense: `curl -I http://192.168.86.214`
4. Check health check settings (try `None`)

#### SSL Certificate Issues

1. Verify ACME certificate issued: **Services → ACME → Certificates**
2. Check certificate is assigned to frontend
3. Verify Cloudflare SSL mode is "Full (strict)"
4. Check ACME logs for errors

#### Site Shows Wrong Content

1. Verify ACL order (subdomains before root domains)
2. Check ACL expression type (`Host matches` for exact)
3. Clear browser cache
4. Test from outside network (cellular)

#### Dynamic DNS Not Updating

1. Check **Services → Dynamic DNS** for errors
2. Verify API token permissions
3. Force update and check Cloudflare dashboard

---

## Future Enhancements

### Planned

- [ ] Split DNS for internal LAN access
- [ ] Cloudflare IP restriction (security hardening)
- [ ] Automated backups to cloud storage
- [ ] Monitoring and alerting setup
- [ ] WordPress multisite consideration

### Optional Improvements

- [ ] Redis object cache for WordPress
- [ ] Cloudflare Page Rules for caching
- [ ] Fail2ban integration
- [ ] Uptime monitoring (UptimeRobot, etc.)
- [ ] Log aggregation and analysis

---

## Quick Reference

### Important URLs

| Service | URL |
|---------|-----|
| Main Site | https://therapeuticsociety.org |
| Alternate | https://therapeutic-society.org |
| Wiki | https://books.therapeuticsociety.org |
| pfSense | https://192.168.86.1 |
| WordPress Admin | https://therapeuticsociety.org/wp-admin |
| BookStack Admin | https://books.therapeuticsociety.org/login |

### Important IPs

| Device | IP |
|--------|-----|
| pfSense LAN | 192.168.86.1 |
| WordPress | 192.168.86.214 |
| BookStack | 192.168.86.113 |

### Key File Paths

| File | Path |
|------|------|
| WordPress Config | /var/www/wordpress/wp-config.php |
| BookStack Config | /var/www/bookstack/.env |
| HAProxy Config | /var/etc/haproxy/haproxy.cfg |

---

## Credentials Storage

> **SECURITY**: Store these securely (password manager, encrypted vault)

```
# Cloudflare
API Token: <REDACTED>
Account ID: <REDACTED>
Zone ID (therapeuticsociety.org): <REDACTED>
Zone ID (therapeutic-society.org): <REDACTED>

# WordPress Admin
URL: https://therapeuticsociety.org/wp-admin
Username: <REDACTED>
Password: <REDACTED>

# BookStack Admin
URL: https://books.therapeuticsociety.org/login
Username: <REDACTED>
Password: <REDACTED>

# VM SSH
WordPress: ssh root@192.168.86.214
BookStack: ssh root@192.168.86.113
```

---

# Adding a New Backend to HAProxy

> Template for adding additional services to the infrastructure

## Prerequisites

- [ ] New VM/server deployed and accessible on LAN
- [ ] Service running and responding on expected port
- [ ] Subdomain or domain chosen
- [ ] Cloudflare API credentials available

## Step-by-Step Process

### 1. Cloudflare DNS

**Cloudflare Dashboard → [your domain] → DNS → Records → Add**

For a **subdomain** (e.g., `app.therapeuticsociety.org`):

| Field | Value |
|-------|-------|
| Type | CNAME |
| Name | `app` |
| Target | `therapeuticsociety.org` |
| Proxy | Proxied (orange cloud) |

For a **new domain** (e.g., `newdomain.org`):

| Field | Value |
|-------|-------|
| Type | A |
| Name | `@` |
| IPv4 | Your WAN IP |
| Proxy | Proxied (orange cloud) |

---

### 2. Dynamic DNS (if new domain)

**pfSense → Services → Dynamic DNS → Add**

| Field | Value |
|-------|-------|
| Service Type | Cloudflare |
| Interface | WAN |
| Hostname | `@` |
| Domain | `newdomain.org` |
| Username | token |
| Password | `<API_TOKEN>` |
| Proxied | ✓ Checked |
| Description | Cloudflare DDNS - newdomain.org |

**Save & Force Update**

---

### 3. ACME Certificate

**pfSense → Services → ACME → Certificates → Add**

| Field | Value |
|-------|-------|
| Name | `app_therapeuticsociety_cert` |
| Status | Active |
| ACME Account | letsencrypt-prod |
| Private Key | 256-bit ECDSA |

**Domain SAN List:**

| Field | Value |
|-------|-------|
| Domainname | `app.therapeuticsociety.org` |
| Method | DNS-Cloudflare |
| Token | `<API_TOKEN>` |
| Account ID | `<ACCOUNT_ID>` |
| Zone ID | `<ZONE_ID>` |

**Actions List:**

| Field | Value |
|-------|-------|
| Command | `/usr/local/etc/rc.d/haproxy.sh restart` |

**Save → Issue/Renew**

---

### 4. HAProxy Backend

**pfSense → Services → HAProxy → Backend → Add**

| Field | Value |
|-------|-------|
| Name | `app_backend` |
| Mode | HTTP |

**Server List → Add:**

| Field | Value |
|-------|-------|
| Name | `app-vm` |
| Address | `192.168.86.XXX` |
| Port | `80` |
| SSL | Unchecked |

**Health Check:**

| Field | Value |
|-------|-------|
| Method | None |

**Save**

---

### 5. HAProxy Frontend Update

**pfSense → Services → HAProxy → Frontend → Edit `shared_https_frontend`**

#### Add Certificate

Under **SSL Offloading → Additional Certificates:**

Add: `app_therapeuticsociety_cert`

#### Add ACL

| Name | Expression | Value |
|------|------------|-------|
| `acl_app` | Host matches | `app.therapeuticsociety.org` |

> **IMPORTANT**: Add subdomain ACLs **BEFORE** root domain ACLs!

#### Add Action

| Action | Condition | Backend |
|--------|-----------|---------|
| Use Backend | `acl_app` | `app_backend` |

> **IMPORTANT**: Add subdomain actions **BEFORE** root domain actions!

**Save → Apply Changes**

---

### 6. Application Configuration

SSH into the new server and configure the application to:

1. Accept the new URL
2. Trust the reverse proxy headers

Example for a generic app:

```bash
# Example environment variable
APP_URL=https://app.therapeuticsociety.org

# Trust proxy headers (varies by application)
TRUSTED_PROXIES=*
```

---

### 7. Testing

1. **Test from outside network** (cellular or VPN):
   ```bash
   curl -I https://app.therapeuticsociety.org
   ```

2. **Check HAProxy status**:
   - pfSense → Status → HAProxy
   - Backend should show green

3. **Verify SSL**:
   ```bash
   echo | openssl s_client -servername app.therapeuticsociety.org -connect app.therapeuticsociety.org:443 2>/dev/null | openssl x509 -noout -dates
   ```

---

### 8. Update Documentation

Add the new service to:

- [ ] `docs/THERAPEUTIC_SOCIETY_PROJECT.md`
- [ ] `README.md`
- [ ] `.env.example` (if credentials needed)
- [ ] `scripts/health-check.sh` (add URL and service checks)

---

## Checklist Template

```markdown
## New Backend: [Service Name]

- [ ] VM deployed at 192.168.86.XXX
- [ ] Service running on port XX
- [ ] Cloudflare DNS record added
- [ ] Dynamic DNS configured (if new domain)
- [ ] ACME certificate issued
- [ ] HAProxy backend created
- [ ] HAProxy ACL added (correct order!)
- [ ] HAProxy action added (correct order!)
- [ ] Application configured for new URL
- [ ] Tested from external network
- [ ] Documentation updated
```

---

## Quick Reference: ACL Order

Always maintain this order (subdomains first):

```
1. acl_books              → books.therapeuticsociety.org
2. acl_app                → app.therapeuticsociety.org
3. acl_[other subdomains] → [subdomain].therapeuticsociety.org
4. acl_therapeuticsociety → therapeuticsociety.org
5. acl_therapeutic_hyphen → therapeutic-society.org
```

---

# Changelog

All notable changes to the Therapeutic Society Infrastructure will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/).

## [Unreleased]

### Planned
- Split DNS for internal LAN access
- Cloudflare IP restriction
- Automated backup scheduling
- Monitoring and alerting

---

## [1.0.0] - 2025-01-17

### Added
- Initial infrastructure setup
- pfSense with HAProxy reverse proxy
- WordPress site on Turnkey Linux VM (192.168.86.214)
- BookStack wiki on Turnkey Linux VM (192.168.86.113)
- SSL certificates via ACME/Let's Encrypt
- Dynamic DNS for Cloudflare
- Multi-domain support:
  - therapeuticsociety.org
  - therapeutic-society.org
  - books.therapeuticsociety.org

### Infrastructure
- HAProxy frontend on ports 80 (redirect) and 443 (SSL)
- HTTP to HTTPS redirect
- Health checks disabled for reliability
- ACL-based routing for multiple backends

### Documentation
- Full project documentation
- Backup scripts (WordPress, BookStack)
- Health check script
- Update script for WordPress
- Template for adding new backends

---

## Version History Format

```
## [X.Y.Z] - YYYY-MM-DD

### Added
- New features

### Changed
- Changes to existing functionality

### Deprecated
- Features to be removed in future

### Removed
- Removed features

### Fixed
- Bug fixes

### Security
- Security improvements
```
