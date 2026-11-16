{
  pkgs,
  ...
}:
{
  imports = [ ../../../modules/darwin ];
  system.stateVersion = 5;
  environment.systemPackages = with pkgs; [
    vault
    postgresql
    circleci-cli
    github-cli
    # Rex is installed via DMG; expose its CLI on PATH (path has spaces, so wrap instead of systemPath)
    (writeShellScriptBin "rex" ''
      exec "/Applications/Rex Beta.app/Contents/Helpers/Rex Server.rex/Contents/MacOS/rex" "$@"
    '')
  ];

  unfreePackages = [ 
    "vault" 
  ];
}
