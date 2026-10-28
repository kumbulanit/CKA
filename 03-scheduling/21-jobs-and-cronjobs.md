### Jobs and CronJobs

A **Job** runs a pod until it finishes successfully, instead of keeping it running. A **CronJob** creates a Job on a schedule.

#### A Job

```yaml
apiVersion: batch/v1
kind: Job
metadata:
  name: kplabs-job
spec:
  template:
    spec:
      containers:
      - name: kplabs-pods
        image: busybox
        command: ["/bin/sh"]
        args: ["-c", "echo Hello World"]
      restartPolicy: Never
```

This is also the file [`21-jobs-and-cronjobs-jobs.yaml`](./21-jobs-and-cronjobs-jobs.yaml) in this folder: `kubectl apply -f 21-jobs-and-cronjobs-jobs.yaml`

```sh
kubectl get jobs
kubectl get pods
kubectl logs job/kplabs-job
```

The Job shows `COMPLETIONS 1/1`, its pod `Completed`, and the log `Hello World`.

#### A CronJob

```yaml
apiVersion: batch/v1
kind: CronJob
metadata:
  name: kplabs-cronjob
spec:
  schedule: "*/1 * * * *"
  jobTemplate:
    spec:
      template:
        spec:
          containers:
          - name: kplabs-pods
            image: busybox
            args:
            - /bin/sh
            - -c
            - date; echo Hello from the Kubernetes cluster
          restartPolicy: OnFailure
```

This is also the file [`21-jobs-and-cronjobs-cronjob.yaml`](./21-jobs-and-cronjobs-cronjob.yaml) in this folder: `kubectl apply -f 21-jobs-and-cronjobs-cronjob.yaml`

The schedule `*/1 * * * *` means every minute. Wait a minute or two, then:

```sh
kubectl get cronjob kplabs-cronjob
kubectl get jobs
kubectl logs job/$(kubectl get jobs -o name | grep kplabs-cronjob | tail -1 | cut -d/ -f2)
```

Each run is a Job named `kplabs-cronjob-<number>`; by default the last three successful ones are kept.

#### Clean up

```sh
kubectl delete job kplabs-job
kubectl delete cronjob kplabs-cronjob
```
