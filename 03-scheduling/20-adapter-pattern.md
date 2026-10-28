### The Adapter Pattern

A pod can run helper containers next to the main one. In the **adapter pattern** the helper turns the main container's output into a standard form. Here the `count` container writes two log files in different formats, and a `count-agent` container (fluentd) reads both and writes them out in one place. The two containers share the `/var/log` volume; the ConfigMap holds fluentd's configuration.

```yaml
apiVersion: v1
kind: ConfigMap
metadata:
  name: fluentd-config
data:
  fluentd.conf: |
    <source>
      @type tail
      path /var/log/1.log
      pos_file /var/log/1.log.pos
      tag PHP
      <parse>
        @type none
      </parse>
    </source>
    <source>
      @type tail
      path /var/log/2.log
      pos_file /var/log/2.log.pos
      tag JAVA
      <parse>
        @type none
      </parse>
    </source>
    <match **>
      @type file
      path /var/log/fluent/access
    </match>
---
apiVersion: v1
kind: Pod
metadata:
  name: counter
spec:
  containers:
  - name: count
    image: busybox
    args:
    - /bin/sh
    - -c
    - >
      i=0;
      while true;
      do
        echo "$i: $(date)" >> /var/log/1.log;
        echo "$(date) INFO $i" >> /var/log/2.log;
        i=$((i+1));
        sleep 1;
      done
    volumeMounts:
    - name: varlog
      mountPath: /var/log
  - name: count-agent
    image: fluent/fluentd:v1.20-1
    command: ["fluentd", "-c", "/etc/fluentd-config/fluentd.conf"]
    volumeMounts:
    - name: varlog
      mountPath: /var/log
    - name: config-volume
      mountPath: /etc/fluentd-config
  volumes:
  - name: varlog
    emptyDir: {}
  - name: config-volume
    configMap:
      name: fluentd-config
```

This is also the file [`20-adapter-pattern.yaml`](./20-adapter-pattern.yaml) in this folder: `kubectl apply -f 20-adapter-pattern.yaml`

```sh
kubectl get pod counter
kubectl exec counter -c count -- tail -3 /var/log/1.log /var/log/2.log
kubectl logs counter -c count-agent
kubectl exec counter -c count -- ls /var/log/fluent
```

`READY 2/2` shows both containers running. The two log files have different formats; fluentd follows both and writes what it collects under `/var/log/fluent/`.

```sh
kubectl delete -f 20-adapter-pattern.yaml
```
