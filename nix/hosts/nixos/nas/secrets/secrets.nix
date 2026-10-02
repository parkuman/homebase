let
  parker-m3 = (import ../../../../lib/ssh-keys.nix).userKeys.parker-m3;
  nas = (import ../../../../lib/ssh-keys.nix).hostKeys.nas;
  recipients = [parker-m3 nas];
in {
  "restic-password.age".publicKeys = recipients;
}

