{ config, pkgs, ... }:

{
  services.openiscsi = {
    enable = true;
    name   = "iqn.2016-09.com.longhorn:${config.networking.hostName}";
  };

  boot.kernelModules = [ "iscsi_tcp" "dm_crypt" ];

  environment.systemPackages = with pkgs; [
    nfs-utils
    util-linux    # blkid, lsblk, findmnt — nsenter'd by Longhorn
    e2fsprogs     # mkfs.ext4 — default Longhorn volume fs
    cryptsetup    # required by preflight check even without encryption
  ];

  # NixOS bins live in the store; symlink standard paths so Longhorn's
  # nsenter calls find them after entering the host mount namespace.
  systemd.tmpfiles.rules = [
    "L+ /usr/bin/iscsiadm - - - - ${pkgs.openiscsi}/bin/iscsiadm"
    "L+ /usr/local/bin    - - - - /run/current-system/sw/bin"
  ];
}
