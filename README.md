# argocd-plugin-helm-valuesfrom

Allows `valuesFrom` secrets or configmaps to be passed to a helm-based ArgoCD `Application`

## Example

```
apiVersion: argoproj.io/v1alpha1
kind: Application
metadata:
  name: redis
spec:
  project: default
  destination:
    server: "https://kubernetes.default.svc"
    namespace: redis
  source:
    chart: redis
    repoURL: https://charts.bitnami.com/bitnami
    targetRevision: 17.8.5
    plugin:
      name: helm-valuesfrom
      parameters:
        - name: valuesFrom
          array:
            # Evaluated in order. valuesKey defaults to `values.yaml` if not specified
            - '{"kind":"secret","name":"redis-values","valuesKey":"values.yaml"}'
            - '{"kind":"configmap","name":"redis-values"}'
```

## Test Plugin
```
minikube start
kubectl create ns argocd
kubectl apply -n argocd -k argocd/helm-valuesfrom
kubectl apply -n argocd -k clusters/mycluster/redis
kubectl -n argocd get application redis
kubectl -n redis get pod
```
