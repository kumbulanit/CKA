# A bare Ubuntu 24.04 server as a container: systemd, SSH, sudo and the packages a fresh server
# has, but no container runtime and no Kubernetes, so the installation lesson works as on a VM.
# one-server.sh builds it and runs controlplane, node01 and node02 from it on one Ubuntu server.
# kind's entrypoint (copied from its node image) makes systemd, cgroups and containerd work inside
# a container; prepare-node.sh handles swap and kernel modules, kube-proxy-fix.sh the conntrack limit.
FROM kindest/node:v1.36.4 AS kind

FROM ubuntu:24.04
ENV container=docker DEBIAN_FRONTEND=noninteractive
# The package lists are kept, as on an installed server, so `apt install` works straight away.
RUN apt-get update \
 && apt-get install -y --no-install-recommends \
      systemd systemd-sysv dbus udev kmod iproute2 iptables ethtool conntrack socat ebtables \
      openssh-server openssh-client sudo ca-certificates curl wget gpg gnupg less vim nano jq \
      bash-completion procps iputils-ping dnsutils netcat-openbsd net-tools openssl lsb-release \
      apt-utils hostname git \
 && apt-get clean \
 && find /lib/systemd/system/sysinit.target.wants/ -name 'systemd-tmpfiles-setup.service' -delete \
 && rm -f /lib/systemd/system/multi-user.target.wants/* /etc/systemd/system/*.wants/* \
          /lib/systemd/system/local-fs.target.wants/* /lib/systemd/system/sockets.target.wants/*udev* \
          /lib/systemd/system/sockets.target.wants/*initctl* /lib/systemd/system/basic.target.wants/* \
 && systemctl enable ssh \
 && sed -i -E 's/^#?PermitRootLogin .*/PermitRootLogin prohibit-password/; s/^#?PasswordAuthentication .*/PasswordAuthentication no/' /etc/ssh/sshd_config \
 && echo 'ReadKMsg=no' >> /etc/systemd/journald.conf \
 && apt-get update

COPY --from=kind /usr/local/bin/entrypoint /usr/local/bin/entrypoint
COPY prepare-node.sh /usr/local/bin/prepare-node
COPY kube-proxy-fix.sh /usr/local/bin/cka-kube-proxy-fix
COPY kube-proxy-fix.service /etc/systemd/system/cka-kube-proxy-fix.service
COPY keep-hosts.service /etc/systemd/system/cka-keep-hosts.service
RUN chmod 755 /usr/local/bin/prepare-node /usr/local/bin/entrypoint /usr/local/bin/cka-kube-proxy-fix \
 && systemctl enable cka-kube-proxy-fix cka-keep-hosts \
 && install -d -m 755 /kind

STOPSIGNAL SIGRTMIN+3
ENTRYPOINT ["/usr/local/bin/prepare-node", "/usr/local/bin/entrypoint", "/sbin/init"]
