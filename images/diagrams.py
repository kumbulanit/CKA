#!/usr/bin/env python3
"""The course's diagrams, as plain SVG files (they render on GitHub and in Patchbay).

    python3 images/diagrams.py        # writes images/*.svg

Each diagram shows one mechanism a lab depends on. Edit the drawing functions below and run the
script again; the SVGs are generated, not edited by hand.
"""
import os

HERE = os.path.dirname(os.path.abspath(__file__))
FONT = 'font-family="-apple-system, Segoe UI, Helvetica, Arial, sans-serif"'
INK, MUTED, LINE, FILL = '#1f2933', '#616e7c', '#7b8794', '#f5f7fa'
ACCENT, ACCENT_FILL = '#2563eb', '#e8efff'   # the path the diagram is about
OK, OK_FILL = '#15803d', '#e7f6ec'
BAD, BAD_FILL = '#b91c1c', '#fdecec'
KINDS = {'': (LINE, FILL), 'accent': (ACCENT, ACCENT_FILL), 'ok': (OK, OK_FILL), 'bad': (BAD, BAD_FILL),
         'ghost': ('#cbd2d9', '#ffffff')}


class Svg:
    def __init__(self, w, h, title):
        self.w, self.h, self.title, self.parts = w, h, title, []

    def box(self, x, y, w, h, label, sub=None, kind=''):
        stroke, fill = KINDS[kind]
        dash = ' stroke-dasharray="5 4"' if kind == 'ghost' else ''
        self.parts.append(f'<rect x="{x}" y="{y}" width="{w}" height="{h}" rx="8" fill="{fill}" stroke="{stroke}" stroke-width="1.5"{dash}/>')
        cy = y + h / 2 + (-4 if sub else 5)
        self.text(x + w / 2, cy, label, size=13, weight=600, color=INK)
        if sub:
            for i, line in enumerate(sub.split('\n')):
                self.text(x + w / 2, cy + 17 + i * 15, line, size=11, color=MUTED)

    def text(self, x, y, s, size=12, weight=400, color=INK, anchor='middle'):
        s = s.replace('&', '&amp;').replace('<', '&lt;').replace('>', '&gt;')
        self.parts.append(f'<text x="{x}" y="{y}" font-size="{size}" font-weight="{weight}" fill="{color}" text-anchor="{anchor}">{s}</text>')

    def arrow(self, pts, label=None, at=None, kind='', dashed=False, below=False):
        """A line through pts, ending in an arrowhead. The label sits by segment `at` (default the middle one)."""
        color = {'': LINE, 'accent': ACCENT, 'ok': OK, 'bad': BAD}[kind]
        d = ' '.join(f'{x},{y}' for x, y in pts)
        dash = ' stroke-dasharray="6 4"' if dashed else ''
        self.parts.append(f'<polyline points="{d}" fill="none" stroke="{color}" stroke-width="{2 if kind else 1.6}"{dash} marker-end="url(#a-{kind or "n"})"/>')
        if label:
            i = at if at is not None else (len(pts) - 2) // 2
            (x1, y1), (x2, y2) = pts[i], pts[i + 1]
            mx, my = (x1 + x2) / 2, (y1 + y2) / 2
            if y1 == y2:   # horizontal: above (or below) the line
                for j, line in enumerate(label.split('\n')):
                    self.text(mx, my + (16 + j * 13 if below else -7 - (len(label.split('\n')) - 1 - j) * 13), line, size=11, color=color if kind else MUTED)
            else:          # vertical: to the right of the line
                for j, line in enumerate(label.split('\n')):
                    self.text(mx + 8, my + 4 + j * 13, line, size=11, color=color if kind else MUTED, anchor='start')

    def note(self, x, y, s, color=MUTED, anchor='start', size=11):
        for i, line in enumerate(s.split('\n')):
            self.text(x, y + i * 14, line, size=size, color=color, anchor=anchor)

    def save(self, name):
        marks = ''.join(
            f'<marker id="a-{k}" viewBox="0 0 10 10" refX="9" refY="5" markerWidth="7" markerHeight="7" orient="auto-start-reverse">'
            f'<path d="M0,0 L10,5 L0,10 z" fill="{c}"/></marker>'
            for k, c in (('n', LINE), ('accent', ACCENT), ('ok', OK), ('bad', BAD)))
        svg = (f'<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 {self.w} {self.h}" width="{self.w}" height="{self.h}" '
               f'role="img" aria-label="{self.title}" {FONT}><title>{self.title}</title><defs>{marks}</defs>'
               f'<rect width="100%" height="100%" fill="#ffffff"/>' + ''.join(self.parts) + '</svg>\n')
        with open(os.path.join(HERE, name), 'w') as f:
            f.write(svg)


