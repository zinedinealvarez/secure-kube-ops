# Manual de uso

Este manual indica como usar SecureKubeOps una vez instalado. Esta pensado como una lista de pasos operativos.

## 1. Usar el flujo DevSecOps

1. Crear o usar una rama `pre-*`.
2. Subir cambios con `git push`.
3. Revisar el workflow `Pre Analysis`.
4. Si pasa, abrir Pull Request hacia `main`.
5. Revisar `Branch Policy` e `Image Validation`.
6. Si pasan, hacer merge.
7. Revisar `Publish Image` en `main`.
8. Consultar metricas y evidencias en Grafana y GitHub Actions.

## 2. Comprobar la aplicacion

Ejecutar:

```powershell
kubectl get pods -n application
kubectl get svc -n application
```

Abrir acceso local:

```powershell
kubectl port-forward -n application service/secure-kube-ops 3000:3000
```

Probar:

```powershell
Invoke-WebRequest -UseBasicParsing -Uri http://localhost:3000/health
```

Endpoints:

| Endpoint | Uso |
| --- | --- |
| `/` | Informacion basica de la API. |
| `/health` | Salud de la API. |
| `/version` | Version de la API. |
| `/items` | Datos de ejemplo. |

## 3. Comprobar Juice Shop

Ejecutar:

```powershell
kubectl get pods -n vulnerable-lab
kubectl get svc -n vulnerable-lab
```

Abrir acceso local:

```powershell
kubectl port-forward -n vulnerable-lab service/juice-shop 3001:3000
```

Abrir:

```text
http://localhost:3001
```

## 4. Comprobar observabilidad

Comprobar pods:

```powershell
kubectl get pods -n monitoring
```

Abrir Prometheus:

```powershell
kubectl port-forward -n monitoring service/monitoring-kube-prometheus-prometheus 9090:9090
```

URL:

```text
http://localhost:9090
```

Consultas utiles:

```promql
securekubeops_pipeline_execution_total
```

```promql
sum(securekubeops_pipeline_execution_total{workflow="pre_analysis"})
```

```promql
securekubeops_security_finding_info
```

Abrir Grafana:

```powershell
kubectl port-forward -n monitoring service/monitoring-grafana 3000:80
```

URL:

```text
http://localhost:3000
```

Revisar los dashboards:

1. `SecureKubeOps Cluster Overview`.
2. `SecureKubeOps Pipeline Dashboard`.
3. `SecureKubeOps Runtime Security - Trivy Operator`.

## 5. Comprobar seguridad runtime

Ejecutar:

```powershell
kubectl get pods -n runtime-security
```

Consultar reports:

```powershell
kubectl get vulnerabilityreports -A
kubectl get configauditreports -A
kubectl get exposedsecretreports -A
kubectl get rbacassessmentreports -A
```

Resultado esperado:

- Trivy Operator genera reports sobre los recursos desplegados.
- Esta capa observa y reporta; no bloquea despliegues.

## 6. Desplegar el WAF para pruebas

Ejecutar:

```powershell
powershell -ExecutionPolicy Bypass -File .\azure-waf\scripts\deploy-waf.ps1
```

Esperar a que termine. Si Azure indica que una feature esta en registro, esperar a que aparezca como `Registered` y repetir el comando.

Comprobar recursos:

```powershell
kubectl get applicationloadbalancer -n alb-infra
kubectl get gateway -n alb-infra
kubectl get httproute -A
kubectl get webapplicationfirewallpolicy -A
```

Resultado esperado:

- `Gateway` con `PROGRAMMED=True`.
- `WebApplicationFirewallPolicy` con `DEPLOYMENT=True`.

## 7. Probar trafico normal por WAF

Obtener FQDN:

```powershell
$fqdn = kubectl get gateway securekubeops-gateway -n alb-infra -o jsonpath="{.status.addresses[0].value}"
$fqdn
```

Probar aplicacion:

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

- Ambas peticiones responden correctamente.
- El trafico esta pasando por Application Gateway for Containers y Azure WAF.

## 8. Abrir WAF en navegador

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

## 9. Probar WAF en modo Detection

El despliegue deja la WAF Policy en modo `Detection`. En este modo el WAF inspecciona y registra, pero no tiene por que bloquear.

Enviar XSS controlado:

```powershell
Invoke-WebRequest `
  -UseBasicParsing `
  -Uri "http://$fqdn/?q=%3Cscript%3Ealert(1)%3C%2Fscript%3E" `
  -Headers @{ Host = "juice-shop.securekubeops.local" }
```

Enviar SQLi controlado:

```powershell
Invoke-WebRequest `
  -UseBasicParsing `
  -Uri "http://$fqdn/?id=1%27%20OR%20%271%27%3D%271" `
  -Headers @{ Host = "juice-shop.securekubeops.local" }
```

Resultado esperado:

- La peticion puede pasar.
- Deben generarse logs o metricas del WAF si los diagnosticos estan activos.

## 10. Consultar logs del WAF

Abrir el workspace `law-securekubeops-waf` en Azure Portal y ejecutar:

```kusto
search *
| where TimeGenerated > ago(24h)
| take 50
```

Para ver tablas con datos:

```kusto
union withsource=__TablaOrigen *
| where TimeGenerated > ago(24h)
| summarize Count=count() by __TablaOrigen
| order by Count desc
```

Para ver metricas del Traffic Controller:

```kusto
AzureMetrics
| where ResourceProvider == "MICROSOFT.SERVICENETWORKING"
| summarize Count=count() by MetricName
```

## 11. Probar WAF en modo Prevention

Cambiar a modo bloqueo:

```powershell
az network application-gateway waf-policy policy-setting update `
  --resource-group rg-securekubeops-lab `
  --policy-name waf-securekubeops-detection `
  --mode Prevention `
  --state Enabled
```

Esperar unos minutos y repetir las peticiones XSS/SQLi del paso anterior.

Resultado esperado:

- El WAF bloquea o mitiga las peticiones maliciosas.
- Se generan evidencias para documentar la prueba.

Volver a modo deteccion:

```powershell
az network application-gateway waf-policy policy-setting update `
  --resource-group rg-securekubeops-lab `
  --policy-name waf-securekubeops-detection `
  --mode Detection `
  --state Enabled
```

## 12. Eliminar el WAF

Al terminar:

```powershell
powershell -ExecutionPolicy Bypass -File .\azure-waf\scripts\delete-waf.ps1 -DeleteGeneratedManifests -DeleteLogAnalyticsWorkspace
```

Comprobar:

```powershell
kubectl get applicationloadbalancer,gateway,httproute,healthcheckpolicy,webapplicationfirewallpolicy -A
az network application-gateway waf-policy list --resource-group rg-securekubeops-lab -o table
```

Resultado esperado:

- No quedan recursos WAF activos.
- La aplicacion base, Juice Shop, observabilidad y Trivy Operator siguen desplegados.

## 13. Parar AKS si no se va a seguir trabajando

```powershell
az aks stop --resource-group rg-securekubeops-lab --name aks-securekubeops-lab
```

## Documentacion tecnica relacionada

| Tema | Documento |
| --- | --- |
| CI/CD y evidencias | `docs/ci-cd/` |
| Despliegue Kubernetes | `docs/deployment/` |
| Observabilidad | `docs/observability/` |
| Seguridad runtime | `docs/security/` |
| WAF en Azure | `azure-waf/` |
