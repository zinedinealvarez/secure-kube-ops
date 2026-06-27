# Monitorizacion interna y seguridad runtime

Este documento prepara la fase de monitorizacion interna del cluster y seguridad runtime de SecureKubeOps.

El alcance actual se limita a:

- observabilidad interna del cluster con la base existente de Prometheus y Grafana;
- inventario de workloads e imagenes desplegadas;
- Trivy Operator en modo observacion;
- reports de vulnerabilidades, configuraciones inseguras y posibles secretos embebidos en imagenes;
- compatibilidad entre Minikube ahora y AKS mas adelante con los minimos cambios posibles.

Quedan fuera de esta fase:

- AKS como despliegue activo;
- WAF;
- NetworkPolicies;
- cambios en workflows de GitHub Actions;
- cambios en la aplicacion de referencia;
- cambios en OWASP Juice Shop.

## Encaje con SecureKubeOps

SecureKubeOps ya cuenta con una base de observabilidad en `monitoring/` mediante `kube-prometheus-stack`, Prometheus, Grafana, `kube-state-metrics`, `node-exporter` y Pushgateway.

Esa capa cubre el estado interno del cluster:

- nodos;
- pods;
- deployments;
- services;
- reinicios de contenedores;
- uso de CPU y memoria;
- estado de objetos Kubernetes mediante `kube-state-metrics`.

La capa nueva de `runtime-security/` no reemplaza esa base. La complementa con Trivy Operator para obtener evidencias de seguridad sobre workloads ya desplegados.

## Herramientas

| Necesidad | Herramienta |
| --- | --- |
| Estado interno del cluster | `kube-prometheus-stack`, `kube-state-metrics`, `node-exporter` |
| Dashboards y consultas | Grafana sobre Prometheus |
| Inventario de workloads e imagenes | `kubectl` y metricas de `kube-state-metrics` |
| Vulnerabilidades en imagenes en ejecucion | Trivy Operator |
| Configuraciones inseguras en Kubernetes | Trivy Operator |
| Posibles secretos embebidos en imagenes | Trivy Operator |

Trivy Operator se instala en modo observacion: crea Custom Resources con reports de seguridad, pero no actua como admission controller ni bloquea despliegues.

La configuracion activa metricas detalladas para que Grafana pueda mostrar tablas de CVEs, configuraciones inseguras y posibles secretos embebidos:

- `metricsVulnIdEnabled`;
- `metricsConfigAuditInfo`;
- `metricsExposedSecretInfo`.

Tambien se activan RBAC Assessment e InfraAssessment en modo observacion para cubrir problemas de permisos y postura del cluster sin bloquear despliegues:

- `rbacAssessmentScannerEnabled`;
- `infraAssessmentScannerEnabled`;
- `metricsRbacAssessmentInfo`;
- `metricsInfraAssessmentInfo`.

## Estructura

La estructura preparada es:

```text
runtime-security/
`-- trivy-operator/
    |-- namespace.yaml
    |-- values.yaml
    `-- README.md
```

El namespace elegido es `runtime-security`.

La configuracion excluye namespaces de sistema y observabilidad:

```text
kube-system,kube-public,kube-node-lease,monitoring,runtime-security
```

De este modo, el operador se centra en los workloads del laboratorio, como la aplicacion de referencia y OWASP Juice Shop, sin mezclar ruido de componentes internos.

## Instalacion en Minikube

Comprobar que Minikube esta activo:

```powershell
minikube status
```

Comprobar el contexto activo:

```powershell
kubectl config current-context
```

Comprobar nodos:

```powershell
kubectl get nodes
```

Aplicar el namespace:

```powershell
kubectl apply -f runtime-security/trivy-operator/namespace.yaml
```

Anadir el repositorio Helm de Aqua Security:

```powershell
helm repo add aqua https://aquasecurity.github.io/helm-charts/
helm repo update
```

Instalar Trivy Operator:

```powershell
helm upgrade --install trivy-operator aqua/trivy-operator `
  --namespace runtime-security `
  --version 0.32.1 `
  -f runtime-security/trivy-operator/values.yaml
