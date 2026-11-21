# Clean-room study with Craft Anything

Tool: Craft Anything v0.6.1 (`craft-anything-cli`, Windows x64 portable, SHA-256 verified
against the release's SHA256SUMS.txt). Mode: **Clean room** – only what a visitor sees
(screenshots, visible text, measured layout); page source, scripts and app code are refused.

## What was studied
- Target: the public Google Play search results for "net speed meter"
  (`web_site_open` + `web_site_capture`, driven through `craft-anything-cli mcp` in one session,
  because each plain CLI command starts and closes its own browser).
- The study covered the category as a whole: ~27 net-speed-meter listings. No single app was
  used as a model and nothing was copied.

## Category features observed (visible listing art and titles only)
- Live speed in the status bar / notification (the defining feature).
- Download and upload shown separately; "real-time" emphasis.
- Daily data usage split into Wi-Fi and mobile; per-day tables.
- Floating / overlay meters on some listings.
- Units in KB/s, MB/s and Mbps.
- Dark UI with blue/green accent pairs is common.

## Decisions taken into the spec
- Must-have: status-bar live speed (Android), tray live speed (Windows parity), daily Wi-Fi/mobile usage, unit switch.
- Windows floating meter as the desktop counterpart of overlays.
- Original name (Tachyo), icon, copy and layout; Astryx Neutral styling. Nothing copied from any listing.

## Limitations
- One page state; no app binaries or code were inspected.
- Evidence ids from the run: `ev_a77db361…` (open), `ev_61492da4…` (capture).
