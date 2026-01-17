# Therapeutic Society Infrastructure

[![Infrastructure](https://img.shields.io/badge/Infrastructure-Self--Hosted-blue)]()
[![pfSense](https://img.shields.io/badge/Firewall-pfSense-orange)]()
[![WordPress](https://img.shields.io/badge/CMS-WordPress-21759b)]()
[![BookStack](https://img.shields.io/badge/Wiki-BookStack-0288d1)]()

Self-hosted web infrastructure for Therapeutic Society organization.

## 🌐 Live Sites

| Site | URL | Purpose |
|------|-----|---------|
| Main Website | [therapeuticsociety.org](https://therapeuticsociety.org) | Public website |
| Alternate Domain | [therapeutic-society.org](https://therapeutic-society.org) | Secondary domain |
| Knowledge Base | [books.therapeuticsociety.org](https://books.therapeuticsociety.org) | Documentation wiki |

## 🏗️ Architecture

```
Internet → Cloudflare (DNS/CDN) → pfSense (HAProxy) → Internal VMs
                                         │
                     ┌───────────────────┴───────────────────┐
                     │                                       │
              WordPress VM                            BookStack VM
            192.168.86.214:80                       192.168.86.113:80
```

## 📁 Project Structure

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

## 🚀 Quick Start

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

## 🔧 Configuration

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

## 📖 Documentation

- [Full Project Documentation](docs/THERAPEUTIC_SOCIETY_PROJECT.md)
- [Adding New Backends](templates/new-backend.md)

## 🛠️ Maintenance

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

## 📝 Changelog

See [CHANGELOG.md](CHANGELOG.md) for version history.

## 📄 License

Private infrastructure - Not for public distribution.

---

*Managed with ❤️ for Therapeutic Society*
