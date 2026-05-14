# Puesta en marcha en otro clúster Kubernetes

Este documento recoge el orden completo para desplegar SecureKubeOps en un clúster Kubernetes distinto a Minikube. Incluye la API de referencia, los Secrets necesarios, la observabilidad con Prometheus y Grafana, Pushgateway y la validación manual de métricas del pipeline.

El flujo operativo queda definido así:

```text
GHCR -> Kubernetes -> Prometheus/Grafana -> Pushgateway -> métricas del pipeline
```

La configuración es reutilizable porque se apoya en manifiestos Kubernetes, Helm y servicios internos del clúster. Los ajustes específicos dependen del clúster de destino, especialmente permisos, almacenamiento, políticas de red, acceso a imágenes privadas y recursos disponibles.

## Requisitos

Antes de ejecutar los comandos, `kubectl` apunta al clúster de destino.

Herramientas necesarias:

| Herramienta | Uso |
| --- | --- |
| `kubectl` | Aplicar manifiestos, crear Secrets, comprobar recursos y abrir `port-forward`. |
| `helm` | Instalar `kube-prometheus-stack` y Pushgateway. |
| PowerShell | Definir variables locales y enviar métricas con `Invoke-WebRequest`. |

Permisos necesarios:

| Permiso | Motivo |
| --- | --- |
| Crear Secrets | Crear `ghcr-pull-secret` y `monitoring-grafana-admin` sin guardar credenciales en Git. |
| Crear recursos Kubernetes | Aplicar `Deployment`, `Service`, namespace y `ServiceMonitor`. |
| Instalar charts Helm | Instalar Prometheus, Grafana y Pushgateway. |
| Usar `kubectl port-forward` | Validar servicios internos sin exponerlos públicamente. |

## Variables locales

Estas variables se definen en la terminal local y no se guardan en el repositorio.

Usuario de GHCR:

```powershell
$env:GHCR_USERNAME="zinedinealvarez"
```

Token de GitHub con permiso de lectura de paquetes:

```powershell
$env:GHCR_TOKEN="TU_TOKEN_DE_GITHUB_CON_READ_PACKAGES"
```

Usuario administrador de Grafana:

```powershell
$env:GRAFANA_ADMIN_USER="admin"
```

Contraseña local de Grafana:

```powershell
$env:GRAFANA_ADMIN_PASSWORD="TU_PASSWORD_LOCAL_NO_VERSIONADO"
```

Ruta al archivo `metrics.prom` extraído de un artifact:

```powershell
$env:METRICS_PROM_PATH="C:\Users\Usuario\Downloads\artifact-extraido\metrics.prom"
```

## Comprobación del clúster

Comprobar el contexto activo:

```powershell
kubectl config current-context
```

Comprobar nodos:

```powershell
kubectl get nodes
```

Comprobar que Helm funciona:

```powershell
helm version
```

## Despliegue de la API de referencia

La API de referencia usa la imagen publicada por el pipeline en GitHub Container Registry:

```text
ghcr.io/zinedinealvarez/secure-kube-ops:<commit-sha>
```

El valor `<commit-sha>` se sustituye por el tag publicado por el workflow **Publish Image**.

Como GHCR se utiliza como registry privado, el clúster necesita un `imagePullSecret` para descargar la imagen.

Crear o actualizar el `imagePullSecret`:

```powershell
kubectl create secret docker-registry ghcr-pull-secret --docker-server=ghcr.io --docker-username=$env:GHCR_USERNAME --docker-password=$env:GHCR_TOKEN --dry-run=client -o yaml | kubectl apply -f -
```

Aplicar el `Deployment`:

```powershell
kubectl apply -f k8s/deployment.yaml
```

Aplicar el `Service`:

```powershell
kubectl apply -f k8s/service.yaml
```

Comprobar Pods:

```powershell
kubectl get pods
```

Comprobar Services:

```powershell
kubectl get svc
```

Revisar el Pod si la imagen no arranca:

```powershell
kubectl describe pod -l app=secure-kube-ops
```

Abrir la API mediante `port-forward`:

```powershell
kubectl port-forward service/secure-kube-ops 3000:3000
```

Comprobar `/health` desde otra terminal:

```powershell
Invoke-WebRequest -UseBasicParsing -Uri http://localhost:3000/health
```

## Instalación de observabilidad

Añadir el repositorio Helm de Prometheus Community:

```powershell
helm repo add prometheus-community https://prometheus-community.github.io/helm-charts
```

Actualizar índices de charts:

```powershell
helm repo update
```

Aplicar el namespace de observabilidad:

```powershell
kubectl apply -f monitoring/namespace.yaml
```

Crear o actualizar el Secret externo de Grafana:

```powershell
kubectl create secret generic monitoring-grafana-admin --namespace monitoring --from-literal=admin-user=$env:GRAFANA_ADMIN_USER --from-literal=admin-password=$env:GRAFANA_ADMIN_PASSWORD --dry-run=client -o yaml | kubectl apply -f -
```

Instalar o actualizar `kube-prometheus-stack`:

```powershell
helm upgrade --install monitoring prometheus-community/kube-prometheus-stack --namespace monitoring --version 84.5.0 -f monitoring/values.yaml
```

Instalar o actualizar Pushgateway:

```powershell
helm upgrade --install pushgateway prometheus-community/prometheus-pushgateway --namespace monitoring --version 3.6.0 -f monitoring/pushgateway-values.yaml
```

Aplicar el `ServiceMonitor` de Pushgateway:

```powershell
kubectl apply -f monitoring/pushgateway-servicemonitor.yaml
```

## Comprobación de observabilidad

Comprobar Pods del namespace `monitoring`:

```powershell
kubectl get pods -n monitoring
```

Comprobar Services:

```powershell
kubectl get svc -n monitoring
```

Comprobar el `ServiceMonitor` de Pushgateway:

```powershell
kubectl get servicemonitor -n monitoring pushgateway
```

Comprobar que Pushgateway existe como Service interno:

```powershell
kubectl get svc -n monitoring pushgateway
```

Pushgateway queda como `ClusterIP`. No se expone con Ingress ni `LoadBalancer`.

## Validación de Pushgateway

Abrir Pushgateway localmente:

```powershell
kubectl port-forward -n monitoring svc/pushgateway 9091:9091
```

La terminal del `port-forward` queda ocupada. Los siguientes comandos se ejecutan en otra terminal.

Enviar una métrica de prueba:

