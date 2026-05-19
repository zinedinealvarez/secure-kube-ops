# Observabilidad en Kubernetes

Este documento describe la configuración inicial de observabilidad de SecureKubeOps en Kubernetes.

La observabilidad se plantea como una fase de la solución práctica del TFG, orientada a comprobar el estado del despliegue, los recursos del clúster y el comportamiento básico de la API de referencia desplegada en Kubernetes.

## Enfoque

Para esta fase se utiliza `kube-prometheus-stack` mediante Helm y un archivo `monitoring/values.yaml` versionado en el repositorio.

El objetivo es disponer de una configuración reproducible que pueda instalarse tanto en Minikube como en otros clústeres Kubernetes, manteniendo una configuración mínima y sin añadir componentes fuera del alcance actual.

No se añaden:

- métricas propias de la aplicación;
- endpoint `/metrics`;
- Ingress;
- Argo CD;
- WAF;
- alertas personalizadas.

La documentación operativa se reparte así:

| Documento | Uso |
| --- | --- |
| `docs/observability.md` | Instalación y comprobación de Prometheus, Grafana y Pushgateway. |
| `docs/cluster-portability.md` | Puesta en marcha completa de SecureKubeOps en otro clúster Kubernetes. |
| `docs/pipeline-metrics-integration.md` | Envío y validación de métricas del pipeline mediante Pushgateway. |
| `docs/pipeline-dashboard.md` | Diseño de paneles y consultas PromQL para Grafana. |
| `docs/pipeline-evidence.md` | Estructura de artifacts y origen de `reports/metrics.prom`. |
| `docs/runtime-security-monitoring.md` | Extensión de la observabilidad interna con inventario de workloads y reports de seguridad runtime mediante Trivy Operator. |

## Componentes incluidos

La configuración inicial habilita:

- Prometheus;
- Grafana;
- Prometheus Operator;
- kube-state-metrics;
- node-exporter;
- Pushgateway para recibir métricas del pipeline DevSecOps.

La seguridad runtime se documenta por separado en `docs/runtime-security-monitoring.md`. Esa fase reutiliza la base de Prometheus y Grafana, pero mantiene Trivy Operator en `runtime-security/` para separar observabilidad de seguridad sobre workloads en ejecución.

Prometheus y Grafana usan persistencia mediante PersistentVolumeClaims. Prometheus conserva las series temporales durante `7d` y solicita `5Gi` de almacenamiento. Grafana solicita `1Gi` para conservar su estado local, incluida la configuración creada desde la interfaz.

Alertmanager queda deshabilitado para mantener el alcance simple, ya que no se definen alertas personalizadas.

## Instalación

Añadir el repositorio de Helm:

```bash
helm repo add prometheus-community https://prometheus-community.github.io/helm-charts
helm repo update
```

Comprobar que Minikube y Kubernetes responden:

```bash
minikube status
```

```bash
kubectl get nodes
```

Aplicar el namespace de observabilidad:

```bash
kubectl apply -f monitoring/namespace.yaml
```

Antes de instalar el chart, crear el Secret externo que utilizará Grafana para sus credenciales de administrador:

```powershell
$env:GRAFANA_ADMIN_USER="admin"
$env:GRAFANA_ADMIN_PASSWORD="TU_PASSWORD_LOCAL_NO_VERSIONADO"
kubectl create secret generic monitoring-grafana-admin --namespace monitoring --from-literal=admin-user=$env:GRAFANA_ADMIN_USER --from-literal=admin-password=$env:GRAFANA_ADMIN_PASSWORD
```

Las contraseñas reales quedan fuera de `README.md`, `docs/` y `monitoring/values.yaml`. El Secret se crea localmente en el clúster antes de instalar Helm. El archivo `monitoring/values.yaml` solo referencia el Secret y no contiene credenciales.

Instalar `kube-prometheus-stack` fijando la versión del chart:

```bash
helm upgrade --install monitoring prometheus-community/kube-prometheus-stack --namespace monitoring --version 84.5.0 -f monitoring/values.yaml
```

Este comando también aplica la configuración de persistencia definida en `monitoring/values.yaml`.

Aplicar el dashboard versionado de SecureKubeOps para Grafana:

```bash
kubectl apply -f monitoring/grafana-dashboard-securekubeops-pipeline.yaml
kubectl apply -f monitoring/grafana-dashboard-securekubeops-cluster-overview.yaml
```

Para dashboards grandes, como el dashboard de runtime security de Trivy Operator, se usa server-side apply para evitar que `kubectl` guarde el JSON completo en la anotacion `last-applied-configuration`:

```bash
kubectl apply --server-side -f monitoring/grafana-dashboard-trivy-operator.yaml
```

Los manifiestos crean `ConfigMap` con la etiqueta `grafana_dashboard: "1"`. El sidecar de Grafana los detecta y provisiona los dashboards propios de SecureKubeOps. El identificador de cada dashboard se mantiene estable para que las actualizaciones sustituyan la versión anterior y no creen duplicados.

