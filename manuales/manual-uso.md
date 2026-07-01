# Manual de uso

Este manual resume cómo utilizar SecureKubeOps una vez desplegado.

## Flujo general

El uso normal del sistema parte del repositorio GitHub:

1. El desarrollador sube cambios a una rama `pre-*`.
2. El workflow `Pre Analysis` ejecuta análisis de secretos, SAST y configuración Kubernetes.
3. Si los controles pasan, se abre una Pull Request hacia `main`.
4. La Pull Request ejecuta política de ramas y validación de imagen.
5. Tras el merge en `main`, se publica la imagen en GHCR.
6. La imagen validada queda disponible para desplegarse en Kubernetes aplicando el manifiesto correspondiente.
7. Prometheus y Grafana permiten consultar métricas del pipeline y del clúster.
8. Trivy Operator genera informes de seguridad runtime.
9. La capa WAF puede activarse para pruebas de protección de entrada.

## Aplicación de referencia

La aplicación se ejecuta en el namespace `application`.

Comprobar estado:

```powershell
kubectl get pods -n application
kubectl get svc -n application
```

Acceder localmente:

```powershell
kubectl port-forward -n application service/secure-kube-ops 3000:3000
```

Endpoints principales:

| Endpoint | Uso |
| --- | --- |
| `/` | Información básica de la API. |
| `/health` | Comprobación de salud. |
| `/version` | Versión y finalidad de la API. |
| `/items` | Datos de ejemplo para validar la API. |

## Laboratorio vulnerable

OWASP Juice Shop se ejecuta en el namespace `vulnerable-lab`.

Comprobar estado:

```powershell
kubectl get pods -n vulnerable-lab
kubectl get svc -n vulnerable-lab
```

Acceder localmente:

```powershell
kubectl port-forward -n vulnerable-lab service/juice-shop 3001:3000
```

Abrir en el navegador:

```text
http://localhost:3001
```

Juice Shop se usa como objetivo de pruebas controladas de seguridad, especialmente para validar detección y bloqueo del WAF.

## Observabilidad

Prometheus, Grafana y Pushgateway se ejecutan en el namespace `monitoring`.

Comprobar estado:

```powershell
kubectl get pods -n monitoring
kubectl get svc -n monitoring
```

Abrir Prometheus:

```powershell
kubectl port-forward -n monitoring service/monitoring-kube-prometheus-prometheus 9090:9090
```

Abrir Grafana:

```powershell
kubectl port-forward -n monitoring service/monitoring-grafana 3000:80
```

Pushgateway se mantiene como servicio interno. En AKS, las métricas del pipeline se envían desde el job `push-pipeline-metrics`, ejecutado por un runner de Actions Runner Controller dentro del clúster. Esto evita exponer Pushgateway a internet.

## Seguridad runtime

Trivy Operator se ejecuta en el namespace `runtime-security`.

Comprobar operador:

```powershell
kubectl get pods -n runtime-security
```

Consultar reports:

```powershell
kubectl get vulnerabilityreports -A
kubectl get configauditreports -A
kubectl get exposedsecretreports -A
```

Esta capa funciona en modo observación: genera evidencias, pero no bloquea despliegues.

## WAF

La capa WAF se despliega únicamente durante pruebas puntuales:

```powershell
powershell -ExecutionPolicy Bypass -File .\azure-waf\scripts\deploy-waf.ps1
```

Obtener el hostname del Gateway:

```powershell
$fqdn = kubectl get gateway securekubeops-gateway -n alb-infra -o jsonpath="{.status.addresses[0].value}"
```

Probar aplicación de referencia:

```powershell
Invoke-WebRequest -UseBasicParsing -Uri "http://$fqdn/health" -Headers @{ Host = "app.securekubeops.local" }
```

Probar Juice Shop:

```powershell
Invoke-WebRequest -UseBasicParsing -Uri "http://$fqdn/" -Headers @{ Host = "juice-shop.securekubeops.local" }
```

Al terminar, eliminar la capa WAF:

```powershell
powershell -ExecutionPolicy Bypass -File .\azure-waf\scripts\delete-waf.ps1 -DeleteGeneratedManifests -DeleteLogAnalyticsWorkspace
```

## Documentación técnica relacionada

| Tema | Documento |
| --- | --- |
| CI/CD y evidencias | `docs/ci-cd/` |
| Despliegue Kubernetes | `docs/deployment/` |
| Observabilidad | `docs/observability/` |
| Seguridad runtime | `docs/security/` |
| WAF en Azure | `azure-waf/` |
