### Liveness Probes

A **liveness probe** tells the kubelet how to check that a container still works. When the check fails a few times in a row, the kubelet restarts the container. (A readiness probe, in [23-readiness-probe.md](./23-readiness-probe.md), only takes the pod out of its services instead.)

#### A command probe that fails

```yaml
apiVersion: v1
kind: Pod
metadata:
  name: liveness
spec:
  containers:
  - name: liveness
    image: ubuntu
    tty: true
    livenessProbe:
      exec:
        command:
        - service
        - nginx
        - status
      initialDelaySeconds: 20
      periodSeconds: 5
```

This is also the file [`22-liveness-probes-livenessprobe.yaml`](./22-liveness-probes-livenessprobe.yaml) in this folder: `kubectl apply -f 22-liveness-probes-livenessprobe.yaml`

The probe runs `service nginx status` in the container every 5 seconds, after waiting 20. nginx is not installed in this `ubuntu` container, so the check fails and the container is restarted again and again:

```sh
kubectl get pod liveness -w          # RESTARTS goes up every half minute or so; Ctrl+C to stop
kubectl describe pod liveness | grep -A10 Events
```

The events show `Liveness probe failed` and `Container liveness failed liveness probe, will be restarted`.

```sh
kubectl delete pod liveness
```

#### An HTTP probe

```yaml
apiVersion: v1
kind: Pod
metadata:
  name: liveness-exec
spec:
  containers:
  - name: liveness
    image: nginx
    ports:
    - containerPort: 80
    livenessProbe:
      httpGet:
         path: /kplabs.html
         port: 80
      initialDelaySeconds: 60
      periodSeconds: 5
```

This is also the file [`22-liveness-probes-liveness-http.yaml`](./22-liveness-probes-liveness-http.yaml) in this folder: `kubectl apply -f 22-liveness-probes-liveness-http.yaml`

After 60 seconds the kubelet requests `/kplabs.html` from nginx every 5 seconds. The page does not exist (`404`), so the container would be restarted. Create it within the first minute and the probe passes:

```sh
kubectl exec liveness-exec -- sh -c 'echo ok > /usr/share/nginx/html/kplabs.html'
kubectl get pod liveness-exec -w     # RESTARTS stays 0; Ctrl+C to stop
```

A restart starts the container from its image again, so if you are too late the page is gone with the old container and the restarts go on; delete the pod and try again.

```sh
kubectl delete pod liveness-exec
```