Los dashboards propios de SecureKubeOps se agrupan en la carpeta `SecureKubeOps` mediante la anotación `grafana_folder: SecureKubeOps` incluida en sus ConfigMaps. El sidecar usa `folderAnnotation` y `foldersFromFilesStructure: true` para respetar esa carpeta. Los dashboards por defecto de `kube-prometheus-stack` reciben la anotación `grafana_folder: Kubernetes` desde `monitoring/values.yaml`, por lo que se agrupan en una carpeta separada.

Instalar Pushgateway fijando la versión del chart:

```bash
helm upgrade --install pushgateway prometheus-community/prometheus-pushgateway --namespace monitoring --version 3.6.0 -f monitoring/pushgateway-values.yaml
```

Aplicar el `ServiceMonitor` de Pushgateway:

```bash
kubectl apply -f monitoring/pushgateway-servicemonitor.yaml
```

Pushgateway se despliega como servicio interno `ClusterIP` y queda monitorizado por Prometheus mediante el manifiesto `monitoring/pushgateway-servicemonitor.yaml`. La configuración completa del envío de métricas del pipeline se documenta en `docs/pipeline-metrics-integration.md`.

El orden de validación es:

1. Comprobar Pods, Services y ServiceMonitor en el namespace `monitoring`.
2. Abrir Pushgateway mediante `kubectl port-forward`.
3. Enviar una métrica de prueba o un archivo `metrics.prom` según `docs/pipeline-metrics-integration.md`.
4. Abrir Prometheus mediante `kubectl port-forward`.
5. Consultar la métrica en Prometheus.
6. Abrir Grafana y comprobar los dashboards propios provisionados desde `monitoring/grafana-dashboard-securekubeops-pipeline.yaml` y `monitoring/grafana-dashboard-securekubeops-cluster-overview.yaml`.

## Comprobación de recursos

Comprobar los Pods del namespace de observabilidad:

```bash
kubectl get pods -n monitoring
```

Comprobar los Services:

```bash
kubectl get svc -n monitoring
```

Comprobar los PersistentVolumeClaims:

```bash
kubectl get pvc -n monitoring
```

Comprobar el ServiceMonitor de Pushgateway:

```bash
kubectl get servicemonitor -n monitoring pushgateway
```

## Acceso a Grafana

Acceder a Grafana mediante `port-forward`:

```bash
kubectl port-forward -n monitoring svc/monitoring-grafana 3000:80
```

Abrir en el navegador:

```text
http://localhost:3000
```

Usuario por defecto:

```text
admin
```

El usuario y la contraseña corresponden a los valores definidos en las variables de entorno utilizadas al crear el Secret `monitoring-grafana-admin`.

## Acceso a Prometheus

Acceder a Prometheus mediante `port-forward`:

```bash
kubectl port-forward -n monitoring svc/monitoring-kube-prometheus-prometheus 9090:9090
```

Abrir en el navegador:

```text
http://localhost:9090
```

## Métricas iniciales a observar

En esta fase no se modifica la aplicación Express ni se añade un endpoint `/metrics`.

Las métricas iniciales se centran en Kubernetes:

- estado del Pod de la API de referencia;
- reinicios del contenedor;
- uso de CPU y memoria;
- estado del Deployment;
- disponibilidad de réplicas;
- métricas del nodo Minikube;
- estado general del clúster;
- métricas del pipeline DevSecOps enviadas manualmente a Pushgateway durante la validación.

## Encaje con SecureKubeOps

La API Express sigue siendo una aplicación de referencia. La observabilidad se incorpora a SecureKubeOps como parte de la solución DevSecOps completa, junto con el pipeline, los controles de seguridad, la imagen Docker publicada en GHCR y el despliegue Kubernetes.

Esta configuración permite validar que el despliegue puede ser observado sin introducir lógica específica de métricas dentro de la aplicación.

## Evidencias para el TFG

Como evidencias técnicas pueden utilizarse:

- `monitoring/values.yaml`;
- `monitoring/pushgateway-values.yaml`;
- `monitoring/pushgateway-servicemonitor.yaml`;
- salida de `kubectl get pods -n monitoring`;
- salida de `kubectl get svc -n monitoring`;
- salida de `kubectl get pvc -n monitoring`;
- salida de `kubectl get servicemonitor -n monitoring pushgateway`;
- acceso a Grafana mediante `port-forward`;
- acceso a Prometheus mediante `port-forward`;
- consulta de métricas `securekubeops_*` en Prometheus tras enviar manualmente un `metrics.prom` a Pushgateway con un `job` estable por workflow;
- visualización del Pod o Deployment de SecureKubeOps desde dashboards de Kubernetes.

No se requieren capturas dentro del repositorio.
