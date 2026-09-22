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
- QNAP's real SSH config has an AllowUsers allow-list
- This is what the UI's "only administrators can use SSH" warning actually meant (not a special SFTP restriction), just a plain AllowUsers admin administrator line blocking every other account. Had to add `nasty-pee` to it.
  - Gotcha: QNAP has a decoy `/etc/ssh/sshd_config` that isn't actually used the real
    one sshd was launched with is `/etc/config/ssh/sshd_config` (found
    via ps aux | grep sshd, looking at its -f flag)
- Result: `nasty-pee` can SSH/SFTP in, has RW on `backup` only but can list files elsewhere
