# NixOS Server Cluster

A declarative multi-node NixOS cluster running k3s on cloud servers.
All nodes share a common configuration base and are managed from this single
repository. Nodes pull and apply changes themselves via `git pull &&
nixos-rebuild switch`.

---

## Architecture

```
Internet
    |
    | (SSH only -- all other ports blocked)
    |
+--------+   +--------+   +--------+   +--------+
| node   |   | node   |   | node   |   | node   |
+---+----+   +---+----+   +---+----+   +---+----+
    |             |             |             |
    +-------------+-------------+-------------+
                  |
          Tailscale mesh
          All inter-node traffic travels here.
          Firewall fully trusts tailscale0.
                  |
    +-------------+-------------+-------------+
    |             |             |             |
+---+----+   +---+----+   +---+----+   +---+----+
| Flannel|   | Flannel|   | Flannel|   | Flannel|
| VXLAN  |   | VXLAN  |   | VXLAN  |   | VXLAN  |
| 10.42.x|   | 10.42.x|   | 10.42.x|   | 10.42.x|
+--------+   +--------+   +--------+   +--------+
```

Nodes communicate exclusively over Tailscale. The public NIC accepts only SSH.
Flannel runs VXLAN over `tailscale0` so pod traffic never crosses the public
internet unencrypted.

Public-facing services are exposed through Cloudflare Tunnels. `cloudflared`
connects outbound from each node to Cloudflare's edge, so no inbound ports
beyond SSH need to be opened.

---

## Node Roles

Nodes are split into two roles, configured in `config.nix`:

**Control plane** -- runs the k3s API server and etcd. At least two control
plane nodes are recommended for high availability. One node is designated the
init node and bootstraps the cluster; others join it.

**Workers** -- run workloads only. Any hostname listed in `workerNodes` inside
`config.nix` is treated as a worker.

---

## Boot Sequence

```
network-online.target
        |
        v
doppler-secrets.service      Fetches secrets from Doppler, writes to
        |                    /run/secrets/ (tmpfs, cleared on reboot).
        |
        +----------+
        |          |
        v          v
tailscaled      k3s.service
        |
        v
glusterd.service
        |
        v
glusterfs-mount.service      Retry loop until glusterd connects to peers.
```

Doppler runs first because both Tailscale and k3s need their tokens before
they can start. Nothing sensitive lives on disk or in this repository.

---

## Secrets

Doppler is the single source of truth. Each node holds only one file on disk:
`/etc/doppler-token`, placed manually during provisioning and never committed
to git.

At boot, `doppler-secrets.service` fetches all required secrets and writes
them to `/run/secrets/`. The secrets expected are:

| Secret                  | Used by              |
|-------------------------|----------------------|
| K3S_TOKEN               | k3s cluster join     |
| TAILSCALE_AUTH_KEY      | Tailscale node auth  |
| CLUSTER_SSH_PRIVATE_KEY | Inter-node SSH       |
| CLUSTER_SSH_PUB_KEY     | Inter-node SSH auth  |

---

## Storage

**Longhorn** provides distributed block storage for Kubernetes persistent
volumes. Every node runs open-iscsi and the Longhorn CSI components. Volumes
are replicated across nodes over the pod network.

**GlusterFS** provides a shared POSIX filesystem mounted at `/mnt/storage` on
every node. The volume is replicated across all nodes. The mount is retried in
a loop after glusterd starts, because Tailscale connectivity may not be
established immediately.

---

## Security

**Firewall** -- default REJECT policy. Only SSH is open on public interfaces.
`tailscale0` is fully trusted.

**fail2ban** -- permanent ban after 2 failed SSH attempts. The Tailscale CGNAT
range is excluded to avoid banning legitimate inter-node traffic.

**SSH** -- password authentication and root login disabled. Key-only access.
Forwarding (X11, TCP, agent) disabled. Max 3 auth tries per connection.

**Kernel hardening** -- ICMP redirect and source routing disabled, reverse
path filtering enabled, SYN cookies enabled, kernel pointer and dmesg access
restricted, ASLR at full randomization, ptrace scope restricted.

**Blacklisted modules** -- uncommon filesystems, USB storage, and unused
network protocols are prevented from loading.

---

## Repository Structure

```
.
+-- flake.nix              Entry point. One NixOS config per host.
+-- config.nix             Local config (gitignored). nodeIPs, adminUser,
|                          sshKeys, workerNodes.
+-- config.nix.example     Template for config.nix.
+-- hosts/
|   +-- <hostname>/        Host-specific config (hardware, hostname).
+-- modules/
    +-- common.nix         Shared config: networking, SSH, fail2ban,
    |                      Tailscale, vnstat, NTP, sysctl tuning.
    +-- k3s.nix            k3s role assignment and cluster flags.
    +-- security.nix       Firewall, kernel hardening, blacklisted modules.
    +-- longhorn.nix       open-iscsi and path setup for Longhorn.
    +-- glusterfs.nix      GlusterFS daemon and /mnt/storage mount.
    +-- doppler.nix        Boot-time secret fetch from Doppler.
```

---

## Adding a Node

1. Provision a server and install NixOS.
2. Place `/etc/doppler-token` on the new node.
3. Add the node's hostname and Tailscale IP to `config.nix` under `nodeIPs`.
4. Add to `workerNodes` if it should be a worker, otherwise it becomes a
   control plane node.
5. Create `hosts/<hostname>/default.nix` (copy from an existing host).
6. Run `nixos-rebuild switch` on the new node.
7. Peer the node into the GlusterFS volume if shared storage is needed.
