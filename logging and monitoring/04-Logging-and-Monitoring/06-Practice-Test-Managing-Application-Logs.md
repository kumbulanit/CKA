# Practice Test - Managing Application Logs
  - Take me to [Practice Test](https://kodekloud.com/topic/practice-test-managing-application-logs/)
  
#### Practice setup (your own cluster)

The test deploys `webapp-1`, then `webapp-2` (two containers). Create them first; each log has a user to find:

```
kubectl run webapp-1 --image=busybox:1.37 -- sh -c 'i=0; while true; do i=$((i+1)); echo "$(date) INFO USER$((i % 4 + 1)) logged in"; [ $((i % 5)) -eq 0 ] && echo "$(date) WARNING USER5 Failed to Login as the account is locked due to MANY FAILED ATTEMPTS."; sleep 2; done'
cat <<EOF | kubectl apply -f -
apiVersion: v1
kind: Pod
metadata:
  name: webapp-2
spec:
  containers:
  - name: simple-webapp
    image: busybox:1.37
    command: ["sh", "-c", "i=0; while true; do i=\$((i+1)); echo \"\$(date) INFO USER\$((i % 4 + 1)) is viewing page2\"; [ \$((i % 5)) -eq 0 ] && echo \"\$(date) WARNING USER30 Order failed as the item is OUT OF STOCK.\"; sleep 2; done"]
  - name: db
    image: busybox:1.37
    command: ["sh", "-c", "while true; do echo \"\$(date) INFO db ready\"; sleep 5; done"]
EOF
```

Questions: which user is locked out in webapp-1's log, and which user's order failed in webapp-2's application container?

Solutions to practice test - managing application logs
- We have deployed a POD hosting an application. Inspect it. Wait for it to start.

  <details>
  
  ```
  $ kubectl get pods
  ```
  </details>
  
- Inspect the logs of the POD
  
  <details>
  
  ```
  $ kubectl logs webapp-1
  ```
  </details>
  
- We have deployed a new POD - 'webapp-2' - hosting an application. Inspect it. Wait for it to start.

  <details>
  
  ```
  $ kubectl get pods
  ```
  </details>
  
- Inspect the logs of the webapp in the POD
  
  <details>
  
  ```
  $ kubectl logs webapp-2 -c simple-webapp
  ```
  webapp-2 has two containers, so `kubectl logs` needs `-c` to pick one.
  </details>





