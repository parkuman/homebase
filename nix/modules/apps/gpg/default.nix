{ pkgs, user, ... }:

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
}
