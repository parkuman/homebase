# Ragenix

`ragenix` is like `agenix` but rust. It is used to take age-encrypted secrets
and use them within nix conveniently. It can use SSH keys from hosts to
encrypt files that can then be used later.

## How encrpyting works

Rather than managing GPG keyrings and putting public keys in some `.sops.yaml` file,
age just uses SSH keys to encrypt. A `secrets.nix` file determines which recipients (SSH keys)
are allowed to decrypt a certain file.

## Encrypting a new secret

```bash
nix shell nixpkgs#ragenix
ragenix -e file.age # in the same dir as secrets.nix
```
