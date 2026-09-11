# Valheim Dedicated Server — Chromebox LXC + playit.gg

Runs on the Chromebox (Proxmox) as a Debian LXC container.

## 1. Create the LXC Container

In the Proxmox GUI:

1. Download a **Debian 12** CT template: local → CT Templates → Templates → download `debian-12-standard`
2. Create CT:
   - **General:** hostname `valheim`, set a root password
   - **Template:** the Debian 12 template you just downloaded
   - **Disks:** storage = `local-lvm`, size = **20 GB**
   - **CPU:** 2 cores
   - **Memory:** 6144 MB (6 GB), swap 512 MB
   - **Network:** DHCP or static IP on your LAN bridge (vmbr0)
   - **DNS:** use host settings
3. Start the container

## 2. Initial Setup

```bash
# enter the container (from Proxmox shell, or SSH)
pct enter <CTID>

apt update && apt upgrade -y
apt install -y curl wget lib32gcc-s1 software-properties-common
```

## 3. Create a Non-Root User

```bash
useradd -m -s /bin/bash steam
```

## 4. Install SteamCMD

```bash
dpkg --add-architecture i386
apt update
apt install -y steamcmd
```

## 5. Install Valheim Dedicated Server

```bash
su - steam

steamcmd +@sSteamCmdForcePlatformType linux \
  +force_install_dir /home/steam/valheim \
  +login anonymous \
  +app_update 896660 validate \
  +quit
```

## 6. Configure the Server

```bash
# still as steam user
cat > /home/steam/valheim/start_server.sh << 'EOF'
#!/bin/bash
export templdpath=$LD_LIBRARY_PATH
export LD_LIBRARY_PATH=./linux64:$LD_LIBRARY_PATH
export SteamAppId=892970

./valheim_server.x86_64 \
  -name "YOUR_SERVER_NAME" \
  -port 2456 \
  -world "YourWorldName" \
  -password "YOUR_PASSWORD" \
  -crossplay \
  -public 0

export LD_LIBRARY_PATH=$templdpath
EOF

chmod +x /home/steam/valheim/start_server.sh
```

Change `YOUR_SERVER_NAME`, `YourWorldName`, and `YOUR_PASSWORD` (password must be ≥5 chars and not contain the server name).

`-public 0` keeps it off the server browser (friends connect via playit.gg address directly).

`-crossplay` enables crossplay support — omit if all players are on Steam.

## 7. Systemd Service

```bash
# back as root (exit from steam user)
cat > /etc/systemd/system/valheim.service << 'EOF'
[Unit]
Description=Valheim Dedicated Server
After=network.target

[Service]
Type=simple
User=steam
WorkingDirectory=/home/steam/valheim
ExecStart=/home/steam/valheim/start_server.sh
Restart=on-failure
RestartSec=10
LimitNOFILE=100000

[Install]
WantedBy=multi-user.target
EOF

systemctl daemon-reload
systemctl enable --now valheim
```

Check it's running:

```bash
systemctl status valheim
journalctl -u valheim -f
```

Wait for `"Game server connected"` in the logs — first boot takes a minute or two to generate the world.

## 8. Install playit.gg

```bash
# as root
curl -SsL https://playit.gg/downloads/playit-linux-amd64 -o /usr/local/bin/playit
chmod +x /usr/local/bin/playit
```

### First run (interactive — sets up your account link)

```bash
playit
```

This prints a URL — open it in your browser, sign in / create a playit.gg account, and claim the agent.

### Create a tunnel

In the playit.gg web dashboard (<https://playit.gg/account/tunnels>):

1. **Add Tunnel**
2. Game type: **Valheim** (or custom UDP)
3. Port: **2456**
4. Protocol: **UDP**
5. It assigns you a public address like `something.at.playit.gg:12345`

### Systemd service for playit

```bash
cat > /etc/systemd/system/playit.service << 'EOF'
[Unit]
Description=playit.gg tunnel agent
After=network.target

[Service]
Type=simple
ExecStart=/usr/local/bin/playit
Restart=on-failure
RestartSec=5

[Install]
WantedBy=multi-user.target
EOF

systemctl daemon-reload
systemctl enable --now playit
```

## 9. Connect

Friends add the server in Valheim:

- **Join Game → Add Server**
- Enter the `something.at.playit.gg:12345` address from playit dashboard
- Enter the server password

## 10. Updating the Server

```bash
systemctl stop valheim

su - steam -c 'steamcmd +@sSteamCmdForcePlatformType linux \
  +force_install_dir /home/steam/valheim \
  +login anonymous \
  +app_update 896660 validate \
  +quit'

systemctl start valheim
```

## 11. Backups

World saves live at `/home/steam/.config/unity3d/IronGate/Valheim/worlds_local/`.

Simple cron backup:

```bash
# as root
cat > /etc/cron.d/valheim-backup << 'EOF'
0 */6 * * * steam tar czf /home/steam/valheim-worlds-backup-$(date +\%Y\%m\%d-\%H\%M).tar.gz -C /home/steam/.config/unity3d/IronGate/Valheim worlds_local
EOF
```

## Resource Usage

- **Disk:** ~3 GB server + world saves — well within 20 GB
- **RAM:** 2–4 GB typical for a small group (6 GB allocation gives headroom)
- **CPU:** light — Valheim server is not CPU-intensive
- **Network:** negligible (<100 Kbps even with 10 players)