def cluster():
    d = 24   # room above the boxes for the kubelet -> kube-apiserver arrow
    s = Svg(1000, 330 + d, 'A kubeadm cluster: what runs where, and who talks to whom')
    s.box(20, 30 + d, 470, 270, '', None, kind='ghost')
    s.text(255, 54 + d, 'controlplane', size=14, weight=700)
    s.box(40, 70 + d, 200, 56, 'kube-apiserver', 'every request goes here', kind='accent')
    s.box(270, 70 + d, 200, 56, 'etcd', 'the cluster state')
    s.box(40, 150 + d, 200, 56, 'kube-scheduler', 'picks a node')
    s.box(270, 150 + d, 200, 56, 'controller-manager', 'keeps replicas, nodes')
    s.box(40, 230 + d, 430, 50, 'kubelet + containerd', 'static pods: /etc/kubernetes/manifests')
    s.arrow([(240, 98 + d), (270, 98 + d)], None)
    s.arrow([(140, 150 + d), (140, 126 + d)], None)
    s.arrow([(370, 150 + d), (370, 126 + d), (240, 112 + d)], None)
    for i, n in enumerate(('node01', 'node02')):
        x = 560 + i * 220
        s.box(x, 30 + d, 200, 270, '', None, kind='ghost')
        s.text(x + 100, 54 + d, n, size=14, weight=700)
        s.box(x + 15, 70 + d, 170, 50, 'kubelet', 'runs this node’s pods', kind='accent')
        s.box(x + 15, 135 + d, 170, 50, 'kube-proxy', 'Service rules')
        s.box(x + 15, 200 + d, 170, 50, 'calico-node', 'pod network', kind='ok')
        s.text(x + 100, 282 + d, 'containerd · your pods', size=11, color=MUTED)
    s.arrow([(600, 70 + d), (600, 40), (100, 40), (100, 70 + d)], 'every kubelet watches the API server and reports its node', kind='accent')
    s.note(500, 320 + d, 'kubectl talks only to kube-apiserver; everything else watches it.', anchor='middle')
    s.save('cluster.svg')


def deployment():
    s = Svg(1000, 300, 'A Deployment manages ReplicaSets; a rollout moves pods from the old one to the new one')
    s.box(20, 110, 180, 70, 'Deployment', 'kplabs-deployment\nreplicas: 5', kind='accent')
    s.box(300, 40, 230, 64, 'ReplicaSet (revision 1)', 'image nginx · scaled to 0')
    s.box(300, 190, 230, 64, 'ReplicaSet (revision 2)', 'image nginx:1.17.3 · 5 pods', kind='ok')
    s.arrow([(200, 130), (300, 72)], 'old template')
    s.arrow([(200, 160), (300, 222)], 'new template', kind='ok', below=True)
    for i in range(5):
        s.box(620 + i * 72, 196, 60, 52, 'pod', None, kind='ok')
    for i in range(5):
        s.box(620 + i * 72, 46, 60, 52, 'pod', None, kind='ghost')
    s.arrow([(530, 222), (620, 222)], 'creates', kind='ok')
    s.arrow([(530, 72), (620, 72)], 'removes', dashed=True)
    s.arrow([(800, 98), (800, 196)], 'one at a time\n(rolling update)', kind='ok')
    s.note(20, 286, 'kubectl rollout undo --to-revision=1 scales revision 1 up again and revision 2 down: the old ReplicaSet was kept for this.')
    s.save('deployment-rollout.svg')


