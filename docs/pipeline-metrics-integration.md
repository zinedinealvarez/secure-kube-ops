# Integración de métricas del pipeline

Este documento describe cómo SecureKubeOps integra las métricas del pipeline DevSecOps con la capa de observabilidad en Kubernetes.

El flujo de integración queda definido así:

```text
GitHub Actions artifacts -> Pushgateway -> Prometheus -> Grafana
```

Los workflows generan `reports/metrics.prom` como evidencia en formato Prometheus text format. Pushgateway actúa como punto de recepción para métricas generadas por procesos efímeros. Las métricas se conservan como artifacts y la validación del envío a Pushgateway se realiza de forma local mediante `kubectl port-forward`.

## Cómo funciona

Prometheus normalmente obtiene métricas mediante un modelo pull: scrapea endpoints HTTP que exponen métricas. Un workflow de GitHub Actions es efímero y termina después de ejecutarse, por lo que Prometheus no puede scrapeárselo como si fuera un servicio estable dentro del clúster.

Pushgateway resuelve este caso actuando como intermediario:

1. El workflow genera `reports/metrics.prom` dentro del artifact.
2. El archivo `metrics.prom` se envía a Pushgateway mediante HTTP durante la validación local.
3. Pushgateway conserva las series recibidas.
4. Prometheus scrapea Pushgateway mediante el `ServiceMonitor`.
5. Grafana consulta Prometheus usando PromQL.

El detalle técnico completo de cada ejecución sigue estando en los artifacts. Pushgateway recibe métricas orientadas a Grafana: estado de workflows, resultado de controles y hallazgos de seguridad enriquecidos sin exponer secretos.

## Enfoque de seguridad

Pushgateway se despliega como servicio interno de Kubernetes:

- servicio `ClusterIP`;
- sin Ingress;
- sin `LoadBalancer`;
- sin credenciales reales versionadas;
- sin exposición pública desde el repositorio;
- con un manifiesto `ServiceMonitor` versionado para que Prometheus lo descubra dentro del namespace `monitoring`.

GitHub Actions no envía métricas automáticamente a Pushgateway porque Pushgateway se mantiene como servicio interno del clúster. En Minikube, la validación local se realiza mediante `kubectl port-forward`.

La imagen utilizada por el chart se trata como un componente de terceros sujeto a revisión de vulnerabilidades. La configuración evita exposición pública directa y limita el uso de Pushgateway a la recepción de métricas del pipeline.

En esta configuración, `monitoring/pushgateway-values.yaml` usa:

| Clave | Valor | Motivo |
| --- | --- | --- |
| `service.type` | `ClusterIP` | Mantiene Pushgateway como servicio interno del clúster. |
| `serviceMonitor.enabled` | `false` | Evita que el chart cree el `ServiceMonitor`; el scraping se define en un manifiesto versionado aparte. |
| `persistentVolume.enabled` | `false` | Mantiene la validación local simple y evita almacenamiento persistente innecesario en Minikube. |

El manifiesto `monitoring/pushgateway-servicemonitor.yaml` define:

| Campo | Valor | Motivo |
| --- | --- | --- |
| `metadata.labels.release` | `monitoring` | Alinea el `ServiceMonitor` con la selección usada por la release `monitoring` de `kube-prometheus-stack`. |
| `spec.selector.matchLabels` | labels del Service de Pushgateway | Permite que Prometheus encuentre el Service creado por el chart. |
| `spec.endpoints.port` | `http` | Usa el puerto expuesto por el Service de Pushgateway. |
| `spec.endpoints.path` | `/metrics` | Scrapea el endpoint de métricas de Pushgateway. |
| `spec.endpoints.honorLabels` | `true` | Conserva labels enviados por las métricas del pipeline. |

Pushgateway no incorpora autenticación pública en esta configuración porque no se expone mediante Ingress ni `LoadBalancer`. En un clúster compartido o accesible desde GitHub Actions mediante red externa, el endpoint se protege con autenticación, TLS, reglas de red o un mecanismo equivalente antes de automatizar el envío desde el pipeline.

