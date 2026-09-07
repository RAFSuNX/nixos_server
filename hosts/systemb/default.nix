# k3s join node, control-plane, etcd
{ ... }:
{
  imports = [ ./hardware-configuration.nix ];
  networking.hostName = "systemb";
}