def services():
    s = Svg(1000, 330, 'How traffic reaches a pod: a Service selects pods by label; NodePort opens a port on every node')
    s.box(20, 40, 170, 56, 'frontend-pod', 'curl <ClusterIP>:8080')
    s.box(20, 200, 170, 56, 'Your browser', 'curl node01:30008')
    s.box(290, 120, 200, 76, 'Service', 'ClusterIP 10.96.x.x:8080\nselector app=myapp', kind='accent')
    s.box(290, 230, 200, 56, 'NodePort 30008', 'open on every node')
    s.box(590, 120, 150, 76, 'Endpoints', 'the IPs of matching,\nready pods', kind='accent')
    for i in range(3):
        s.box(820, 60 + i * 80, 160, 56, f'pod {i + 1}', 'app=myapp · :80', kind='ok')
    s.arrow([(190, 68), (240, 68), (240, 150), (290, 150)], None, kind='accent')
    s.arrow([(190, 228), (290, 255)], None)
    s.arrow([(390, 230), (390, 196)], 'kube-proxy')
    s.arrow([(490, 158), (590, 158)], 'looks up', kind='accent')
    for i in range(3):
        s.arrow([(740, 158), (820, 88 + i * 80)], None, kind='ok')
    s.note(590, 240, 'A pod joins the endpoints when its labels\nmatch the selector, whoever created it.\nNo endpoints = the selector matches nothing.')
    s.save('services.svg')


def ingress():
    s = Svg(1000, 300, 'Ingress: one node port, two websites, chosen by the HTTP Host header')
    s.box(20, 110, 190, 76, 'curl', '-H "Host: website01…"\nhttp://node01:30080')
    s.box(290, 100, 200, 96, 'ingress-nginx', 'controller pod\n(NodePort 30080)', kind='accent')
    s.box(570, 40, 180, 64, 'service1', 'ClusterIP :80')
    s.box(570, 190, 180, 64, 'service2', 'ClusterIP :80')
    s.box(820, 40, 160, 64, 'service-pod-1', '"This is Website 1"', kind='ok')
    s.box(820, 190, 160, 64, 'service-pod-2', '"This is Website 2"', kind='ok')
    s.arrow([(210, 148), (290, 148)], 'request', kind='accent')
    s.arrow([(490, 130), (570, 72)], None, kind='accent')
    s.arrow([(490, 166), (570, 222)], None)
    s.text(528, 92, 'website01', size=11, color=ACCENT)
    s.text(528, 212, 'website02', size=11, color=MUTED)
    s.arrow([(750, 72), (820, 72)], None, kind='ok')
    s.arrow([(750, 222), (820, 222)], None, kind='ok')
    s.note(290, 230, 'The Ingress (name-virtual-host-ingress)\nholds the rules; the controller follows them.')
    s.save('ingress.svg')


def scheduling():
    s = Svg(1000, 400, 'How a pod gets a node: the scheduler filters, then scores; nodeName and static pods skip it')
    s.box(20, 120, 150, 64, 'New pod', 'no nodeName yet')
    s.box(240, 40, 280, 224, '', None, kind='accent')
    s.text(380, 64, 'kube-scheduler: filter', size=13, weight=600)
    for i, (a, b) in enumerate((('taints', 'tolerated?'), ('nodeSelector / affinity', 'labels match?'),
                                ('resources', 'enough unrequested CPU, memory?'))):
        s.box(260, 80 + i * 58, 240, 46, a, b)
    s.box(580, 120, 120, 64, 'score', 'best node')
    s.box(800, 120, 180, 64, 'kubelet on node01', 'starts the pod', kind='ok')
    s.arrow([(170, 152), (240, 152)], None)
    s.arrow([(520, 152), (580, 152)], 'nodes left')
    s.arrow([(700, 152), (800, 152)], 'sets nodeName', kind='ok')
    s.note(20, 210, 'No node passes the filter:\nthe pod stays Pending\n(describe: FailedScheduling).', color=BAD)
    s.box(560, 290, 190, 56, 'nodeName: node01', 'in the manifest')
    s.arrow([(750, 318), (860, 318), (860, 184)], 'scheduler skipped', at=0, dashed=True)
    s.box(20, 290, 220, 56, 'Static pod', '/etc/kubernetes/manifests')
    s.arrow([(240, 318), (300, 318), (300, 368), (940, 368), (940, 184)], 'the kubelet reads the folder itself', at=1, dashed=True)
    s.save('scheduling.svg')