## Configuración entregable

La configuración versionada se encuentra en:

```text
monitoring/pushgateway-values.yaml
```

El chart utilizado es:

```text
prometheus-community/prometheus-pushgateway
```

La versión fijada para el TFG es:

```text
3.6.0
```

## Instalación en Kubernetes

Añadir el repositorio de Helm:

```bash
helm repo add prometheus-community https://prometheus-community.github.io/helm-charts
helm repo update
```

Instalar primero `kube-prometheus-stack`, tal como se describe en `docs/observability.md`.

Instalar Pushgateway en el namespace `monitoring`:

```bash
helm upgrade --install pushgateway prometheus-community/prometheus-pushgateway --namespace monitoring --version 3.6.0 -f monitoring/pushgateway-values.yaml
```

Aplicar el `ServiceMonitor`:

```bash
kubectl apply -f monitoring/pushgateway-servicemonitor.yaml
```

Comprobar el Pod:

```bash
kubectl get pods -n monitoring -l app.kubernetes.io/name=prometheus-pushgateway
```

Comprobar el Service:

```bash
kubectl get svc -n monitoring pushgateway
```

Comprobar el ServiceMonitor:

```bash
kubectl get servicemonitor -n monitoring pushgateway
```

## Validación local con Minikube

Abrir un `port-forward` local hacia Pushgateway:

```bash
kubectl port-forward -n monitoring svc/pushgateway 9091:9091
```

Enviar una métrica de prueba desde otra terminal:

