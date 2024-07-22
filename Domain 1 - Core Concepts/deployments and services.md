### Different Ways to Deploy Deployments and Services in Kubernetes

Deploying applications and services in Kubernetes can be done through various methods, each catering to different needs and levels of complexity. The following sections cover the different ways to deploy Deployments and Services in Kubernetes:

1. **kubectl CLI**
2. **Kustomize**
3. **Helm**
4. **GitOps**
5. **CI/CD Pipelines**

#### 1. kubectl CLI

**kubectl** is the command-line tool for interacting with the Kubernetes API. It allows you to create, update, delete, and get details about resources.

**Example**: Deploying a web application using `kubectl`.

**Deployment YAML**:
```yaml
apiVersion: apps/v1
kind: Deployment
metadata:
  name: webapp-deployment
spec:
  replicas: 3
  selector:
    matchLabels:
      app: webapp
  template:
    metadata:
      labels:
        app: webapp
    spec:
      containers:
      - name: webapp
        image: webapp:1.0
        ports:
        - containerPort: 80
```

**Service YAML**:
```yaml
apiVersion: v1
kind: Service
metadata:
  name: webapp-service
spec:
  selector:
    app: webapp
  ports:
  - protocol: TCP
    port: 80
    targetPort: 80
  type: ClusterIP
```

**Commands**:
```sh
kubectl apply -f webapp-deployment.yaml
kubectl apply -f webapp-service.yaml
```

