{
  pkgs,
  lib,
  user,
  ...
}:

let
  isDarwin = pkgs.stdenv.isDarwin;
in

{
  programs.gpg = {
    enable = true;
    settings = {
      default-key = user.gpgKey;
    };
  };

  services.gpg-agent = {
    enable = true;
    pinentry.package = if isDarwin then pkgs.pinentry_mac else pkgs.pinentry-qt;
    # gpg-agent defaults to 10 min idle / 2 h max, so commit signing keeps
    # re-prompting.
    defaultCacheTtl = 31536000; # 1 year idle timeout
    maxCacheTtl = 31536000; # 1 year absolute cap
  };

  # A running gpg-agent does not notice gpg-agent.conf changing on
  # `home-manager switch` (the systemd unit is unchanged, so it is not
  # restarted), so it keeps the TTLs it read at startup. Reload it after
  # each switch so the new config takes effect.
  home.activation = lib.mkIf (!isDarwin) {
    reloadGpgAgent = lib.hm.dag.entryAfter [ "writeBoundary" ] ''
      ${pkgs.gnupg}/bin/gpgconf --reload gpg-agent 2>/dev/null || true
    '';
  };
}
