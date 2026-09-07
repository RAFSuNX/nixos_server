# =============================================================================
# NixOS Cluster Flake
# =============================================================================
# Five-node aarch64 cluster.
#
# Nodes:
#   - systema  (k3s init / control-plane / etcd)
#   - systemb  (k3s join / control-plane / etcd)
#   - systemc  (k3s join / control-plane / etcd)
#   - systemd  (k3s worker)
#   - systeme  (k3s worker)
#
# Secrets: managed by Doppler, written to /run/secrets/ at boot.
# =============================================================================

{
  description = "NixOS cluster — systema / systemb / systemc / systemd / systeme";

  inputs.nixpkgs.url = "github:NixOS/nixpkgs/nixos-26.05";

  outputs = { self, nixpkgs }: {

    nixosConfigurations =
      let
        # Local config — gitignored, copy from config.nix.example
        cfg = import ./config.nix;

        mkHost = hostname: nixpkgs.lib.nixosSystem {
          system = "aarch64-linux";
          specialArgs = { inherit (cfg) nodeIPs adminUser; workerNodes = cfg.workerNodes or []; };
          modules = [
            ./hosts/${hostname}
            ./modules/common.nix
            ./modules/k3s.nix
            ./modules/glusterfs.nix
            ./modules/longhorn.nix
            ./modules/security.nix
            ./modules/doppler.nix
            # SSH keys from config.nix — not in git
            { users.users.${cfg.adminUser}.openssh.authorizedKeys.keys = cfg.sshKeys.${hostname}; }
          ];
        };
      in {
        systema = mkHost "systema";
        systemb = mkHost "systemb";
        systemc = mkHost "systemc";
        systemd = mkHost "systemd";
        systeme = mkHost "systeme";
      };

  };
}
