{ pkgs, adminUser, ... }:

# Requires /etc/doppler-token on each node containing:
#   DOPPLER_TOKEN=dp.st.prod.xxxxxxxxx
# Place this file once during initial provisioning. Everything else is automatic.
#
# Doppler secrets this module expects:
#   K3S_TOKEN               — k3s cluster join token
#   TAILSCALE_AUTH_KEY      — Tailscale auth key for initial node registration
#   CLUSTER_SSH_PRIVATE_KEY — Ed25519 private key shared across all nodes
#   CLUSTER_SSH_PUB_KEY     — Corresponding public key (authorizes inter-node SSH)

{
  environment.systemPackages = with pkgs; [ doppler ];

  systemd.tmpfiles.rules = [
    "d /run/secrets              0700 root       root       -"
    "d /home/${adminUser}/.ssh  0700 ${adminUser} ${adminUser} -"
  ];

  systemd.services.doppler-secrets = {
    description = "Fetch secrets from Doppler";
    wantedBy    = [ "multi-user.target" ];
    before      = [ "tailscaled.service" "tailscaled-autoconnect.service" "k3s.service" ];
    after       = [ "network-online.target" ];
    wants       = [ "network-online.target" ];

    serviceConfig = {
      Type             = "oneshot";
      RemainAfterExit  = true;
      Environment      = "HOME=/root";
      EnvironmentFile  = "/etc/doppler-token";
      TimeoutStartSec  = 30;
      ExecStart        = pkgs.writeShellScript "doppler-fetch" ''
        set -euo pipefail
        fetch() { ${pkgs.doppler}/bin/doppler secrets get "$1" --plain; }

        # Fetch all values first — if any fail, nothing gets written
        k3s_token=$(fetch K3S_TOKEN)
        ts_authkey=$(fetch TAILSCALE_AUTH_KEY)
        cluster_key=$(fetch CLUSTER_SSH_PRIVATE_KEY)
        cluster_pub=$(fetch CLUSTER_SSH_PUB_KEY)

        install -m600 /dev/null /run/secrets/k3s_token
        printf '%s' "$k3s_token" > /run/secrets/k3s_token

        install -m600 /dev/null /run/secrets/tailscale_authkey
        printf '%s' "$ts_authkey" > /run/secrets/tailscale_authkey

        mkdir -p /home/${adminUser}/.ssh
        chown ${adminUser}:users /home/${adminUser}/.ssh
        chmod 700 /home/${adminUser}/.ssh
        install -m600 -o ${adminUser} /dev/null /home/${adminUser}/.ssh/cluster_key
        printf '%s\n' "$cluster_key" > /home/${adminUser}/.ssh/cluster_key

        # Append cluster pub key to authorized_keys if not already present
        touch /home/${adminUser}/.ssh/authorized_keys
        chown ${adminUser}:users /home/${adminUser}/.ssh/authorized_keys
        chmod 600 /home/${adminUser}/.ssh/authorized_keys
        grep -qxF "$cluster_pub" /home/${adminUser}/.ssh/authorized_keys || printf '%s\n' "$cluster_pub" >> /home/${adminUser}/.ssh/authorized_keys
      '';
    };
  };

  programs.ssh.extraConfig = ''
    Host systema systemb systemc systemd systeme
      User ${adminUser}
      IdentityFile /home/${adminUser}/.ssh/cluster_key
      StrictHostKeyChecking accept-new
  '';
}
