{
  pkgs,
  ...
}:
{
  imports = [ ../../../modules/darwin ];
  system.stateVersion = 5;
  environment.systemPackages = with pkgs; [
    vault
  ];

  unfreePackages = [ 
    "vault" 
  ];
}
