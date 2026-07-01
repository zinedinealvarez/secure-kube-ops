# Manual de instalacion

Este manual indica los pasos para instalar SecureKubeOps sobre un cluster Kubernetes ya creado. Los scripts no crean el cluster desde cero: instalan la aplicacion de referencia, el laboratorio vulnerable, observabilidad, seguridad runtime y, opcionalmente, la capa WAF de Azure.

La capa WAF debe desplegarse solo durante ventanas de prueba, porque crea recursos gestionados en Azure que pueden generar coste.

## 1. Comprobar herramientas

Ejecutar:

```powershell
kubectl version --client
helm version
```

Si se va a instalar el WAF, comprobar tambien:

```powershell
az version
az account show -o table
```

## 2. Comprobar conexion al cluster

Ejecutar:

```powershell
kubectl config current-context
kubectl get nodes
```

Resultado esperado:

- `kubectl` muestra el contexto correcto.
- Los nodos aparecen en estado `Ready`.

## 3. Definir variables necesarias

Si la imagen de GHCR es privada:

```powershell
$env:GHCR_USERNAME="TU_USUARIO_GITHUB"
$env:GHCR_TOKEN="TOKEN_CON_READ_PACKAGES"
```

Para Grafana:

```powershell
$env:GRAFANA_ADMIN_USER="admin"
$env:GRAFANA_ADMIN_PASSWORD="CONTRASENA_LOCAL"
```

Estas variables solo viven en la terminal actual y no se guardan en el repositorio.

## 4. Instalar SecureKubeOps sin WAF

Desde la raiz del repositorio:

```powershell
powershell -ExecutionPolicy Bypass -File .\manuales\scripts\install-securekubeops.ps1
```

Este comando instala:

1. Aplicacion de referencia en `application`.
2. OWASP Juice Shop en `vulnerable-lab`.
3. Prometheus, Grafana y Pushgateway en `monitoring`.
4. Dashboards de Grafana.
5. Trivy Operator en `runtime-security`.

Comprobar:

```powershell
kubectl get pods -A
kubectl get svc -A
```

Resultado esperado:

- Los pods principales aparecen en `Running`.
- Existen los namespaces `application`, `vulnerable-lab`, `monitoring` y `runtime-security`.

## 5. Probar la aplicacion de referencia

Abrir un port-forward:

```powershell
kubectl port-forward -n application service/secure-kube-ops 3000:3000
```

En otra terminal:

```powershell
Invoke-WebRequest -UseBasicParsing -Uri http://localhost:3000/health
```

Resultado esperado:

```json
{"status":"ok"}
```

## 6. Probar Juice Shop

Abrir un port-forward:

```powershell
kubectl port-forward -n vulnerable-lab service/juice-shop 3001:3000
```

Abrir:

```text
http://localhost:3001
```

Resultado esperado:

- La interfaz de OWASP Juice Shop carga correctamente.

## 7. Probar Grafana

Abrir un port-forward:

```powershell
kubectl port-forward -n monitoring service/monitoring-grafana 3000:80
```

Abrir:

```text
http://localhost:3000
```

Resultado esperado:

- Grafana carga.
- Existen dashboards dentro de la carpeta `SecureKubeOps`.

## 8. Instalar el WAF

Antes de instalar el WAF, comprobar que la aplicacion y Juice Shop funcionan:

```powershell
kubectl get pods -n application
kubectl get pods -n vulnerable-lab
```

Si solo se quiere instalar la capa WAF:

```powershell
powershell -ExecutionPolicy Bypass -File .\azure-waf\scripts\deploy-waf.ps1
```

Si se quiere instalar todo, incluyendo WAF, desde el script general:

```powershell
powershell -ExecutionPolicy Bypass -File .\manuales\scripts\install-securekubeops.ps1 -IncludeWaf
```

Si el entorno usa otros nombres, indicar parametros:

```powershell
powershell -ExecutionPolicy Bypass -File .\azure-waf\scripts\deploy-waf.ps1 `
  -ResourceGroup "rg-securekubeops-lab" `
  -AksName "aks-securekubeops-lab" `
  -Location "westeurope" `
  -BaseDomain "securekubeops.local" `
  -VnetName "aks-vnet-10084315" `
  -AlbSubnetName "aks-appgateway"
```

Resultado esperado:

- Se crea el namespace `alb-infra`.
- Se crea el recurso `ApplicationLoadBalancer`.
- Se crea el `Gateway`.
- Se crean las `HTTPRoute`.
- Se crean las asociaciones `WebApplicationFirewallPolicy`.

## 9. Comprobar el WAF

Ejecutar:

```powershell
kubectl get applicationloadbalancer -n alb-infra
kubectl get gateway -n alb-infra
kubectl get httproute -A
kubectl get webapplicationfirewallpolicy -A
```

Resultado esperado:

- El `ApplicationLoadBalancer` aparece con `DEPLOYMENT=True`.
- El `Gateway` aparece con `PROGRAMMED=True`.
- Las `WebApplicationFirewallPolicy` aparecen con `DEPLOYMENT=True`.

Obtener el FQDN:

```powershell
$fqdn = kubectl get gateway securekubeops-gateway -n alb-infra -o jsonpath="{.status.addresses[0].value}"
$fqdn
```

Probar la aplicacion:

```powershell
Invoke-WebRequest `
  -UseBasicParsing `
  -Uri "http://$fqdn/health" `
  -Headers @{ Host = "app.securekubeops.local" }
```

Probar Juice Shop:

```powershell
Invoke-WebRequest `
  -UseBasicParsing `
  -Uri "http://$fqdn/" `
  -Headers @{ Host = "juice-shop.securekubeops.local" }
```

Resultado esperado:

- La aplicacion responde `HTTP 200`.
- Juice Shop responde `HTTP 200`.

## 10. Abrir las aplicaciones por navegador usando el WAF

Resolver el FQDN:

```powershell
nslookup $fqdn
```

Editar como administrador:

```text
C:\Windows\System32\drivers\etc\hosts
```

Anadir:

```text
<IP_DEL_GATEWAY> app.securekubeops.local
<IP_DEL_GATEWAY> juice-shop.securekubeops.local
```

Abrir:

```text
http://app.securekubeops.local/health
http://juice-shop.securekubeops.local/
```

## 11. Borrar el WAF al terminar

Cuando terminen las pruebas:

```powershell
powershell -ExecutionPolicy Bypass -File .\azure-waf\scripts\delete-waf.ps1 -DeleteGeneratedManifests -DeleteLogAnalyticsWorkspace
```

Este comando elimina la capa WAF y los recursos asociados, pero no elimina:

- el cluster AKS;
- la aplicacion;
- Juice Shop;
- Prometheus;
- Grafana;
- Trivy Operator.

Si no se va a seguir trabajando, parar AKS:

```powershell
az aks stop --resource-group rg-securekubeops-lab --name aks-securekubeops-lab
```