def upgrade():
    s = Svg(1000, 300, 'A kubeadm upgrade, one minor version: control plane first, then each worker in turn')
    steps = [('repo /v1.37/', 'apt update'), ('kubeadm', '1.37.1-1.1'), ('upgrade plan', 'check'), ('upgrade apply', 'control plane'),
             ('drain', 'move pods off'), ('kubelet, kubectl', 'restart'), ('uncordon', 'back in use')]
    x = 15
    s.text(20, 30, 'controlplane', size=13, weight=600, anchor='start')
    for i, (a, b) in enumerate(steps):
        s.box(x, 45, 125, 60, a, b, kind='accent' if a == 'upgrade apply' else '')
        if i:
            s.arrow([(x - 17, 75), (x, 75)])
        x += 142
    s.text(20, 165, 'node01, then node02', size=13, weight=600, anchor='start')
    wsteps = [('repo + kubeadm', 'on the worker'), ('upgrade node', 'kubelet config'), ('drain', 'from controlplane'),
              ('kubelet, kubectl', 'restart'), ('uncordon', 'from controlplane')]
    x = 15
    for i, (a, b) in enumerate(wsteps):
        s.box(x, 180, 150, 60, a, b, kind='accent' if a == 'upgrade node' else '')
        if i:
            s.arrow([(x - 17, 210), (x, 210)])
        x += 167
    s.note(20, 280, 'A kubelet may be older than the API server, never newer: that is why the control plane goes first.')
    s.save('upgrade.svg')


def rbac():
    s = Svg(1000, 320, 'RBAC: who (subject) may do what (role), where (binding)')
    s.box(20, 40, 220, 64, 'user zeal', 'client certificate, CN=zeal')
    s.box(20, 200, 220, 64, 'service account external', 'system:serviceaccount:default:external')
    s.box(330, 40, 220, 64, 'RoleBinding read-pods', 'namespace default only', kind='accent')
    s.box(330, 200, 220, 64, 'ClusterRoleBinding', 'every namespace')
    s.box(650, 120, 200, 64, 'Role / ClusterRole', 'pod-reader: list pods', kind='accent')
    s.box(880, 30, 100, 56, 'allowed', None, kind='ok')
    s.box(880, 230, 100, 56, 'Forbidden', 'no binding', kind='bad')
    s.arrow([(240, 72), (330, 72)], 'subject', kind='accent')
    s.arrow([(240, 232), (330, 232)], 'subject', below=True)
    s.arrow([(550, 80), (650, 140)], 'roleRef', kind='accent')
    s.arrow([(550, 224), (650, 164)], 'roleRef', below=True)
    s.arrow([(850, 140), (880, 70)], None, kind='ok')
    s.arrow([(850, 168), (880, 250)], None, kind='bad')
    s.note(20, 300, 'kubectl auth can-i list pods --as=system:serviceaccount:default:external answers the same question without curl.')
    s.save('rbac.svg')


def storage():
    s = Svg(1000, 300, 'Storage: a pod asks for a claim; the claim binds a volume, made by an admin or by a provisioner')
    s.box(20, 110, 150, 64, 'Pod mypod', 'mounts /var/www/html')
    s.box(250, 110, 170, 64, 'PVC myclaim', '1Gi · ReadWriteOnce', kind='accent')
    s.box(520, 30, 220, 64, 'PV pv-vol1', 'made by you (static)')
    s.box(520, 190, 220, 64, 'StorageClass local-path', 'provisioner makes a PV', kind='accent')
    s.box(820, 110, 160, 64, 'disk on the node', 'hostPath · /opt/...', kind='ok')
    s.arrow([(170, 142), (250, 142)], 'claimName')
    s.arrow([(420, 128), (520, 62)], None)
    s.note(455, 72, 'binds: size, mode,\nclass all match', anchor='end')
    s.arrow([(420, 156), (520, 222)], None, kind='accent')
    s.text(455, 222, 'storageClassName', size=11, color=ACCENT, anchor='end')
    s.arrow([(740, 62), (820, 130)], None, kind='ok')
    s.arrow([(740, 222), (820, 154)], None, kind='ok')
    s.note(250, 280, 'No match: the claim stays Pending. WaitForFirstConsumer waits for a pod before it binds.')
    s.save('storage.svg')


