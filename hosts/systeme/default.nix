# k3s worker node
{ ... }:
{
  imports = [ ./hardware-configuration.nix ];
  networking.hostName = "systeme";
}
