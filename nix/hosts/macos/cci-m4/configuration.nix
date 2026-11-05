{
  pkgs,
  ...
}:
{
  imports = [ ../../../modules/darwin ];
  system.stateVersion = 5;
  environment.systemPackages = with pkgs; [ /* specific to this machine */ ];
}
