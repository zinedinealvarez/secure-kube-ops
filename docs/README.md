# Documentacion tecnica

Esta carpeta agrupa la documentacion operativa y de validacion de SecureKubeOps.

## Organizacion

| Carpeta | Contenido |
| --- | --- |
| `ci-cd/` | Flujo Git, criterios de parada, evidencias del pipeline, validacion de workflows y decisiones de Dependabot. |
| `deployment/` | Despliegue de la aplicacion de referencia, AKS, Minikube, portabilidad y laboratorio OWASP Juice Shop. |
| `observability/` | Instalacion de Prometheus, Grafana y Pushgateway, metricas del pipeline y dashboards. |
| `security/` | Seguridad runtime con Trivy Operator y notas de datos de laboratorio. |

La capa WAF se documenta en `../azure-waf/`, ya que contiene scripts y manifiestos propios para crear y eliminar recursos de Azure durante pruebas puntuales.

Los recursos desplegables de Kubernetes se agrupan en `../k8s/`. La configuracion propia de herramientas de seguridad del pipeline se agrupa en `../security-tools/`.

## Documentos principales

| Documento | Uso |
| --- | --- |
| `ci-cd/branch-flow.md` | Flujo de ramas y proteccion de `main`. |
| `ci-cd/criterios-parada-pipeline.md` | Criterios de validacion, Security Gates y parada del pipeline. |
| `ci-cd/pipeline-evidence.md` | Estructura de artifacts, reportes, metadatos y metricas generadas por los workflows. |
| `ci-cd/pipeline-validation.md` | Validacion real del pipeline a partir de artifacts de GitHub Actions. |
| `deployment/cluster-portability.md` | Puesta en marcha de SecureKubeOps en otro cluster Kubernetes. |
| `deployment/aks-deployment-evidence.md` | Evidencias de despliegue en AKS. |
| `deployment/minikube-deployment.md` | Despliegue local de la aplicacion de referencia. |
| `deployment/juice-shop-deployment.md` | Despliegue de OWASP Juice Shop como laboratorio vulnerable. |
| `observability/observability.md` | Instalacion y comprobacion de Prometheus, Grafana y Pushgateway. |
| `observability/pipeline-metrics-integration.md` | Envio de `metrics.prom` hacia Pushgateway y validacion en Prometheus. |
| `observability/pipeline-dashboard.md` | Consultas y paneles del dashboard del pipeline. |
| `security/runtime-security-monitoring.md` | Trivy Operator y seguridad en tiempo de ejecucion. |
