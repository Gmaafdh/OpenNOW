# OpenNOW Social service

This is the optional, self-hosted service used by OpenNOW's Friends page for OpenNOW accounts, friend codes, requests, chat, presence, and opt-in play history. It is independent of NVIDIA/GeForce NOW. OpenNOW cannot look up NVIDIA accounts or verify the optional NVIDIA display name; that field is user-provided and explicitly marked **unverified**.

## Deploy with HTTPS

You need a server reachable by both users, a DNS name pointing to it, and ports 80/443 available. The included Compose stack runs the service behind Caddy, which obtains and renews TLS certificates automatically.

```sh
cd services/social-backend
SOCIAL_DOMAIN=social.example.com docker compose up -d --build
```

Use the same public HTTPS address (for this example, `https://social.example.com`) in the OpenNOW Friends page on each computer. Do not expose port 8787 directly to the public internet or use plain HTTP over an untrusted network. For a server behind an existing reverse proxy, route the HTTPS hostname to the service's port 8787 and set `TRUST_PROXY=1` only when requests can reach the service exclusively through that trusted proxy.

The Compose file keeps account/chat data in the `social-data` volume. Back it up regularly (`docker compose stop social` before copying the volume), protect backups as sensitive data, and test restore procedures. The default deployment is a single service instance with a local JSON database; do not run multiple replicas against the same file. The service has no email/password recovery or account moderation workflow, so the operator is responsible for access, backups, abuse reports, and retention.

## Local development

Requires Node.js 20 or newer; no npm packages are needed.

```sh
npm test
DATA_DIR=./data HOST=127.0.0.1 PORT=8787 npm start
```

Only use a localhost address for local development. Public hosting should use HTTPS. Registration requires a unique 3–20 character username and a password of at least 12 characters. Passwords are stored as scrypt hashes; session tokens are random, expire after 30 days, and only their SHA-256 hashes are stored. The client keeps the active token in memory and asks the user to sign in again after restarting OpenNOW.

## What is shared

New accounts default to sharing no presence, current game, or play history. Each user can enable those separately in Friends privacy controls. Presence and current-game activity require OpenNOW to remain running and connected to the configured server. Game history is accumulated from those OpenNOW heartbeats; it is not retrieved from or verified by NVIDIA. Messages are plain text and capped at 2,000 characters.

This is an early self-hosted service, not a centrally operated OpenNOW network. Creating the app and backend source does not by itself make another computer reachable: a user/operator must deploy this service on a publicly reachable HTTPS host and both users must configure that same URL.