def metrics():
    s = Svg(1000, 290, 'Metrics and autoscaling: from each kubelet to kubectl top and the HPA')
    s.box(20, 110, 170, 64, 'kubelets', 'CPU, memory per pod')
    s.box(270, 110, 180, 64, 'metrics-server', '--kubelet-insecure-tls', kind='accent')
    s.box(530, 40, 170, 64, 'kubectl top', 'nodes, pods')
    s.box(530, 180, 170, 64, 'HPA nginx', '50% of the CPU request', kind='accent')
    s.box(790, 180, 190, 64, 'Deployment nginx', 'replicas 1 → up to 10', kind='ok')
    s.box(790, 40, 190, 64, 'load-generator', 'wget loop', kind='ghost')
    s.arrow([(270, 142), (190, 142)], 'scrapes', kind='accent')
    s.arrow([(450, 130), (530, 72)], None, kind='accent')
    s.text(478, 84, 'metrics API', size=11, color=ACCENT, anchor='end')
    s.arrow([(450, 156), (530, 212)], None, kind='accent')
    s.arrow([(700, 212), (790, 212)], 'scales', kind='ok')
    s.arrow([(885, 104), (885, 180)], 'traffic', dashed=True)
    s.save('metrics-hpa.svg')


def two_tier():
    s = Svg(1000, 320, 'The two-tier app of the troubleshooting labs, and where each scenario breaks it')
    s.box(20, 120, 150, 64, 'curl', 'http://node01:30081')
    s.box(240, 120, 170, 64, 'web-service', 'NodePort 30081 → 8080', kind='accent')
    s.box(480, 120, 170, 64, 'webapp-mysql', 'DB_Host=mysql-service\nDB_User=root')
    s.box(720, 120, 170, 64, 'mysql-service', '3306 → 3306\nselector name=mysql', kind='accent')
    s.box(720, 240, 170, 56, 'mysql pod', 'name=mysql · paswrd', kind='ok')
    s.arrow([(170, 152), (240, 152)], None)
    s.arrow([(410, 152), (480, 152)], None)
    s.arrow([(650, 152), (720, 152)], None)
    s.arrow([(805, 184), (805, 240)], None, kind='ok')
    for x, y, label in ((325, 100, 'zeta: nodePort'), (565, 100, 'delta, epsilon: user, password'),
                        (805, 100, 'alpha: name · beta: targetPort'), (900, 270, 'gamma: selector')):
        s.text(x if x != 900 else 900, y, label, size=11, color=BAD, anchor='middle' if x != 900 else 'start')
    s.note(20, 40, 'Check each hop in order: the node port, the web app’s settings, the Service’s name, port and\n'
                   'selector, then the database login. kubectl describe and the web page’s error say which hop fails.')
    s.save('two-tier-app.svg')


def network():
    s = Svg(1000, 290, 'Inside the cluster: DNS finds the Service, kube-proxy picks a pod, the CNI carries the packet')
    s.box(20, 110, 160, 64, 'webapp pod', 'connects to mysql-service')
    s.box(260, 30, 180, 64, 'CoreDNS', 'mysql-service →\n10.96.x.x', kind='accent')
    s.box(260, 190, 180, 64, 'kube-proxy rules', 'Service IP → pod IP', kind='accent')
    s.box(520, 190, 200, 64, 'CNI (Calico, kindnet)', 'routes between nodes', kind='accent')
    s.box(800, 190, 180, 64, 'mysql pod', 'on another node', kind='ok')
    s.arrow([(180, 128), (260, 62)], '1 lookup')
    s.arrow([(180, 156), (260, 222)], '2 connect', below=True)
    s.arrow([(440, 222), (520, 222)], '3')
    s.arrow([(720, 222), (800, 222)], '4', kind='ok')
    s.note(520, 60, 'No CNI: nodes NotReady, pods stuck in ContainerCreating.\nkube-proxy down: Service IPs lead nowhere.\nCoreDNS down: names do not resolve.', color=BAD)
    s.save('cluster-network.svg')


if __name__ == '__main__':
    for draw in (cluster, deployment, services, ingress, scheduling, upgrade, rbac, storage, metrics, two_tier, network):
        draw()
    print('wrote', len([f for f in os.listdir(HERE) if f.endswith('.svg')]), 'diagrams to', HERE)
