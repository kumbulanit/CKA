# Solution Worker Node Failure

  - Lets have a look at the [Practice Test](https://kodekloud.com/topic/practice-test-worker-node-failure/) of the Worker Node Failure

  - The broken node is `minikube-m02`; you reach it with `minikube ssh -n minikube-m02` and need `sudo` there. On a kubeadm cluster it is `node01` (`ssh node01` as root), the certificates are in `/etc/kubernetes/pki` and the API server port is `6443`.

   ### Solution

   1. <details>
      <summary>Fix the broken cluster</summary>

      * Fix `minikube-m02`

      1. Check the nodes

         ```bash
         kubectl get nodes
         ```

         We see that `minikube-m02` has a status of `NotReady`. This usually means that communication with the node's kubelet has been lost.

      1. Go to the node and investigate

         ```bash
         minikube ssh -n minikube-m02
         ```

      1. Check kubelet status

         ```bash
         systemctl status kubelet
         ```

         We can see from the output that kublet is not running, in fact it has exited. Therefore we should try starting it.

      1. Start kubelet

         ```bash
         sudo systemctl start kubelet
         ```

      1. Now check it is OK.

         ```bash
         systemctl status kubelet
         ```

         Now we can see it is `active (running)`, which is good.

      1. Return to the server

         ```bash
         exit
         ```

      1. Check nodes again

         ```bash
         kubectl get nodes
         ```

         It is good!

      </details>

   2. <details>
      <summary>The cluster is broken again. Investigate and fix the issue.</summary>

      * Fix cluster

      1. Check the nodes

         ```bash
         kubectl get nodes
         ```

         We see that `minikube-m02` has a status of `NotReady`. This usually means that communication with the node's kubelet has been lost.

      1. Go to the node and investigate

         ```bash
         minikube ssh -n minikube-m02
         ```

      1. Check kubelet status

         ```bash
         systemctl status kubelet
         ```

         We can see from the output that it is crashlooping `activating (auto-restart)`, therefore this is likey a configuration issue.

      1. Check kubelet logs

         ```bash
         sudo journalctl -u kubelet
         ```

         There is a lot of information, however the error we are interested in, which is the cause of all other errors is this one

         ```
         "command failed" err="failed to run Kubelet: open /var/lib/minikube/certs/WRONG-CA-FILE.crt: no such file or directory"
         ```

         If kubelet cannot load its certificates, then it cannot autheticate with API server. This is a fatal error, so kubelet exits.

      1.  Check the indicated directory for certificates

            ```bash
            sudo ls -l /var/lib/minikube/certs
            ```

            We see it contains `ca.crt` which we will assume is the correct certificate, therefore we need to find the kubelet configuration file and correct the error there.

      1. Locate kubelet's configuration file

         kubelet is an operating system service, so its service unit file will give us that info

         ```bash
         systemctl cat kubelet
         ```

         Note the `--config` option on the `ExecStart` line

         ```
         ExecStart=/var/lib/minikube/binaries/v1.36.5/kubelet --bootstrap-kubeconfig=/etc/kubernetes/bootstrap-kubelet.conf --config=/var/lib/kubelet/config.yaml ...
         ```

         There is the config YAML file (on a kubeadm node the same option is in an `Environment="KUBELET_CONFIG_ARGS=..."` line)

      1. Fix configuration

         ```bash
         sudo vi /var/lib/kubelet/config.yaml
         ```

         ```yaml
         apiVersion: kubelet.config.k8s.io/v1beta1
         authentication:
           anonymous:
             enabled: false
           webhook:
             cacheTTL: 0s
             enabled: true
           x509:
             clientCAFile: /var/lib/minikube/certs/WRONG-CA-FILE.crt # <- Fix this
         authorization:
           mode: Webhook
         ```

         Note that you can perform the same edit with a single `sed` command. This is quicker than editing in vi.

         ```bash
         sudo sed -i 's/WRONG-CA-FILE.crt/ca.crt/g' /var/lib/kubelet/config.yaml
         ```

      1. Check status

         Wait a few seconds, kubelet will be auto-restarted.

         ```bash
         systemctl status kubelet
         ```

         Now we can see it is `active (running)`, which is good. If it is not, then you made a mistake when editing the config file, probably broke the YAML syntax or did not edit the certificate filename correctly. Return to step `vii.` above and fix it.

      1. Return to the server

         ```bash
         exit
         ```

      1. Check nodes again

         ```bash
         kubectl get nodes
         ```

         It is good!
      </details>

   3. <details>
      <summary>The cluster is broken again. Investigate and fix the issue.</summary>

      * Fix cluster

      1. Check the nodes

         ```bash
         kubectl get nodes
         ```

         We see that `minikube-m02` has a status of `NotReady`. This usually means that communication with the node's kubelet has been lost.

      1. Go to the node and investigate

         ```bash
         minikube ssh -n minikube-m02
         ```

      1. Check kubelet status

         ```bash
         systemctl status kubelet
         ```

         We can see it is `active (running)`, however the API server still thinks there is an issue. So we must again go to the kubelet logs.

      1. Check kubelet logs

         ```bash
         sudo journalctl -u kubelet
         ```

         There is a lot of information, however the error we are interested in, which is the cause of all other errors is this one

         ```
          "Unable to register node with API server" err="Post \"https://control-plane.minikube.internal:8553/api/v1/nodes\": dial tcp 192.168.49.2:8553: connect: connection refused" node="minikube-m02"
          ```

         What do you know about the usual port for API server? On minikube it is `8443` (`6443` on a kubeadm cluster), not `8553`! kubelet uses a kubeconfig file to connect to API server just like kubectl does, so we need to locate and fix that.

      1. Locate kubelet's kubeconfig file

         kubelet is an operating system service, so its service unit file will give us that info

         ```bash
         systemctl cat kubelet
         ```

         Note the two kubeconfig options on the `ExecStart` line

         ```
         ExecStart=/var/lib/minikube/binaries/v1.36.5/kubelet --bootstrap-kubeconfig=/etc/kubernetes/bootstrap-kubelet.conf ... --kubeconfig=/etc/kubernetes/kubelet.conf ...
         ```

         There are two kubeconfigs. The first one is used when a node is created and is joining the cluster. The second one is used for normal operation. It is therefore the second one we are interested in.

      1. Fix the kubeconfig

         Port should be `8443`

         ```bash
         sudo vi /etc/kubernetes/kubelet.conf
         ```

         ```yaml
         apiVersion: v1
         clusters:
         - cluster:
             certificate-authority-data: REDACTED
             server: https://control-plane.minikube.internal:8553  # <- Fix this
           name: default-cluster
         contexts:
         - context:
             cluster: default-cluster
             namespace: default
             user: default-auth
           name: default-context
         current-context: default-context
         kind: Config
         users:
         - name: default-auth
           user:
             client-certificate: /var/lib/kubelet/pki/kubelet-client-current.pem
             client-key: /var/lib/kubelet/pki/kubelet-client-current.pem
         ```

         Note that you can perform the same edit with a single `sed` command. This is quicker than editing in vi.

         ```bash
         sudo sed -i 's/8553/8443/g' /etc/kubernetes/kubelet.conf
         ```

      1. Restart kubelet

         Since kubelet is already running (not crashlooping), we need to restart it so it gets the updated kubeconfig

         ```bash
         sudo systemctl restart kubelet
         ```

      1. Check status

         ```bash
         systemctl status kubelet
         ```

         Now we can see it is `active (running)`, which is good. If it is not, then you made a mistake when editing the kubeconfig, probably broke the YAML syntax. Return to step `vi.` above and fix it.

      1. Return to the server

         ```bash
         exit
         ```

      1. Check nodes again

         ```bash
         kubectl get nodes
         ```

         It is good! If it is not, then you probably made a mistake setting the port number. Return to `minikube-m02` and redo from step `vi.` above.

      </details>