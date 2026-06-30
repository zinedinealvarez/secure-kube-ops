# Manual de instalación

Este manual describe cómo instalar SecureKubeOps sobre un clúster Kubernetes ya disponible. La instalación despliega la aplicación de referencia, OWASP Juice Shop, observabilidad con Prometheus/Grafana/Pushgateway y seguridad runtime con Trivy Operator.

La capa WAF sobre Azure se instala de forma opcional, ya que crea recursos específicos de Azure y puede generar coste.

## Requisitos previos

Herramientas necesarias:

| Herramienta | Uso |
| --- | --- |
| `kubectl` | Aplicar manifiestos y comprobar recursos del clúster. |
| `helm` | Instalar Prometheus, Grafana, Pushgateway y Trivy Operator. |
| `az` | Solo necesario si se despliega la capa WAF en Azure. |
| PowerShell | Ejecutar el script de instalación. |

Antes de instalar, comprobar que `kubectl` apunta al clúster correcto:

```powershell
kubectl config current-context
kubectl get nodes
```

## Variables necesarias

Si la imagen de GHCR es privada, definir credenciales de lectura:

```powershell
$env:GHCR_USERNAME="TU_USUARIO_GITHUB"
$env:GHCR_TOKEN="TOKEN_CON_READ_PACKAGES"
```

Para instalar observabilidad, definir las credenciales de Grafana. El chart está configurado para leerlas desde un Secret de Kubernetes:

```powershell
$env:GRAFANA_ADMIN_USER="admin"
$env:GRAFANA_ADMIN_PASSWORD="CONTRASEÑA_LOCAL"
```

Estas variables se definen en la terminal y no se guardan en el repositorio.

## Instalación completa sin WAF

Ejecutar desde la raíz del repositorio:

```powershell
powershell -ExecutionPolicy Bypass -File .\manuales\scripts\install-securekubeops.ps1
```

Este comando instala:

1. Namespace, Deployment y Service de la aplicación de referencia.
2. OWASP Juice Shop como laboratorio vulnerable.
3. Prometheus, Grafana y Pushgateway.
4. Dashboards versionados.
5. Trivy Operator y dashboard de seguridad runtime.

## Instalación por partes

Solo aplicación de referencia:

```powershell
powershell -ExecutionPolicy Bypass -File .\manuales\scripts\install-securekubeops.ps1 -SkipJuiceShop -SkipMonitoring -SkipRuntimeSecurity
```

Sin seguridad runtime:

```powershell
powershell -ExecutionPolicy Bypass -File .\manuales\scripts\install-securekubeops.ps1 -SkipRuntimeSecurity
```

Sin actualizar repositorios Helm:

```powershell
powershell -ExecutionPolicy Bypass -File .\manuales\scripts\install-securekubeops.ps1 -SkipHelmRepoUpdate
```

## Instalación con WAF

La capa WAF se debe desplegar solo cuando se vayan a realizar pruebas:

```powershell
powershell -ExecutionPolicy Bypass -File .\manuales\scripts\install-securekubeops.ps1 -IncludeWaf
```

Internamente, este modo ejecuta:

```powershell
powershell -ExecutionPolicy Bypass -File .\azure-waf\scripts\deploy-waf.ps1
```

El detalle de esta capa está en `azure-waf/README.md` y `azure-waf/deployment-runbook.md`.

## Comprobaciones tras la instalación

Comprobar recursos principales:

```powershell
kubectl get pods -A
kubectl get svc -A
```

Comprobar aplicación de referencia:

```powershell
kubectl port-forward -n application service/secure-kube-ops 3000:3000
```

En otra terminal:

```powershell
Invoke-WebRequest -UseBasicParsing -Uri http://localhost:3000/health
```

Comprobar Juice Shop:

```powershell
kubectl port-forward -n vulnerable-lab service/juice-shop 3001:3000
```

Abrir:

```text
http://localhost:3001
```

Comprobar Grafana:

```powershell
kubectl port-forward -n monitoring service/monitoring-grafana 3000:80
```

Abrir:

```text
http://localhost:3000
```

## Limpieza del WAF

Al terminar las pruebas WAF, eliminar esa capa para controlar costes:

```powershell
powershell -ExecutionPolicy Bypass -File .\azure-waf\scripts\delete-waf.ps1 -DeleteGeneratedManifests -DeleteLogAnalyticsWorkspace
```

Este comando no para AKS. Para parar AKS se usa el comando operativo habitual de Azure:

```powershell
az aks stop --resource-group rg-securekubeops-lab --name aks-securekubeops-lab
```
