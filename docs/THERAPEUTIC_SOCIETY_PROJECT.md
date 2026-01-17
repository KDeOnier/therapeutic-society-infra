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

> **⚠️ IMPORTANT**: Subdomain ACLs MUST come before root domain ACLs!

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

> **⚠️ SECURITY**: Store these securely (password manager, encrypted vault)

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

## Changelog

| Version | Date | Changes |
|---------|------|---------|
| 1.0.0 | 2025-01-17 | Initial documentation created |

---

*Generated for migration to VS Code with Claude CLI plugin*
