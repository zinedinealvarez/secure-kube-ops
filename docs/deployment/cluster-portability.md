# Puesta en marcha en otro clúster Kubernetes

Este documento recoge el orden completo para desplegar SecureKubeOps en un clúster Kubernetes distinto a Minikube. Incluye la API de referencia, los Secrets necesarios, la observabilidad con Prometheus y Grafana, Pushgateway y la validación de métricas del pipeline.

El flujo operativo queda definido así:

```text
GHCR -> Kubernetes -> Pushgateway -> Prometheus -> Grafana
```

La configuración es reutilizable porque se apoya en manifiestos Kubernetes, Helm y servicios internos del clúster. En AKS, las métricas del pipeline se envían desde runners internos de Actions Runner Controller hacia Pushgateway. En validaciones locales puede usarse `kubectl port-forward` como mecanismo de comprobación. Los ajustes específicos dependen del clúster de destino, especialmente permisos, almacenamiento, políticas de red, acceso a imágenes privadas y recursos disponibles.

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
| Crear PersistentVolumeClaims | Conservar métricas de Prometheus y estado local de Grafana entre reinicios. |

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

Ruta al archivo `metrics.prom`:

```powershell
$prom = "C:\Users\Usuario\Downloads\metrics.prom"
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
kubectl apply -f k8s/application/deployment.yaml
```

Aplicar el `Service`:

```powershell
kubectl apply -f k8s/application/service.yaml
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
kubectl apply -f k8s/monitoring/namespace.yaml
```

Crear o actualizar el Secret externo de Grafana:

```powershell
kubectl create secret generic monitoring-grafana-admin --namespace monitoring --from-literal=admin-user=$env:GRAFANA_ADMIN_USER --from-literal=admin-password=$env:GRAFANA_ADMIN_PASSWORD --dry-run=client -o yaml | kubectl apply -f -
```

Instalar o actualizar `kube-prometheus-stack`:

```powershell
helm upgrade --install monitoring prometheus-community/kube-prometheus-stack --namespace monitoring --version 84.5.0 -f k8s/monitoring/values.yaml
```

La configuración de `k8s/monitoring/values.yaml` solicita almacenamiento persistente para Prometheus y Grafana. El clúster de destino necesita una StorageClass por defecto o una StorageClass compatible con aprovisionamiento dinámico.

Aplicar el dashboard versionado de SecureKubeOps:

```powershell
kubectl apply -f k8s/monitoring/dashboards/grafana-dashboard-securekubeops-pipeline.yaml
```

El manifiesto crea el `ConfigMap` que consume el sidecar de Grafana. El dashboard se provisiona con un identificador estable para que las siguientes aplicaciones del manifiesto actualicen el panel existente sin duplicarlo.

Instalar o actualizar Pushgateway:

```powershell
helm upgrade --install pushgateway prometheus-community/prometheus-pushgateway --namespace monitoring --version 3.6.0 -f k8s/monitoring/pushgateway-values.yaml
```

Aplicar el `ServiceMonitor` de Pushgateway:

```powershell
kubectl apply -f k8s/monitoring/pushgateway-servicemonitor.yaml
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

Comprobar PersistentVolumeClaims:

```powershell
kubectl get pvc -n monitoring
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

Cada workflow de GitHub Actions genera un artifact normalizado con `metrics.prom`. En AKS, el job final del workflow puede enviar este fichero a Pushgateway desde el runner interno del clúster. El envío local mediante `port-forward` se conserva como procedimiento de diagnóstico o comprobación puntual.

Si el archivo ya está extraído en `C:\Users\Usuario\Downloads`, se puede enviar directamente desde esa ruta.

El `job` usado en Pushgateway identifica el workflow que ha generado el archivo:

| Workflow | Job recomendado en Pushgateway |
| --- | --- |
| `Pre Analysis` | `securekubeops-pre-analysis` |
| `Image Validation` | `securekubeops-image-validation` |
| `Branch Policy` | `securekubeops-branch-policy` |
| `Publish Image` | `securekubeops-publish-image` |

Definir la ruta del archivo:

```powershell
$prom = "C:\Users\Usuario\Downloads\metrics.prom"
```

Comprobar que existe:

```powershell
Test-Path $prom
```

Enviar un archivo de `Pre Analysis`:

