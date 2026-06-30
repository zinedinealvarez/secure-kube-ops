# Azure WAF for AKS

Esta carpeta contiene la preparacion de la capa WAF de SecureKubeOps sobre AKS usando Azure Application Gateway for Containers, ALB Controller, Gateway API y Azure Web Application Firewall.

Los manifiestos se dejan como plantillas (`*.template.yaml`) porque necesitan IDs reales de Azure antes de aplicarse. Esto evita crear recursos de pago por accidente durante el desarrollo.

## Relacion con los comandos oficiales

La documentacion oficial de Microsoft muestra muchos pasos usando comandos del tipo `kubectl apply -f - <<EOF`. Ese formato crea manifiestos Kubernetes directamente desde la terminal.

En este repositorio se usa el mismo enfoque, pero guardando esos manifiestos como archivos versionados. La diferencia es:

| En la documentacion oficial | En este repositorio |
| --- | --- |
| El YAML se escribe dentro del comando. | El YAML se guarda en `azure-waf/manifests/`. |
| Es rapido para una prueba puntual. | Es mas facil de revisar, documentar y repetir. |
| Los valores se sustituyen en variables de shell. | Los valores pendientes quedan como placeholders. |

Por tanto, estos archivos no sustituyen a Azure CLI ni crean por si solos todos los recursos. Sirven para versionar la parte declarativa de Kubernetes que el ALB Controller necesita para crear y conectar Application Gateway for Containers.

## Manifiestos

| Archivo | Funcion |
| --- | --- |
| `application-load-balancer.template.yaml` | Define el namespace de infraestructura y el recurso `ApplicationLoadBalancer`, que representa la entrada gestionada por Azure. |
| `gateway-and-routes.template.yaml` | Define un `Gateway` compartido y dos `HTTPRoute`: una ruta para Juice Shop y otra para la aplicacion de referencia. |
| `health-check-policy.yaml` | Configura el health check de la aplicacion de referencia para usar `/health`. |
| `waf-policy-association.template.yaml` | Asocia una politica Azure WAF existente a cada ruta publicada. |

## Scripts operativos

| Script | Funcion |
| --- | --- |
| `azure-waf/scripts/deploy-waf.ps1` | Reconstruye solo la capa WAF/entrada: renderiza plantillas, aplica Gateway/HTTPRoute/HealthCheckPolicy y asocia la WAF Policy. No despliega las aplicaciones base. |
| `azure-waf/scripts/delete-waf.ps1` | Elimina solo los recursos de WAF/Application Gateway for Containers y, opcionalmente, borra manifiestos generados o desactiva el add-on. No para AKS. |

## Arquitectura

```text
Cliente / navegador de pruebas
  -> Azure Application Gateway for Containers
  -> Azure Web Application Firewall
  -> Gateway compartido en AKS
  -> HTTPRoute de cada aplicacion
  -> Services internos
  -> Pods
```

## Componentes

| Componente | Funcion |
| --- | --- |
| Azure Application Gateway for Containers | Entrada HTTP/HTTPS gestionada para aplicaciones en Kubernetes. Es el componente externo que recibe el trafico antes de enviarlo al cluster. |
| ALB Controller | Controlador instalado en AKS que crea y sincroniza recursos de Application Gateway for Containers desde manifiestos Kubernetes. |
| ApplicationLoadBalancer | Recurso custom de Kubernetes que permite al ALB Controller crear el Application Gateway for Containers y asociarlo a la red de Azure. |
| Gateway | Punto de entrada declarativo de Gateway API compartido por las aplicaciones expuestas. Define los listeners HTTP y los nombres de host. |
| HTTPRoute | Reglas que enrutan el trafico del Gateway al Service `juice-shop` y al Service `secure-kube-ops`. |
| HealthCheckPolicy | Politica del ALB Controller que define como comprobar la salud del backend `secure-kube-ops`. |
| WebApplicationFirewallPolicy | Recurso custom que asocia una politica Azure WAF existente a cada `HTTPRoute`. |

## Enlaces oficiales utiles

| Tema | Enlace |
| --- | --- |
| Application Gateway for Containers | https://learn.microsoft.com/en-us/azure/application-gateway/for-containers/overview |
| Despliegue gestionado por ALB Controller | https://learn.microsoft.com/en-us/azure/application-gateway/for-containers/quickstart-create-application-gateway-for-containers-managed-by-alb-controller |
| Azure WAF con Application Gateway for Containers | https://learn.microsoft.com/en-us/azure/application-gateway/for-containers/web-application-firewall |
| Gateway API de Kubernetes | https://gateway-api.sigs.k8s.io/ |

