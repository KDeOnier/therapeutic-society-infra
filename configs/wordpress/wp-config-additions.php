<?php
/**
 * WordPress Configuration Template for Reverse Proxy Setup
 * Version: 1.0.0
 * 
 * This template shows the required additions for WordPress
 * running behind HAProxy with SSL termination.
 * 
 * Add these lines AFTER <?php and BEFORE the database settings.
 */

// ═══════════════════════════════════════════════════════════════════
// REVERSE PROXY CONFIGURATION
// Required for HAProxy SSL termination
// ═══════════════════════════════════════════════════════════════════

/**
 * Force HTTPS behind reverse proxy
 * HAProxy terminates SSL and forwards HTTP to WordPress.
 * This tells WordPress the original request was HTTPS.
 */
if (isset($_SERVER['HTTP_X_FORWARDED_PROTO']) && $_SERVER['HTTP_X_FORWARDED_PROTO'] === 'https') {
    $_SERVER['HTTPS'] = 'on';
}

// ═══════════════════════════════════════════════════════════════════
// SITE URL CONFIGURATION
// Choose ONE of the following options:
// ═══════════════════════════════════════════════════════════════════

// ─────────────────────────────────────────────────────────────────────
// OPTION A: Dynamic URL (supports multiple domains)
// Use this if both therapeuticsociety.org AND therapeutic-society.org
// should work independently.
// ─────────────────────────────────────────────────────────────────────
if (isset($_SERVER['HTTP_HOST'])) {
    define('WP_HOME', 'https://' . $_SERVER['HTTP_HOST']);
    define('WP_SITEURL', 'https://' . $_SERVER['HTTP_HOST']);
}

// ─────────────────────────────────────────────────────────────────────
// OPTION B: Single canonical domain (better for SEO)
// Use this if you want one primary domain.
// Configure HAProxy to redirect the alternate domain.
// ─────────────────────────────────────────────────────────────────────
// define('WP_HOME', 'https://therapeuticsociety.org');
// define('WP_SITEURL', 'https://therapeuticsociety.org');

// ═══════════════════════════════════════════════════════════════════
// OPTIONAL: Additional security settings
// ═══════════════════════════════════════════════════════════════════

/**
 * Disable file editing in WordPress admin
 * Recommended for security
 */
define('DISALLOW_FILE_EDIT', true);

/**
 * Limit post revisions to save database space
 */
define('WP_POST_REVISIONS', 10);

/**
 * Increase memory limit if needed
 */
define('WP_MEMORY_LIMIT', '256M');

// ═══════════════════════════════════════════════════════════════════
// END OF REVERSE PROXY CONFIGURATION
// The rest of wp-config.php continues below...
// ═══════════════════════════════════════════════════════════════════
