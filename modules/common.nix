{ config, lib, pkgs, nodeIPs, adminUser, ... }:

{
  boot.loader = {
    systemd-boot = {
      enable             = true;
      configurationLimit = 1;
    };
    efi.canTouchEfiVariables = true;
    timeout = 0;
  };

  networking.networkmanager.enable = true;
  networking.networkmanager.dns    = "none";  # NixOS owns resolv.conf, not NM
  networking.nameservers = [ "1.1.1.1" "1.0.0.1" "9.9.9.9" ];

  # maps other nodes' tailscale IPs to hostnames, skips self
  networking.hosts = lib.filterAttrs
    (_ip: names: !(builtins.elem config.networking.hostName names))
    (lib.mapAttrs' (name: ip: lib.nameValuePair ip [ name ]) nodeIPs);

  users.users.${adminUser} = {
    isNormalUser = true;
    extraGroups  = [ "wheel" ];
  };

  security.sudo.wheelNeedsPassword = false;

  services.fail2ban = {
    enable    = true;
    maxretry  = 2;
    bantime   = "-1";
    ignoreIP  = [ "100.64.0.0/10" "127.0.0.1/8" ];  # Tailscale CGNAT range
    jails.sshd.settings = {
      enabled = true;
      port    = "ssh";
      filter  = "sshd";
    };
  };

  services.openssh = {
    enable = true;
    settings = {
      PasswordAuthentication = false;
      PermitRootLogin        = "no";
      AllowUsers             = [ adminUser ];
      PerSourcePenalties     = "no";
      MaxAuthTries           = 3;
      LoginGraceTime         = 60;
      MaxSessions            = 10;
      ClientAliveInterval    = 300;
      ClientAliveCountMax    = 2;
      X11Forwarding          = false;
      AllowTcpForwarding     = false;
      AllowAgentForwarding   = false;
      PermitUserEnvironment  = false;
      MaxStartups            = "10:30:100";
    };
  };

  boot.kernelModules = [ "vxlan" ];  # tcp_bbr auto-loaded by congestion_control sysctl

  boot.kernel.sysctl = {
    "net.ipv4.ip_forward"                = 1;
    "net.ipv6.conf.all.forwarding"       = 1;
    "net.core.rmem_max"                  = 134217728;
    "net.core.wmem_max"                  = 134217728;
    "net.ipv4.tcp_rmem"                  = "4096 87380 67108864";
    "net.ipv4.tcp_wmem"                  = "4096 65536 67108864";
    "net.ipv4.tcp_congestion_control"    = "bbr";
    "net.core.default_qdisc"             = "fq";
    "net.ipv4.tcp_fastopen"              = 3;
    "net.ipv4.tcp_mtu_probing"           = 1;
    "net.ipv4.tcp_slow_start_after_idle" = 0;
  };

  services.tailscale = {
    enable      = true;
    authKeyFile = "/run/secrets/tailscale_authkey";
    extraUpFlags = [
      "--advertise-exit-node"
      "--hostname=${config.networking.hostName}"
      "--netfilter-mode=off"
      "--accept-dns=false"
    ];
  };

  # env var sets MTU inside tailscaled — ip link set loses on tailscale reconnect
  systemd.services.tailscaled.environment.TS_DEBUG_MTU = "8000";

  # UDP GRO forwarding on public NIC — required for Tailscale exit node performance
  networking.localCommands = ''
    iface=$(${pkgs.iproute2}/bin/ip route show default | grep -oP 'dev \K\S+' | head -1)
    ${pkgs.ethtool}/bin/ethtool -K "$iface" rx-udp-gro-forwarding on rx-gro-list off || true
  '';

  services.vnstat.enable = true;

  nix.settings = {
    experimental-features = [ "nix-command" "flakes" ];
    auto-optimise-store   = true;
  };

  services.timesyncd.servers = [
    "0.pool.ntp.org" "1.pool.ntp.org" "2.pool.ntp.org" "3.pool.ntp.org"
  ];

  environment.systemPackages = with pkgs; [ git curl iperf3 ffmpeg-full tmux ethtool ];

  time.timeZone = "UTC";

  system.stateVersion = "26.05";
}