## Recursos previstos

En Azure:

- AKS existente.
- Subred dedicada para Application Gateway for Containers, delegada a `Microsoft.ServiceNetworking/trafficControllers`.
- Managed identity usada por ALB Controller.
- Azure WAF Policy en modo `Detection` y posteriormente en modo `Prevention`.

En AKS:

- Gateway API CRDs.
- ALB Controller.
- `ApplicationLoadBalancer` en el namespace `alb-infra`.
- `Gateway` compartido en el namespace `alb-infra`.
- `HTTPRoute` y `WebApplicationFirewallPolicy` para Juice Shop en el namespace `vulnerable-lab`.
- `HTTPRoute` y `WebApplicationFirewallPolicy` para la aplicacion de referencia en el namespace `application`.
- Deployment y Service de OWASP Juice Shop ya versionados en `k8s/labs/juice-shop`.
- Deployment y Service de la aplicacion de referencia ya versionados en `k8s/application/`.

## Orden de despliegue previsto

1. Arrancar o crear AKS y comprobar el contexto activo.
2. Desplegar Juice Shop:

   ```powershell
   kubectl apply -k k8s/labs/juice-shop
   ```

3. Instalar las CRDs de Gateway API si no estan presentes en el cluster.
4. Instalar ALB Controller en AKS siguiendo la documentacion oficial de Microsoft.
5. Crear o reutilizar una subred dedicada para Application Gateway for Containers y delegarla a `Microsoft.ServiceNetworking/trafficControllers`.
6. Asignar a la identidad gestionada del controlador los permisos necesarios sobre el grupo de recursos y la subred.
7. Crear una politica Azure WAF en modo `Detection`.
8. Sustituir los placeholders de las plantillas:

   ```text
   <ALB_SUBNET_ID>
   <AZURE_WAF_POLICY_RESOURCE_ID>
   <BASE_DOMAIN>
   ```

9. Aplicar los manifiestos renderizados en este orden:

   ```powershell
   kubectl apply -f azure-waf/manifests/application-load-balancer.yaml
   kubectl apply -f azure-waf/manifests/gateway-and-routes.yaml
   kubectl apply -f azure-waf/manifests/health-check-policy.yaml
   kubectl apply -f azure-waf/manifests/waf-policy-association.yaml
   ```

10. Obtener el FQDN asignado al Gateway:

   ```powershell
   kubectl get gateway securekubeops-gateway -n alb-infra -o jsonpath="{.status.addresses[0].value}"
   ```

11. Crear los registros DNS o usar cabeceras `Host` durante las pruebas:

   ```text
   juice-shop.<BASE_DOMAIN>
   app.<BASE_DOMAIN>
   ```

12. Ejecutar pruebas normales contra Juice Shop y contra la aplicacion de referencia.
13. Ejecutar ataques controlados contra Juice Shop.
14. Cambiar la politica WAF a modo `Prevention` y repetir las pruebas.
15. Guardar evidencias y eliminar los recursos WAF/Application Gateway for Containers cuando termine la validacion.

## Pruebas previstas

Trafico normal:

```powershell
$fqdn = kubectl get gateway securekubeops-gateway -n alb-infra -o jsonpath="{.status.addresses[0].value}"
Invoke-WebRequest -UseBasicParsing -Uri "http://$fqdn/" -Headers @{ Host = "juice-shop.<BASE_DOMAIN>" }
Invoke-WebRequest -UseBasicParsing -Uri "http://$fqdn/health" -Headers @{ Host = "app.<BASE_DOMAIN>" }
```

Payloads controlados:

```powershell
Invoke-WebRequest -UseBasicParsing -Uri "http://$fqdn/?q=%3Cscript%3Ealert(1)%3C%2Fscript%3E" -Headers @{ Host = "juice-shop.<BASE_DOMAIN>" }
Invoke-WebRequest -UseBasicParsing -Uri "http://$fqdn/?id=1%27%20OR%20%271%27%3D%271" -Headers @{ Host = "juice-shop.<BASE_DOMAIN>" }
Invoke-WebRequest -UseBasicParsing -Uri "http://$fqdn/../../etc/passwd" -Headers @{ Host = "juice-shop.<BASE_DOMAIN>" }
```

Resultados esperados:

- En modo `Detection`, las peticiones se registran en el WAF sin bloquear necesariamente el trafico.
- En modo `Prevention`, los payloads maliciosos deben bloquearse o generar una respuesta de denegacion.
