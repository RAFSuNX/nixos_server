{ config, lib, pkgs, nodeIPs, workerNodes, ... }:

let
  initNode   = "systema";
  hostname   = config.networking.hostName;
  isInitNode = hostname == initNode;
  isWorker   = builtins.elem hostname workerNodes;

  tlsSans = map (n: "--tls-san=${n}") (builtins.attrNames nodeIPs);

  flannelConf = pkgs.writeText "flannel-conf.json" (builtins.toJSON {
    Network      = "10.42.0.0/16";
    EnableIPv4   = true;
    EnableIPv6   = false;
    IPv6Network  = "::/0";
    Backend      = { Type = "vxlan"; MTU = 7950; };
  });

  serverFlags = [
    "--disable=traefik"
    "--disable=local-storage"
    "--disable=servicelb"
    "--disable-cloud-controller"
    "--flannel-iface=tailscale0"
    "--flannel-conf=${flannelConf}"
    "--node-ip=${nodeIPs.${hostname}}"
    "--advertise-address=${nodeIPs.${hostname}}"
    "--node-external-ip=${nodeIPs.${hostname}}"
    "--write-kubeconfig-mode=0644"
  ] ++ tlsSans;

  agentFlags = [
    "--flannel-iface=tailscale0"
    "--node-ip=${nodeIPs.${hostname}}"
    "--node-external-ip=${nodeIPs.${hostname}}"
  ];
in
{
  services.k3s = {
    enable    = true;
    package   = pkgs.k3s_1_36;
    role      = if isWorker then "agent" else "server";
    tokenFile = "/run/secrets/k3s_token";

    extraFlags = if isWorker then
      [ "--server=https://${initNode}:6443" ] ++ agentFlags
    else if isInitNode then
      [ "--cluster-init" ] ++ serverFlags
    else
      [ "--server=https://${initNode}:6443" ] ++ serverFlags;
  };

  systemd.services.k3s = {
    after = [ "tailscaled.service" "doppler-secrets.service" ];
    wants = [ "tailscaled.service" "doppler-secrets.service" ];
  };

  environment.variables.KUBECONFIG = "/etc/rancher/k3s/k3s.yaml";

  environment.systemPackages = with pkgs; [ kubectl k9s ];
}
