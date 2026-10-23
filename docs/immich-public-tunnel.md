# Sharing images to friends

I wanted to be able to share links to Immich albums to allow friends and family to see photos
without having to have an account, and without having to connect via tailscale or be on my LAN.

Solution: <https://github.com/alangrainger/immich-public-proxy> with a Cloudflare Tunnel.

This allows me to share links for viewing and uploading without exposing any ports
from my LAN to the world.

## Immich Settings

External domain: `photos.prowe.ca`

## Cloudflare Tunnel

On my mac:

```bash
nix shell nixpkgs#cloudflared
cloudflared tunnel login
cloudflared tunnel create immich
cloudflared tunnel route dns immich photos.prowe.ca
```

Copied the contents of the generated JSON and put it into an age secret.

Per IPP's README, videos served through Cloudflare may not play unless `/share/video/*`
is excluded from caching. Cloudflare tries to cache or range-split the responses,
and that breaks video seeking and streaming.

Steps: in the Cloudflare dashboard, picked the prowe.ca zone, then Caching → Cache Rules → Create rule.

- Name: `immich-public-proxy-video-bypass`
- If incoming requests match: Custom filter expression.
  - Field: URI Path
  - Operator: starts with
  - Value: `/share/video/`
  - AND Hostname equals `photos.prowe.ca`, so the rule doesn't touch other hostnames in the zone.
- Then: Cache eligibility → Bypass cache.

## Uploads

- Tunnel -> Caddy on `127.0.0.1:8088` (`upload.caddy.port`) -> `/upload/*` goes to the upload service (:3001), everything else to IPP (:3000).
- `maxFileSize = 100` because Cloudflare's free plan rejects bodies over 100 MB.
- In Immich: shared link -> enable "Allow public user to upload". Requires Immich >= 3.0.
- Check: `https://photos.prowe.ca/upload/healthcheck` answers `upload-ok`.
