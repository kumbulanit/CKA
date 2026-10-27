#### Documentation Referred:

https://kubernetes.io/docs/tasks/configure-pod-container/security-context/

https://kubernetes.io/docs/concepts/services-networking/network-policies/

## Security Context

#### Step 1: Privileged and Non-Privileged Pods
Apply [privileged.yaml](./privileged.yaml): the pod `privileged` runs with `securityContext.privileged: true`, the pod `non-privileged` without it.
```sh
kubectl apply -f privileged.yaml
kubectl get pods
```
Compare what each container may do. A privileged container sees all the host's devices and has every capability:
```sh
kubectl exec privileged -- sh -c 'ls /dev | wc -l; grep CapEff /proc/1/status'
kubectl exec non-privileged -- sh -c 'ls /dev | wc -l; grep CapEff /proc/1/status'
```

#### Step 2: Dropping a Capability
Apply [capabilities.yaml](./capabilities.yaml): the pod `privileged1` drops the `LINUX_IMMUTABLE` capability.
```sh
kubectl apply -f capabilities.yaml
kubectl exec privileged1 -- grep CapEff /proc/1/status
```
Its CapEff value is lower than non-privileged's: one capability bit is gone.

## Network Policy

#### Step 3: Create a Pod and Check that it Answers
```sh
kubectl run pod01 --image=nginx
kubectl get pod pod01 -o wide
kubectl run test --image=busybox:1.37 --rm -it --restart=Never -- wget -T 3 -qO- <POD01-IP>
```

#### Step 4: Deny All Traffic to and from pod01
Apply [nsp-deny-pod.yaml](./nsp-deny-pod.yaml): it selects the pods labelled `run: pod01` and lists both policy types with no rules, so all ingress and egress is denied.
```sh
kubectl apply -f nsp-deny-pod.yaml
kubectl get networkpolicy
kubectl describe networkpolicy default-deny-pod
```

#### Step 5: Verify
```sh
kubectl run test --image=busybox:1.37 --rm -it --restart=Never -- wget -T 3 -qO- <POD01-IP>
```
This time the request times out. Network policies need a network plugin that enforces them; Calico does.
