{ pkgs, adminUser, ... }:

{
  services.glusterfs.enable = true;

  boot.kernelModules = [ "fuse" ];

  systemd.services.glusterd = {
    after = [ "tailscaled.service" ];
    wants = [ "tailscaled.service" ];
  };

  systemd.tmpfiles.rules = [
    "d /mnt/storage-brick 0775 ${adminUser} users -"
    "d /mnt/storage       0775 ${adminUser} users -"
  ];

  # noauto — boot-time mount is handled by glusterfs-mount below.
  # glusterd starts before it reconnects to peers over Tailscale, so a
  # one-shot mount right after glusterd.service starts fails on join nodes.
  fileSystems."/mnt/storage" = {
    device  = "localhost:/storage";
    fsType  = "glusterfs";
    options = [ "noauto" "_netdev" "backupvolfile-server=systema" ];
  };

  systemd.services.glusterfs-mount = {
    description = "Retry GlusterFS storage mount until glusterd is ready";
    after    = [ "network-online.target" "glusterd.service" ];
    wants    = [ "network-online.target" ];
    requires = [ "glusterd.service" ];
    wantedBy = [ "multi-user.target" ];
    serviceConfig = {
      Type            = "oneshot";
      RemainAfterExit = true;
      ExecStart       = pkgs.writeShellScript "glusterfs-mount" ''
        for i in $(seq 1 24); do
          ${pkgs.util-linux}/bin/mountpoint -q /mnt/storage && exit 0
          ${pkgs.util-linux}/bin/mount /mnt/storage && exit 0
          sleep 5
        done
        exit 1
      '';
    };
  };

}
