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
| SSL | ❌ Unchecked |

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

> ⚠️ **IMPORTANT**: Add subdomain ACLs **BEFORE** root domain ACLs!

#### Add Action

| Action | Condition | Backend |
|--------|-----------|---------|
| Use Backend | `acl_app` | `app_backend` |

> ⚠️ **IMPORTANT**: Add subdomain actions **BEFORE** root domain actions!

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
