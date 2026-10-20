# Buddy backup with dad

## Setting it up

We both sign up for tailscale

He didn't have an account so he had to make one with an identity provider. No email/pass is gross>

He shares his NAS with me, I share my NAS with him.

We create a new thick volume on his NAS called `parker_backup`.
Within that we created a 'shared folder' called `backup`.

I backup my `/tank/drive` only - media isn't backed up as of writing. It is saved on the QNAP at `/share/backup/restic/nas`

### Machine user on QNAP

Created a new user named `nasty-pee`. This is my machine user my NAS will use to
transfer files.

- nasty-pee was a normal restricted QNAP user.
- a member of everyone group only (not administrators)
- Given Read/Write permission on the backup shared folder only, via QNAP's own share-permission system

### Realizing that ssh settings get wiped on QNAP restart

I realized that ssh settings on the QNAP kept getting wiped on restarts, so nasty-pee couldn't ssh/sftp in. I also found that the QuFTP app wouldn't allow SFTP as a protocol so gave up there.

The plan was then:

- container station restic server

```yaml
services:
  rest-server:
    image: restic/rest-server:0.14.0
    container_name: parker-restic-backup-server
    restart: unless-stopped
    ports:
      - "8000:8000"
    environment:
      OPTIONS: "--private-repos"
    volumes:
      - /share/backup/restic:/data
```

Before starting it, it needs a `.htpasswd` file in `/data`. This username and password is what my NAS will use to login to this one.

On my machine I ran:

```bash
htpasswd -B -c .htpasswd nas
# type in password
```

Then on the QNAP i ssh'ed in as administrator and ran

```bash
printf '%s\n' 'CONTENTS_OF_HTPASSWD' | sudo tee /share/backup/restic/.htpasswd >/dev/null
```

Then started the container.

Then for nix/age setup i ran:

```bash
cd homebase/nix/hosts/nixos/nas/secrets
nix shell nixpkgs#ragenix -c ragenix -e restic-qnap-rest-container-htpasswd.age
# opens nano

RESTIC_REST_USERNAME=nas
RESTIC_REST_PASSWORD=the-password-i-chose

# save and exit
```

## Secrets

There are two secrets to manage with Restic:

1. the restic repo password
2. the rest-server nas user .htpasswd

Both are in my password manager.

## Tailscale key expiry

If either of the Tailscale keys expire this will stop working. I disabled key expiry on my NAS and let dad know to do the same.

## Runbook

### Restore a file (NAS is okay tho)

```bash
sudo restic-dad snapshots
sudo restic-dad ls latest | head # list files in the latest snapshot
sudo restic-dad restore latest --target /tmp/restore --include /tank/drive/path/to/file
```

### NAS is dead, restore files elsewhere

```bash
export RESTIC_REPOSITORY=rest:http://100.127.86.79:8000/nas/
export RESTIC_REST_USERNAME=nas
export RESTIC_REST_PASSWORD=<from password manager>
export RESTIC_PASSWORD=<repo password from password manager>
restic snapshots
restic restore latest --target /some/dir
```

### Backup is failing

```bash
systemctl status restic-backups-dad
journalctl -u restic-backups-dad -n 50
```

### Rotate the rest-server password

- Run `htpasswd -B` again.
- Replace `/share/backup/restic/.htpasswd` on QNAP again.
- edit the ragenix secret
- update password manager
- rebuild the NAS
- restart the container on QNAP

### Reinstalled the NAS

The SSH key is regenerated, so it can't decrypt the secrets that were assigned to it's old key.

Put the new host public key in `ssh-keys.nix`.

Run `run ragenix --rekey` from another trusted machine like my mac

### Routine checks

Run this every once and a while:

```bash
restic-dad check --read-data-subset=5%
```