```powershell
$body = "securekubeops_pipeline_test_metric 1`n"; Invoke-WebRequest -UseBasicParsing -Uri http://localhost:9091/metrics/job/securekubeops-test -Method Post -Body $body -ContentType "text/plain"
```

Comprobar que Pushgateway expone la métrica:

```powershell
(Invoke-WebRequest -UseBasicParsing -Uri http://localhost:9091/metrics).Content | Select-String "securekubeops_pipeline_test_metric"
```

Eliminar la métrica de prueba:

```powershell
Invoke-WebRequest -UseBasicParsing -Uri http://localhost:9091/metrics/job/securekubeops-test -Method Delete
```

Comprobar la métrica desde Prometheus:

```bash
kubectl port-forward -n monitoring svc/monitoring-kube-prometheus-prometheus 9090:9090
```

Abrir en el navegador:

```text
http://localhost:9090
```

Ejecutar esta consulta:

```promql
securekubeops_pipeline_test_metric
```

La métrica aparece cuando Prometheus ha scrapeado Pushgateway. Si no aparece inmediatamente, se espera al siguiente intervalo de scrape y se vuelve a ejecutar la consulta.

## Envío de métricas del pipeline

Cada workflow genera `reports/metrics.prom` dentro de su artifact. El envío a Pushgateway es manual durante la validación.

El archivo que se envía es siempre `metrics.prom`. La URL de Pushgateway incluye un `job` estable para identificar el origen lógico de las métricas. Ese nombre no es una carpeta ni el nombre del repositorio; Pushgateway lo convierte en el label `job`.

| Workflow | Artifact | Job recomendado en Pushgateway |
| --- | --- | --- |
| `Pre Analysis` | `securekubeops-pre-analysis-security-results-*` | `securekubeops-pre-analysis` |
| `Image Validation` | `securekubeops-image-validation-security-results-*` | `securekubeops-image-validation` |
| `Branch Policy` | `securekubeops-branch-policy-results-*` | `securekubeops-branch-policy` |
| `Publish Image` | `securekubeops-ghcr-publish-results-*` | `securekubeops-publish-image` |

El nombre del `job` se mantiene estable y descriptivo. No se usan como parte del `job` valores variables como commit, `run_id`, fecha o nombre exacto del ZIP.

Procedimiento:

1. Descargar desde GitHub Actions el artifact del workflow que se quiere validar.
2. Extraer el ZIP descargado.
3. Localizar el archivo `metrics.prom`.
4. Abrir un `port-forward` local hacia Pushgateway.
5. Enviar `metrics.prom` a Pushgateway.
6. Comprobar la métrica en Pushgateway.
7. Comprobar la métrica en Prometheus.

Ejemplo de estructura tras extraer un artifact:

```text
artifact-extraido/
  metadata.json
  metrics.prom
  <workflow-report>.html
  tools/
```

El archivo que se envía a Pushgateway es `metrics.prom`, no el ZIP completo. Si el archivo ya está fuera del ZIP en `C:\Users\Usuario\Downloads`, se usa directamente esa ruta.

Definir la ruta del `.prom`:

```powershell
$prom = "C:\Users\Usuario\Downloads\metrics.prom"
```

Comprobar que el archivo existe:

```powershell
Test-Path $prom
```

Ver el contenido antes de enviarlo:

```powershell
Get-Content $prom
```

Abrir Pushgateway localmente en una terminal y dejarla abierta:

```powershell
kubectl port-forward -n monitoring svc/pushgateway 9091:9091
```

La terminal del `port-forward` permanece abierta porque `kubectl port-forward` mantiene activa la conexión local con el Service de Kubernetes. El envío de métricas se ejecuta desde otra terminal.

Enviar un `metrics.prom` de `Pre Analysis`:

```powershell
Invoke-WebRequest -UseBasicParsing -Uri "http://localhost:9091/metrics/job/securekubeops-pre-analysis" -Method Post -InFile $prom -ContentType "text/plain"
```

Enviar un `metrics.prom` de `Image Validation`:

```powershell
Invoke-WebRequest -UseBasicParsing -Uri "http://localhost:9091/metrics/job/securekubeops-image-validation" -Method Post -InFile $prom -ContentType "text/plain"
```

Enviar un `metrics.prom` de `Branch Policy`:

```powershell
Invoke-WebRequest -UseBasicParsing -Uri "http://localhost:9091/metrics/job/securekubeops-branch-policy" -Method Post -InFile $prom -ContentType "text/plain"
```

Enviar un `metrics.prom` de `Publish Image`:

```powershell
Invoke-WebRequest -UseBasicParsing -Uri "http://localhost:9091/metrics/job/securekubeops-publish-image" -Method Post -InFile $prom -ContentType "text/plain"
```

Este envío se hace durante la validación local, con Pushgateway expuesto únicamente mediante `kubectl port-forward`. El `job` elegido identifica el workflow al que pertenece el archivo enviado.

Comprobar que Pushgateway contiene métricas de SecureKubeOps:

```powershell
(Invoke-WebRequest -UseBasicParsing -Uri http://localhost:9091/metrics).Content | Select-String "securekubeops_"
```

Eliminar las métricas enviadas para un workflow concreto:

```powershell
Invoke-WebRequest -UseBasicParsing -Uri "http://localhost:9091/metrics/job/securekubeops-pre-analysis" -Method Delete
```

```powershell
Invoke-WebRequest -UseBasicParsing -Uri "http://localhost:9091/metrics/job/securekubeops-image-validation" -Method Delete
```

```powershell
Invoke-WebRequest -UseBasicParsing -Uri "http://localhost:9091/metrics/job/securekubeops-branch-policy" -Method Delete
```

```powershell
Invoke-WebRequest -UseBasicParsing -Uri "http://localhost:9091/metrics/job/securekubeops-publish-image" -Method Delete
```

## Consulta desde Prometheus

Acceder a Prometheus:

```bash
kubectl port-forward -n monitoring svc/monitoring-kube-prometheus-prometheus 9090:9090
```

Abrir:

```text
http://localhost:9090
```

Consultar una métrica del pipeline:

```promql
securekubeops_pipeline_execution_total
```

Consultar las métricas enviadas desde un workflow concreto:

```promql
securekubeops_pipeline_execution_total{job="securekubeops-pre-analysis"}
```

Consultar hallazgos de seguridad enviados desde los artifacts:

```promql
securekubeops_security_finding_info
```

Prometheus no recibe directamente el archivo `.prom`. El archivo se envía a Pushgateway y Prometheus lo obtiene al scrapear el Service de Pushgateway mediante `monitoring/pushgateway-servicemonitor.yaml`.

## Visualización en Grafana

Acceder a Grafana:

```bash
kubectl port-forward -n monitoring svc/monitoring-grafana 3000:80
```

Abrir:

```text
http://localhost:3000
```

Los paneles definidos en `docs/pipeline-dashboard.md` utilizan las métricas recibidas por Pushgateway y almacenadas por Prometheus.

El dashboard de Grafana se crea siguiendo las consultas y paneles definidos en `docs/pipeline-dashboard.md`. La comprobación consiste en confirmar que las consultas PromQL devuelven datos en Prometheus y después usar esas mismas consultas en los paneles de Grafana.

## Orden completo de comprobación

El orden operativo para validar la integración es:

1. Instalar o actualizar `kube-prometheus-stack` con `docs/observability.md`.
2. Instalar o actualizar Pushgateway con `monitoring/pushgateway-values.yaml`.
3. Aplicar `monitoring/pushgateway-servicemonitor.yaml`.
4. Abrir `kubectl port-forward -n monitoring svc/pushgateway 9091:9091`.
5. Enviar una métrica de prueba o un archivo `metrics.prom`.
6. Comprobar la métrica en `http://localhost:9091/metrics`.
7. Abrir `kubectl port-forward -n monitoring svc/monitoring-kube-prometheus-prometheus 9090:9090`.
8. Consultar la métrica en Prometheus.
9. Abrir Grafana con `kubectl port-forward -n monitoring svc/monitoring-grafana 3000:80`.
10. Usar `docs/pipeline-dashboard.md` como guía para crear paneles.

## Límites de la integración

Pushgateway almacena el último valor recibido para cada combinación de job y labels hasta que se elimina o sobrescribe.

No se envían:

- commits como labels;
- `run_id` como label;
- paquetes;
- rutas de ficheros;
- secretos;
- mensajes de error.

Sí se envían como labels de hallazgos de seguridad:

- `id`, como CVE, ID de Trivy config o `check_id` de Semgrep;
- `severity`;
- `title`;
- `description`;
- `time`, como fecha declarada de generación de la métrica.

En GitLeaks solo se envía el número de secretos detectados. No se envía el valor del secreto ni su ubicación.

Cuando varios findings de Semgrep o Trivy comparten los mismos labels, el valor de la muestra representa el número de ocurrencias para evitar métricas duplicadas con el mismo nombre y la misma combinación de labels.

El detalle técnico completo permanece en los artifacts de GitHub Actions.

## Referencias técnicas

- `docs/observability.md` describe la instalación de Prometheus, Grafana y Pushgateway.
- `docs/cluster-portability.md` describe cómo reproducir esta configuración en otro clúster Kubernetes.
- `docs/pipeline-evidence.md` describe cómo los workflows generan `reports/metrics.prom`.
- `docs/pipeline-dashboard.md` define las consultas PromQL y los paneles de Grafana.
- `monitoring/pushgateway-values.yaml` contiene la configuración Helm usada para desplegar Pushgateway.
- `monitoring/pushgateway-servicemonitor.yaml` contiene el `ServiceMonitor` que conecta Pushgateway con Prometheus.
- Prometheus Pushgateway documenta el envío mediante HTTP usando rutas con `/metrics/job/<JOB_NAME>`.
- Prometheus documenta PromQL como lenguaje para seleccionar y agregar series temporales.
- Prometheus documenta Grafana como herramienta recomendada para crear gráficas y dashboards sobre métricas Prometheus.
