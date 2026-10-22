# DNS setup for the homelab

As of writing, I have Adguard acting as a DNS server (and ad-blocker) running
on the Chromebox within K3s.

My new goal is to have DNS and a reverse proxy running on the NAS.

## Public DNS resolution

Wildcard `*.home.prowe.ca` A record in Cloudflare

This tells any public device when trying to resolve that domain to hit the NAS IP.

```bash
dig photos.home.prowe.ca +short
```

## Private DNS resolution

CoreDNS running on the NAS.

### LAN devices

This covers the case: "What if the internet is down for longer than the Cloudflare DNS entry TTL?"

Hit the router, which via DHCP will point to the NAS as the DNS server

The NAS, running CoreDNS, responds with its own LAN IP for `*.home.prowe.ca`.

### Tailscale Devices

We point Tailscale DNS as the NAS Tailnet IP, this hits CoreDNS, which responds
with the Tailnet IP of the NAS for `*.home.prowe.ca`.
