### Artifact Hub Page:

https://artifacthub.io/


## Deploying Jenkins Helm Chart

https://artifacthub.io/packages/helm/jenkinsci/jenkins

##### Step 1. Configure and Install Jenkins Helm Chart

```sh
helm repo add jenkins https://charts.jenkins.io
helm repo update
helm install my-jenkins jenkins/jenkins
```
##### Step 2. Verify the List of Releases

```sh
helm list
```
##### Step 3. Uninstall Jenkins Helm Chart

```sh
helm uninstall my-jenkins
```

## Deploying Grafana Helm Chart

https://artifacthub.io/packages/helm/grafana/grafana

(This used to be the Bitnami WordPress chart. Bitnami stopped publishing free versioned images in 2025, so that chart no longer installs without a subscription.)

##### Step 1. Configure and Install Grafana Helm Chart

```sh
helm repo add grafana https://grafana.github.io/helm-charts
helm repo update
helm install my-release grafana/grafana
```

##### Step 2. Check the Release and its Values

```sh
helm list
helm status my-release
helm get values my-release --all | head -30
```

##### Step 3. Uninstall Grafana Helm Chart

```sh
helm uninstall my-release
```
