# SSH public keys for all machines
let
  userKeys = {
    parker-m3 = "ssh-rsa AAAAB3NzaC1yc2EAAAADAQABAAABgQDNz/e4xQTjh6iIfOw4zNJGxV+6uUv4eUY2IxTfsO9O0CEvKHpFKORpJNt2R0O+5UDDIE+6rtnwjI0l5X5huvZyud/HYKKT7kM4U7Z3joTr2kJLBUPz4PrJh+4mNfPuo6/qULmfx2hLfIen5SpvmYGMbR6Di/MRH21HbsZqjN/PCYsHQv/7wmWewxIodERV5iDNsYYH1zKt4XQfyTHVvBSBfFjeBIM7rsg/yGz6PX6zEW1dm7ga6FCvAgVJSoZ/L9OlCj9fu9RrNLmv9HOOEfAObBvo8UmyeaMbBiqnB9+tZL2BhxYq5njyKFvx6S24V1wLfHAZIjIDkhCSnIZ2B0Hg7aFs4BAvAca2YPrcb3DEhwDmEYYqX2g0LC6xnLL0fXyR2JfC+1wdPPKQC34OxsRnqN9fnEnOwwv+10EVWyrrBEFo3Y69HW1ABCsaR5S4xLqwXHgpeSiQaxOTfAGoc4LP+xKBsg819l/tC+vVshVV4J5xQvv9gtEu+GQ1gxi3RFs= parker@Parkers-MacBook-Pro-2.local";
  };
  hostKeys = {
    nas = "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIMLqwZGWiCG0dVHDGsCa2j0x9acGpdo8Zxuwe+/DGFrI root@nixos";
  };
in
{
  inherit userKeys hostKeys;
  sshKeys = builtins.attrValues userKeys;
}