```

## Verificacion de instalacion

Comprobar la release:

```powershell
helm list -n runtime-security
```

Comprobar el Deployment:

```powershell
kubectl get deployment -n runtime-security
```

Comprobar Pods:

```powershell
kubectl get pods -n runtime-security
```

Revisar logs si el operador no arranca:

```powershell
kubectl logs deployment/trivy-operator -n runtime-security
```

Comprobar que existen los CRD principales:

```powershell
kubectl get crd | Select-String "aquasecurity"
```

## Verificacion de reports

Trivy Operator genera reports de forma asincrona. Tras instalarlo, conviene esperar unos minutos y consultar:

```powershell
kubectl get vulnerabilityreports -A
```

```powershell
kubectl get configauditreports -A
```

```powershell
kubectl get exposedsecretreports -A
```

Para inspeccionar un report concreto:

```powershell
kubectl describe vulnerabilityreport -n vulnerable-lab
```

```powershell
kubectl describe configauditreport -n vulnerable-lab
```

```powershell
kubectl describe exposedsecretreport -n vulnerable-lab
```

Si no aparecen reports inmediatamente, comprobar los Jobs de escaneo:

```powershell
kubectl get jobs -A | Select-String "scan"
```

Y revisar logs del operador:

```powershell
kubectl logs deployment/trivy-operator -n runtime-security
```

## Inventario de workloads e imagenes

Ver workloads principales:

```powershell
kubectl get deployments -A
```

```powershell
kubectl get pods -A
```

```powershell
kubectl get svc -A
```

Listar imagenes ejecutandose en el cluster:

```powershell
kubectl get pods -A -o jsonpath="{range .items[*]}{.metadata.namespace}{' '}{.metadata.name}{' '}{range .spec.containers[*]}{.image}{' '}{end}{'\n'}{end}"
```

Con Prometheus y `kube-state-metrics`, el inventario tambien puede consultarse mediante metricas como:

```promql
kube_pod_container_info
```

Ejemplo para listar imagenes por namespace, pod y contenedor:

```promql
count by (namespace, pod, container, image) (kube_pod_container_info)
```

## Metricas y Grafana

La configuracion de Trivy Operator habilita `serviceMonitor.enabled` para que Prometheus pueda descubrir sus metricas si `kube-prometheus-stack` ya esta instalado.

El `ServiceMonitor` se crea en el namespace `monitoring` con la etiqueta:

```yaml
release: monitoring
```

Esto mantiene la misma convencion usada por el `ServiceMonitor` de Pushgateway.

Comprobar el `ServiceMonitor`:

```powershell
kubectl get servicemonitor -n monitoring
```

Metricas esperadas para el dashboard de Trivy Operator:

```promql
trivy_image_vulnerabilities
```

```promql
trivy_vulnerability_id
```

```promql
trivy_resource_configaudits
```

```promql
trivy_configaudits_info
```

```promql
trivy_image_exposedsecrets
```

```promql
trivy_exposedsecrets_info
```

Tambien se esperan metricas de RBAC e infraestructura:

```promql
trivy_rbacassessments_info
```

```promql
trivy_infraassessments_info
```

Abrir Prometheus:

```powershell
kubectl port-forward -n monitoring svc/monitoring-kube-prometheus-prometheus 9090:9090
```

Abrir Grafana:

```powershell
kubectl port-forward -n monitoring svc/monitoring-grafana 3000:80
```

En esta fase no se anade un dashboard nuevo obligatorio. Primero se validan los reports de Trivy Operator y el inventario de workloads. Despues se puede decidir si conviene crear un dashboard especifico de runtime security.

El dashboard de runtime security se provisiona desde:

```text
monitoring/dashboards/grafana-dashboard-trivy-operator.yaml
```

Aplicarlo:

```powershell
kubectl apply --server-side -f monitoring/dashboards/grafana-dashboard-trivy-operator.yaml
```

El dashboard utiliza el datasource `prometheus` y contiene secciones para vulnerabilidades, configuraciones inseguras, secretos embebidos, RBAC Assessment e InfraAssessment.

Al igual que los dashboards del pipeline y de observabilidad interna, queda agrupado en la carpeta `SecureKubeOps` de Grafana mediante la anotacion `grafana_folder: SecureKubeOps` del ConfigMap. El sidecar usa `folderAnnotation` y `foldersFromFilesStructure: true` para respetar esa carpeta. Los dashboards por defecto de `kube-prometheus-stack` se agrupan aparte con la anotacion `grafana_folder: Kubernetes`.

Se utiliza `kubectl apply --server-side` porque el dashboard de Trivy Operator es grande. El `apply` client-side intenta guardar el manifiesto completo dentro de la anotacion `kubectl.kubernetes.io/last-applied-configuration` y puede superar el limite maximo de anotaciones de Kubernetes.

## Relacion con otros documentos

| Documento | Relacion |
| --- | --- |
| `docs/observability.md` | Instala la base de Prometheus, Grafana, `kube-state-metrics` y `node-exporter` sobre la que se apoya esta fase. |
| `docs/juice-shop-deployment.md` | Despliega OWASP Juice Shop como workload vulnerable que puede aparecer en el inventario y en los reports de Trivy Operator. |
| `docs/minikube-deployment.md` | Documenta el despliegue local de la aplicacion de referencia, tambien visible para inventario y escaneo runtime. |
| `docs/cluster-portability.md` | Recoge criterios generales para repetir la puesta en marcha en otro cluster Kubernetes. |
| `docs/pipeline-evidence.md` | Documenta las evidencias de CI/CD; esta fase complementa esas evidencias con reports del cluster en ejecucion. |

## Evidencias para el TFG

Evidencias recomendadas:

- `runtime-security/trivy-operator/namespace.yaml`;
- `runtime-security/trivy-operator/values.yaml`;
- salida de `helm list -n runtime-security`;
- salida de `kubectl get pods -n runtime-security`;
- salida de `kubectl get vulnerabilityreports -A`;
- salida de `kubectl get configauditreports -A`;
- salida de `kubectl get exposedsecretreports -A`;
- detalle de al menos un `VulnerabilityReport`;
- detalle de al menos un `ConfigAuditReport`;
- detalle de reports o metricas de RBAC Assessment e InfraAssessment si el cluster genera hallazgos;
- comprobacion en Prometheus de metricas `trivy_*`;
- inventario de imagenes ejecutandose en el cluster;
- consulta `kube_pod_container_info` en Prometheus;
- captura opcional de Grafana mostrando estado de workloads o metricas internas.

## Portabilidad a AKS

La instalacion se ha planteado con Helm y manifiestos Kubernetes genericos para poder repetirla en AKS sin redisenar la solucion.

Aspectos a revisar al migrar:

| Area | Consideracion |
| --- | --- |
| Permisos | El usuario o identidad usada en AKS debe poder instalar CRDs, ClusterRoles y ClusterRoleBindings. |
| Salida a Internet | Trivy necesita descargar bases de vulnerabilidades y consultar registros de imagenes. En clusters con egress restringido habra que permitir esos destinos o preparar cache/mirrors. |
| Registros privados | La imagen propia en GHCR puede requerir `imagePullSecret` o integracion especifica de identidad. |
| Azure Container Registry | Si en el futuro se usa ACR, puede convenir integrar permisos de lectura mediante identidad gestionada. |
| Namespaces excluidos | En AKS puede interesar excluir namespaces gestionados adicionales, ademas de los definidos para Minikube. |
| Coste de recursos | Los Jobs de escaneo consumen CPU, memoria y red. En AKS hay que ajustar concurrencia y limites si el cluster es pequeno. |
| Observabilidad gestionada | AKS puede usar Azure Monitor, managed Prometheus o Azure Managed Grafana. La configuracion actual mantiene Prometheus/Grafana propios para maximizar portabilidad. |
| Persistencia | La capa de observabilidad ya usa PVC. En AKS hay que comprobar la StorageClass por defecto. |

El cambio minimo esperado para AKS seria ajustar namespaces excluidos, permisos de registry y, si existe egress restringido, la configuracion de salida de Trivy.

## Limpieza

Eliminar la release:

```powershell
helm uninstall trivy-operator -n runtime-security
```

Eliminar el namespace:

```powershell
kubectl delete namespace runtime-security
```

Los CRDs de Trivy Operator no se eliminan automaticamente al desinstalar la release. Si se eliminan manualmente, tambien se borran los reports generados.
