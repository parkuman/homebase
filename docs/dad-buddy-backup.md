# Buddy backup with dad

We both sign up for tailscale

He didn't have an account so he had to make one with an identity provider. No email/pass is gross>

He shares his NAS with me, I share my NAS with him.

We create a new thick volume on his NAS called `parker_backup`.
Within that we created a 'shared folder' called `backup`.

## Machine user

Created a new user named `nasty-pee`. This is my machine user my NAS will use to
transfer files.

- nasty-pee was a normal restricted QNAP user.
- a member of everyone group only (not administrators)
- Given Read/Write permission on the backup shared folder only, via QNAP's own share-permission system
- Had a password set, but no SSH key, and critically: no home directory actually existed on disk yet
  - `/etc/passwd` had an entry pointing at `/share/homes/nasty-pee`, but QNAP only creates that
    directory when you explicitly enable "Home Folder" for a user, which hadn't happened
- had to `mkdir -p /share/homes/nasty-pee/.ssh` create `authorized_keys` with the public key from the NAS pasted in
  - i noticed on a reboot this dir disappeared. Enabling the home folder feature in QNAP should fix this hopefully:
    - control panel > privilege > users > advanced > home folder
    - enable home folder for all users (check) > DataVol1 > apply
- QNAP's real SSH config has an AllowUsers allow-list
- This is what the UI's "only administrators can use SSH" warning actually meant (not a special SFTP restriction), just a plain AllowUsers admin administrator line blocking every other account. Had to add `nasty-pee` to it.
  - Gotcha: QNAP has a decoy `/etc/ssh/sshd_config` that isn't actually used the real
    one sshd was launched with is `/etc/config/ssh/sshd_config` (found
    via ps aux | grep sshd, looking at its -f flag)
- Result: `nasty-pee` can SSH/SFTP in, has RW on `backup` only but can list files elsewhere

## Realizing that ssh settings get wiped on QNAP restart

I realized that ssh settings on the QNAP kept getting wiped on restarts, so nasty-pee couldn't ssh/sftp in. I also found that the QuFTP app wouldn't allow SFTP as a protocol so gave up there.

New plan:

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
      OPTIONS: "--append-only --private-repos"
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
