#!/bin/bash
# Runs before kind's entrypoint and systemd, inside the node container only.
# - Swap: the Docker host's swap shows up in /proc/swaps, and the kubelet refuses to start
#   with swap on. Hide it from this container, so `swapoff -a` has nothing to do here and the
#   host's swap is left alone.
# - Kernel modules: the host has no /lib/modules for its kernel, so `modprobe overlay` and
#   `modprobe br_netfilter` would fail although both are built into it. List them as built-in.
set -u
: > /run/cka-swaps 2>/dev/null || { mkdir -p /run; : > /run/cka-swaps; }
printf 'Filename\t\t\t\tType\t\tSize\t\tUsed\t\tPriority\n' > /run/cka-swaps
mount --bind /run/cka-swaps /proc/swaps 2>/dev/null || true
rel=$(uname -r)
if [ ! -e "/lib/modules/$rel/modules.dep" ]; then
  mkdir -p "/lib/modules/$rel"
  printf '%s\n' kernel/fs/overlayfs/overlay.ko kernel/net/bridge/br_netfilter.ko kernel/net/bridge/bridge.ko \
    kernel/net/netfilter/nf_conntrack.ko kernel/net/ipv4/netfilter/ip_tables.ko > "/lib/modules/$rel/modules.builtin"
  : > "/lib/modules/$rel/modules.order"
  depmod "$rel" 2>/dev/null || true
fi
# - /etc/hosts: Docker rewrites it when the container restarts; put back what the learner had
#   (saved at shutdown by cka-keep-hosts.service), as a reboot on a VM would keep it.
[ -s /var/lib/cka-hosts ] && cat /var/lib/cka-hosts > /etc/hosts
exec "$@"
