# Manifiestos Kubernetes

Esta carpeta agrupa los manifiestos Kubernetes usados por SecureKubeOps.

| Carpeta | Contenido |
| --- | --- |
| `application/` | Namespace, Deployment y Service de la API de referencia `secure-kube-ops`. |
| `labs/juice-shop/` | Laboratorio vulnerable OWASP Juice Shop, separado de la aplicación de referencia. |
| `monitoring/` | Valores Helm, ServiceMonitor y dashboards de Prometheus, Grafana y Pushgateway. |
| `runtime-security/` | Namespace y valores Helm de Trivy Operator para seguridad en tiempo de ejecución. |
| `arc/` | Notas operativas de Actions Runner Controller y runners efímeros en AKS. |

La capa de entrada WAF no se define aquí porque necesita recursos específicos de Azure y plantillas con identificadores reales. Esa parte se mantiene en `../azure-waf/`.

## Aplicación de referencia

```powershell
kubectl apply -f k8s/application/namespace.yaml
kubectl apply -f k8s/application/deployment.yaml
kubectl apply -f k8s/application/service.yaml
```

## Laboratorio vulnerable

```powershell
kubectl apply -k k8s/labs/juice-shop
```

## Observabilidad

```powershell
kubectl apply -f k8s/monitoring/namespace.yaml
helm upgrade --install monitoring prometheus-community/kube-prometheus-stack --namespace monitoring --version 84.5.0 -f k8s/monitoring/values.yaml
helm upgrade --install pushgateway prometheus-community/prometheus-pushgateway --namespace monitoring --version 3.6.0 -f k8s/monitoring/pushgateway-values.yaml
kubectl apply -f k8s/monitoring/pushgateway-servicemonitor.yaml
```

## Seguridad runtime

```powershell
kubectl apply -f k8s/runtime-security/trivy-operator/namespace.yaml
helm upgrade --install trivy-operator aqua/trivy-operator --namespace runtime-security --version 0.32.1 -f k8s/runtime-security/trivy-operator/values.yaml
```
