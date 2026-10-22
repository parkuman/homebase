# Sharing images to friends

I wanted to be able to share links to Immich albums to allow friends and family to see photos
without having to have an account, and without having to connect via tailscale or be on my LAN.

Solution: <https://github.com/alangrainger/immich-public-proxy> with a Cloudflare Tunnel.

This allows me to share links for viewing (and eventually uploading) without exposing any ports
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