```powershell
$body = "securekubeops_pipeline_test_metric 1`n"; Invoke-WebRequest -UseBasicParsing -Uri http://localhost:9091/metrics/job/securekubeops-test -Method Post -Body $body -ContentType "text/plain"
```

Comprobar que Pushgateway contiene la métrica:

```powershell
(Invoke-WebRequest -UseBasicParsing -Uri http://localhost:9091/metrics).Content | Select-String "securekubeops_pipeline_test_metric"
```

Eliminar la métrica de prueba:

```powershell
Invoke-WebRequest -UseBasicParsing -Uri http://localhost:9091/metrics/job/securekubeops-test -Method Delete
```

## Validación con metrics.prom

Cada workflow de GitHub Actions genera un artifact normalizado. Tras descargar y extraer el ZIP, el archivo `metrics.prom` queda en la raíz de la carpeta extraída.

Ejemplo:

```text
artifact-extraido/
  metadata.json
  metrics.prom
  <workflow-report>.html
  tools/
```

Opción 1: situarse en la carpeta extraída:

```powershell
Set-Location "C:\Users\Usuario\Downloads\artifact-extraido"
```

Enviar `metrics.prom`:

```powershell
Invoke-WebRequest -UseBasicParsing -Uri "http://localhost:9091/metrics/job/securekubeops-manual-validation" -Method Post -InFile "metrics.prom" -ContentType "text/plain"
```

Opción 2: usar ruta absoluta:

```powershell
Invoke-WebRequest -UseBasicParsing -Uri "http://localhost:9091/metrics/job/securekubeops-manual-validation" -Method Post -InFile $env:METRICS_PROM_PATH -ContentType "text/plain"
```

Comprobar que Pushgateway contiene métricas de SecureKubeOps:

```powershell
(Invoke-WebRequest -UseBasicParsing -Uri http://localhost:9091/metrics).Content | Select-String "securekubeops_"
```

Eliminar las métricas de la validación manual:

```powershell
Invoke-WebRequest -UseBasicParsing -Uri http://localhost:9091/metrics/job/securekubeops-manual-validation -Method Delete
```

## Validación en Prometheus

Abrir Prometheus localmente:

```powershell
kubectl port-forward -n monitoring svc/monitoring-kube-prometheus-prometheus 9090:9090
```

Abrir en el navegador:

```text
http://localhost:9090
```

Consultar:

```promql
securekubeops_pipeline_execution_total
```

Si la métrica no aparece inmediatamente, se espera al siguiente intervalo de scrape y se repite la consulta.

## Validación en Grafana

Abrir Grafana localmente:

```powershell
kubectl port-forward -n monitoring svc/monitoring-grafana 3000:80
```

Abrir en el navegador:

```text
http://localhost:3000
```

Acceder con el usuario definido en `$env:GRAFANA_ADMIN_USER` y la contraseña definida en `$env:GRAFANA_ADMIN_PASSWORD`.

Los paneles se construyen a partir de las consultas documentadas en `docs/pipeline-dashboard.md`.

## Ajustes habituales al cambiar de clúster

| Área | Qué se revisa |
| --- | --- |
| Registry privado | El Secret `ghcr-pull-secret` se crea en el namespace donde se despliega la API. |
| Tag de imagen | El tag `<commit-sha>` se actualiza con el SHA publicado por el pipeline en GHCR. |
| Storage | Si el clúster requiere persistencia para Prometheus o Grafana, se ajustan los valores del chart. |
| Recursos | En clústeres limitados se revisan requests y limits de los componentes de observabilidad. |
| Red | Pushgateway, Prometheus y Grafana permanecen internos. Si se exponen, se añaden TLS, autenticación y restricciones de red. |
| Secretos | Las credenciales reales se crean en el clúster y no se guardan en el repositorio. |
| ServiceMonitor | El label `release: monitoring` se mantiene si la release Helm se llama `monitoring`; si cambia el nombre de release, se revisa este selector. |

## Evidencias para el TFG

Las evidencias de portabilidad quedan formadas por:

- manifiestos versionados en `k8s/`;
- manifiestos versionados en `monitoring/`;
- creación del `imagePullSecret` para GHCR privado sin versionar tokens;
- creación del Secret externo de Grafana sin versionar contraseñas;
- salida de `kubectl get pods`;
- salida de `kubectl get svc`;
- salida de `kubectl get pods -n monitoring`;
- salida de `kubectl get svc -n monitoring`;
- salida de `kubectl get servicemonitor -n monitoring pushgateway`;
- comprobación de `/health` mediante `port-forward`;
- comprobación de una métrica `securekubeops_*` en Pushgateway;
- consulta de la misma métrica en Prometheus;
- panel o consulta equivalente en Grafana;
- artifact original de GitHub Actions que contiene `metrics.prom`.

## Relación con otros documentos

| Documento | Relación |
| --- | --- |
| `docs/minikube-deployment.md` | Documenta el despliegue local de la API de referencia y el uso de `imagePullSecret`. |
| `docs/observability.md` | Describe la configuración base de Prometheus, Grafana y Pushgateway. |
| `docs/pipeline-metrics-integration.md` | Detalla cómo enviar manualmente `metrics.prom` a Pushgateway. |
| `docs/pipeline-dashboard.md` | Define las consultas PromQL y los paneles de Grafana. |
| `docs/pipeline-evidence.md` | Explica cómo los workflows generan artifacts y `metrics.prom`. |
