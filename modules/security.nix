{ ... }:

{
  networking.firewall = {
    allowedTCPPorts   = [ 22 ];
    trustedInterfaces = [ "tailscale0" ];
  };

  boot.kernel.sysctl = {
    "net.ipv4.conf.all.src_valid_mark"          = 1;
    "net.ipv4.conf.all.accept_redirects"        = 0;
    "net.ipv4.conf.default.accept_redirects"    = 0;
    "net.ipv6.conf.all.accept_redirects"        = 0;
    "net.ipv6.conf.default.accept_redirects"    = 0;
    "net.ipv4.conf.all.send_redirects"          = 0;
    "net.ipv4.conf.default.send_redirects"      = 0;
    "net.ipv4.conf.all.rp_filter"               = 1;
    "net.ipv4.conf.default.rp_filter"           = 1;
    "net.ipv4.tcp_syncookies"                   = 1;
    "net.ipv4.conf.all.accept_source_route"     = 0;
    "net.ipv4.conf.default.accept_source_route" = 0;
    "kernel.kptr_restrict"                      = 2;
    "kernel.dmesg_restrict"                     = 1;
    "kernel.randomize_va_space"                 = 2;
    "net.ipv4.icmp_echo_ignore_broadcasts"      = 1;
    "kernel.sysrq"                              = 0;
    "net.ipv4.tcp_timestamps"                   = 0;
    "net.ipv4.conf.all.log_martians"            = 1;
    "net.ipv4.conf.default.log_martians"        = 1;
    "net.ipv4.icmp_ignore_bogus_error_responses" = 1;
    "kernel.yama.ptrace_scope"                  = 1;
    "kernel.core_uses_pid"                      = 1;
    "fs.suid_dumpable"                          = 0;
    "fs.protected_hardlinks"                    = 1;
    "fs.protected_symlinks"                     = 1;
    "vm.mmap_min_addr"                          = 65536;
  };

  boot.blacklistedKernelModules = [
    "cramfs" "freevxfs" "jffs2" "hfs" "hfsplus" "udf"
    "usb_storage"
    "dccp" "sctp" "rds" "tipc"
  ];
}
