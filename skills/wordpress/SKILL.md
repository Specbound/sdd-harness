---
name: wordpress
description: WordPress development — custom themes, plugins, and WooCommerce stores, covering architecture, hooks, REST API, block editor, security hardening, and performance. Use when building, extending, or securing a WordPress site, plugin, theme, or WooCommerce store.
---

# WordPress Development

## Theme development
Structure:
```
theme-name/
├── style.css          # theme header (name, version, etc.)
├── functions.php      # theme setup, enqueue, custom functions
├── index.php           # fallback template
├── header.php / footer.php / sidebar.php
├── single.php / page.php / archive.php / search.php / 404.php / comments.php
├── template-parts/
├── inc/
├── assets/{css,js,images}/
└── languages/
```
- Follow the WordPress template hierarchy — `index.php` is the fallback; more specific templates (`single-{post_type}.php`, `page-{slug}.php`) override it.
- `functions.php`: register nav menus, `add_theme_support(...)` (thumbnails, RSS, title-tag, block editor features), register widget areas, enqueue scripts/styles via `wp_enqueue_script`/`wp_enqueue_style` (never inline `<script>`/`<style>` in templates).
- Block editor (Gutenberg): enable support, register custom blocks, block styles/patterns/templates as needed — don't assume classic-editor-only output.
- Child themes: use `style.css` `Template:` header pointing at the parent slug; enqueue parent styles before child overrides.

## Plugin development
Structure:
```
plugin-name/
├── plugin-name.php                 # plugin header + bootstrap
├── includes/
│   ├── class-plugin.php
│   ├── class-loader.php
│   ├── class-activator.php
│   └── class-deactivator.php
├── admin/{class-plugin-admin.php,css/,js/}
├── public/{class-plugin-public.php,css/,js/}
├── languages/
└── vendor/
```
- Use activation/deactivation hooks (`register_activation_hook`, `register_deactivation_hook`) for setup/teardown (e.g. custom table creation, flushing rewrite rules).
- Build a loader class that centralizes `add_action`/`add_filter` registration instead of scattering hooks across files.
- Admin UI: `add_menu_page`/`add_options_page` + Settings API (`register_setting`, sections, fields) rather than hand-rolled form handling.
- Database: custom tables via `dbDelta()` in an activation routine; always use `$wpdb->prepare()` for queries with variables.

### Custom post type
```php
register_post_type('book', [
    'labels' => [...],
    'public' => true,
    'has_archive' => true,
    'supports' => ['title', 'editor', 'thumbnail', 'excerpt'],
    'menu_icon' => 'dashicons-book',
]);
```

### REST API endpoint
```php
add_action('rest_api_init', function () {
    register_rest_route('myplugin/v1', '/books', [
        'methods' => 'GET',
        'callback' => 'get_books',
        'permission_callback' => '__return_true', // tighten for non-public data
    ]);
});
```

## WooCommerce
- Store setup: run the setup wizard, then configure tax rules and currency before adding products.
- Product types: variable products via attributes; custom product type by extending `WC_Product`:
```php
add_action('init', function () {
    class WC_Product_Custom extends WC_Product { /* custom product implementation */ }
});
```
- Payment gateways: integrate via the relevant gateway's WordPress plugin/SDK (Stripe, PayPal) plus WooCommerce's payment gateway API — don't hand-roll checkout payment handling.
- Shipping: configure zones first, then methods per zone; test free-shipping thresholds explicitly.
- Subscriptions/bookings/memberships are WooCommerce extensions, not core — verify the extension is installed/active before writing code against its hooks.

## Security (apply to every plugin/theme, not just "security phase")
- Verify nonces on every state-changing request (`wp_verify_nonce`, `check_admin_referer`).
- Capability-check before any privileged action (`current_user_can(...)`), not just hiding the UI.
- Sanitize all input (`sanitize_text_field`, `sanitize_email`, etc.) and escape all output (`esc_html`, `esc_attr`, `esc_url`) — sanitize on the way in, escape on the way out, always both.
- Parameterize all custom queries via `$wpdb->prepare()` — never string-concatenate user input into SQL.
- Disable file editing in production (`define('DISALLOW_FILE_EDIT', true)`), protect or disable XML-RPC if unused, change the default `wp_` table prefix on new installs.
- Keep core/themes/plugins updated; enforce strong passwords and 2FA for admin accounts.

## Performance
- Cache at every layer that applies: object cache (Redis/Memcached), page cache, browser cache headers, OPcache for PHP.
- Images: lazy-load, serve WebP/AVIF where possible, size appropriately instead of shipping full-resolution originals.
- Minify/combine assets; use a CDN for static assets.
- Targets to verify against: page load < 3s, TTFB < 200ms, LCP < 2.5s, CLS < 0.1, FID < 100ms.

## Quality gates
- **Theme**: all templates render, block editor supported, responsive + accessible (WCAG 2.1), cross-browser tested.
- **Plugin**: activates cleanly, hooks fire as expected, admin UI functional, inputs sanitized / outputs escaped, tests passing.
- **WooCommerce**: products display correctly, checkout completes, payments process, shipping calculates, order emails send, mobile-responsive.
