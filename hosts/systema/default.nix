# k3s init node, control-plane, etcd
{ ... }:
{
  imports = [ ./hardware-configuration.nix ];
  networking.hostName = "systema";
}