```powershell
Invoke-WebRequest -UseBasicParsing -Uri "http://localhost:9091/metrics/job/securekubeops-pre-analysis" -Method Post -InFile $prom -ContentType "text/plain"
```

Enviar un archivo de `Image Validation`:

```powershell
Invoke-WebRequest -UseBasicParsing -Uri "http://localhost:9091/metrics/job/securekubeops-image-validation" -Method Post -InFile $prom -ContentType "text/plain"
```

Enviar un archivo de `Branch Policy`:

```powershell
Invoke-WebRequest -UseBasicParsing -Uri "http://localhost:9091/metrics/job/securekubeops-branch-policy" -Method Post -InFile $prom -ContentType "text/plain"
```

Enviar un archivo de `Publish Image`:

```powershell
Invoke-WebRequest -UseBasicParsing -Uri "http://localhost:9091/metrics/job/securekubeops-publish-image" -Method Post -InFile $prom -ContentType "text/plain"
```

Comprobar que Pushgateway contiene métricas de SecureKubeOps:

```powershell
(Invoke-WebRequest -UseBasicParsing -Uri http://localhost:9091/metrics).Content | Select-String "securekubeops_"
```

Eliminar las métricas de un workflow concreto:

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

Consultar solo las métricas enviadas para `Pre Analysis`:

```promql
securekubeops_pipeline_execution_total{job="securekubeops-pre-analysis"}
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

El dashboard `Pipeline Dashboard` queda provisionado desde `k8s/monitoring/dashboards/grafana-dashboard-securekubeops-pipeline.yaml`. Las consultas y criterios de los paneles quedan documentados en `docs/observability/pipeline-dashboard.md`.

## Ajustes habituales al cambiar de clúster

| Área | Qué se revisa |
| --- | --- |
| Registry privado | El Secret `ghcr-pull-secret` se crea en el namespace donde se despliega la API. |
| Tag de imagen | El tag `<commit-sha>` se actualiza con el SHA publicado por el pipeline en GHCR. |
| Storage | Prometheus solicita `5Gi` y Grafana solicita `1Gi`. Si el clúster no tiene StorageClass por defecto, se define una StorageClass válida en los valores del chart. |
| Recursos | En clústeres limitados se revisan requests y limits de los componentes de observabilidad. |
| Red | Pushgateway, Prometheus y Grafana permanecen internos. Si se exponen, se añaden TLS, autenticación y restricciones de red. |
| Secretos | Las credenciales reales se crean en el clúster y no se guardan en el repositorio. |
| ServiceMonitor | El label `release: monitoring` se mantiene si la release Helm se llama `monitoring`; si cambia el nombre de release, se revisa este selector. |

## Evidencias para el TFG

Las evidencias de portabilidad quedan formadas por:

- manifiestos versionados en `k8s/`;
- manifiestos versionados en `k8s/monitoring/`;
- creación del `imagePullSecret` para GHCR privado sin versionar tokens;
- creación del Secret externo de Grafana sin versionar contraseñas;
- salida de `kubectl get pods`;
- salida de `kubectl get svc`;
- salida de `kubectl get pods -n monitoring`;
- salida de `kubectl get svc -n monitoring`;
- salida de `kubectl get pvc -n monitoring`;
- salida de `kubectl get servicemonitor -n monitoring pushgateway`;
- comprobación de `/health` mediante `port-forward`;
- comprobación de una métrica `securekubeops_*` en Pushgateway;
- consulta de la misma métrica en Prometheus;
- panel o consulta equivalente en Grafana;
- artifact original de GitHub Actions que contiene `metrics.prom`.

## Relación con otros documentos

| Documento | Relación |
| --- | --- |
| `docs/deployment/minikube-deployment.md` | Documenta el despliegue local de la API de referencia y el uso de `imagePullSecret`. |
| `docs/observability/observability.md` | Describe la configuración base de Prometheus, Grafana y Pushgateway. |
| `docs/observability/pipeline-metrics-integration.md` | Detalla cómo enviar `metrics.prom` a Pushgateway desde ARC o mediante validación local. |
| `docs/observability/pipeline-dashboard.md` | Define las consultas PromQL y los paneles de Grafana. |
| `docs/ci-cd/pipeline-evidence.md` | Explica cómo los workflows generan artifacts y `metrics.prom`. |
