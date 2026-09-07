# NixOS Node Setup — Step by Step

Run these on a fresh NixOS install via serial console.

## Prerequisites
- Fresh NixOS install (default template)
- Doppler token ready (get from Doppler dashboard → k3s → prd → Service Tokens)

---

## Steps

### 1. Place Doppler token
```bash
echo "DOPPLER_TOKEN=dp.st.prd.xxxxxxxxxxxx" | sudo tee /etc/doppler-token
sudo chmod 600 /etc/doppler-token
```

### 2. Backup hardware config
```bash
sudo cp /etc/nixos/hardware-configuration.nix /tmp/hardware-configuration.nix
```

### 3. Clone config repo
```bash
sudo rm -rf /etc/nixos
sudo git clone -b server-nixos https://github.com/RAFSuNX/server-hub.git /etc/nixos
```

### 4. Restore hardware config
```bash
sudo cp /tmp/hardware-configuration.nix /etc/nixos/hosts/systema/hardware-configuration.nix
```
> For systemb/systemc replace `systema` with the correct hostname.

### 5. Create config.nix
```bash
sudo cp /etc/nixos/config.nix.example /etc/nixos/config.nix
sudo nano /etc/nixos/config.nix
```

See `config.nix.example` for the format. Fill in your real values.

### 6. Stage untracked files and rebuild
```bash
cd /etc/nixos
sudo git add -f config.nix hosts/systema/hardware-configuration.nix
sudo nixos-rebuild switch --flake /etc/nixos#systema
```

---

## After Rebuild

### 7. Update nodeIPs with real Tailscale IP
Once Tailscale connects, get the assigned IP:
```bash
sudo tailscale ip
```

Update `nodeIPs.systema` in `/etc/nixos/config.nix` with the real IP, then rebuild again:
```bash
sudo nixos-rebuild switch --flake /etc/nixos#systema
```

### 8. Verify everything is up
```bash
sudo systemctl status doppler-secrets
sudo systemctl status tailscaled
sudo systemctl status k3s
sudo fail2ban-client status sshd
```
