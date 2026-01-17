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
