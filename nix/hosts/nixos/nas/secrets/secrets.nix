let
  parker-m3 = (import ../../../../lib/ssh-keys.nix).userKeys.parker-m3;
  nas = (import ../../../../lib/ssh-keys.nix).hostKeys.nas;
  recipients = [parker-m3 nas];
in {
  "restic-password.age".publicKeys = recipients;
  "restic-qnap-rest-container.age".publicKeys = recipients;
  "healthchecks-nas-to-qnap-url.age".publicKeys = recipients;
  "cloudflare-dns-token.age".publicKeys = recipients;
  "cloudflared-tunnel-immich.age".publicKeys = recipients;
}