**Diagram**:
![kubectl CLI Diagram](https://d33wubrfki0l68.cloudfront.net/2cc15183e76b3d28fbc439d27d4e180b67aa0ba1/76c29/images/docs/kubectl_overview.svg)

### 2. Kustomize

**Kustomize** allows customization of Kubernetes YAML configurations without templates. It is integrated into `kubectl` as `kubectl kustomize`.

**Example**: Deploying a web application using Kustomize.

**Base Deployment YAML**:
```yaml
apiVersion: apps/v1
kind: Deployment
metadata:
  name: webapp-deployment
spec:
  replicas: 3
  selector:
    matchLabels:
      app: webapp
  template:
    metadata:
      labels:
        app: webapp
    spec:
      containers:
      - name: webapp
        image: webapp:1.0
        ports:
        - containerPort: 80
```

**Base Service YAML**:
```yaml
apiVersion: v1
kind: Service
metadata:
  name: webapp-service
spec:
  selector:
    app: webapp
  ports:
  - protocol: TCP
    port: 80
    targetPort: 80
  type: ClusterIP
```

**Kustomization YAML**:
```yaml
resources:
- webapp-deployment.yaml
- webapp-service.yaml
```

**Commands**:
```sh
kubectl apply -k .
```

**Diagram**:
![Kustomize Diagram](https://kustomize.io/images/kustomize-flow.png)

### 3. Helm

**Helm** is a package manager for Kubernetes that allows you to define, install, and upgrade complex Kubernetes applications.

**Example**: Deploying a web application using Helm.

**Chart Directory Structure**:
```
webapp-chart/
  Chart.yaml
  values.yaml
  templates/
    deployment.yaml
    service.yaml
```

**Chart.yaml**:
```yaml
apiVersion: v2
name: webapp-chart
description: A Helm chart for Kubernetes
version: 0.1.0
```

**values.yaml**:
```yaml
replicaCount: 3
image:
  repository: webapp
  tag: 1.0
service:
  type: ClusterIP
  port: 80
```

**templates/deployment.yaml**:
```yaml
apiVersion: apps/v1
kind: Deployment
metadata:
  name: {{ .Release.Name }}-webapp
spec:
  replicas: {{ .Values.replicaCount }}
  selector:
    matchLabels:
      app: {{ .Release.Name }}-webapp
  template:
    metadata:
      labels:
        app: {{ .Release.Name }}-webapp
    spec:
      containers:
      - name: webapp
        image: "{{ .Values.image.repository }}:{{ .Values.image.tag }}"
        ports:
        - containerPort: 80
```

**templates/service.yaml**:
```yaml
apiVersion: v1
kind: Service
metadata:
  name: {{ .Release.Name }}-webapp
spec:
  selector:
    app: {{ .Release.Name }}-webapp
  ports:
  - protocol: TCP
    port: {{ .Values.service.port }}
    targetPort: 80
  type: {{ .Values.service.type }}
```

**Commands**:
```sh
helm install webapp-release webapp-chart/
```

**Diagram**:
![Helm Diagram](https://helm.sh/img/helm-logo.svg)

### 4. GitOps

**GitOps** is a practice of using Git as the single source of truth for declarative infrastructure and applications. Tools like ArgoCD and FluxCD are commonly used for GitOps.

**Example**: Deploying a web application using ArgoCD.

**Repository Structure**:
```
webapp-repo/
  base/
    deployment.yaml
    service.yaml
  overlays/
    production/
      kustomization.yaml
    staging/
      kustomization.yaml
```

**base/deployment.yaml**:
```yaml
apiVersion: apps/v1
kind: Deployment
metadata:
  name: webapp
spec:
  replicas: 3
  selector:
    matchLabels:
      app: webapp
  template:
    metadata:
      labels:
        app: webapp
    spec:
      containers:
      - name: webapp
        image: webapp:1.0
        ports:
        - containerPort: 80
```

**base/service.yaml**:
```yaml
apiVersion: v1
kind: Service
metadata:
  name: webapp
spec:
  selector:
    app: webapp
  ports:
  - protocol: TCP
    port: 80
    targetPort: 80
  type: ClusterIP
```

**overlays/production/kustomization.yaml**:
```yaml
resources:
- ../../base
```

**ArgoCD Application**:
```yaml
apiVersion: argoproj.io/v1alpha1
kind: Application
metadata:
  name: webapp
spec:
  project: default
  source:
    repoURL: 'https://github.com/example/webapp-repo'
    targetRevision: HEAD
    path: overlays/production
  destination:
    server: 'https://kubernetes.default.svc'
    namespace: default
  syncPolicy:
    automated:
      prune: true
      selfHeal: true
```

**Commands**:
```sh
kubectl apply -f argocd-application.yaml
```

**Diagram**:
![GitOps Diagram](https://argo-cd.readthedocs.io/en/stable/assets/argo_logo.svg)

### 5. CI/CD Pipelines

**CI/CD Pipelines** automate the deployment process, integrating code changes, running tests, and deploying applications. Popular tools include Jenkins, GitLab CI, and GitHub Actions.

**Example**: Deploying a web application using GitLab CI.

**.gitlab-ci.yml**:
```yaml
stages:
  - build
  - deploy

build:
  stage: build
  script:
    - docker build -t $CI_REGISTRY_IMAGE:$CI_COMMIT_SHA .
    - docker push $CI_REGISTRY_IMAGE:$CI_COMMIT_SHA

deploy:
  stage: deploy
  script:
    - kubectl apply -f k8s/deployment.yaml
    - kubectl apply -f k8s/service.yaml
```

**k8s/deployment.yaml**:
```yaml
apiVersion: apps/v1
kind: Deployment
metadata:
  name: webapp
spec:
  replicas: 3
  selector:
    matchLabels:
      app: webapp
  template:
    metadata:
      labels:
        app: webapp
    spec:
      containers:
      - name: webapp
        image: $CI_REGISTRY_IMAGE:$CI_COMMIT_SHA
        ports:
        - containerPort: 80
```

**k8s/service.yaml**:
```yaml
apiVersion: v1
kind: Service
metadata:
  name: webapp
spec:
  selector:
    app: webapp
  ports:
  - protocol: TCP
    port: 80
    targetPort: 80
  type: ClusterIP
```

**Diagram**:
![CI/CD Diagram](https://about.gitlab.com/images/press/logo/png/gitlab-logo-gray-stacked-rgb.png)

### Conclusion

Different methods for deploying applications and services in Kubernetes provide flexibility to cater to various needs and complexities. Whether using `kubectl`, Kustomize, Helm, GitOps, or CI/CD pipelines, each approach has its advantages and can be chosen based on the specific requirements of the application and the operational environment.

### Additional Resources

- **Kubernetes Official Documentation**: [https://kubernetes.io/docs/](https://kubernetes.io/docs/)
- **Helm Documentation**: [https://helm.sh/docs/](https://helm.sh/docs/)
- **ArgoCD

 Documentation**: [https://argo-cd.readthedocs.io/](https://argo-cd.readthedocs.io/)
- **GitLab CI Documentation**: [https://docs.gitlab.com/ee/ci/](https://docs.gitlab.com/ee/ci/)

---
