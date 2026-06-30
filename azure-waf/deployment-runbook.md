# Azure WAF deployment runbook

Este runbook registra los pasos operativos para desplegar, validar y eliminar la capa WAF de SecureKubeOps en AKS. La idea es poder repetir la prueba de forma controlada y borrar los recursos al terminar para limitar el consumo en Azure for Students.

## Datos del entorno

| Dato | Valor |
| --- | --- |
| Suscripcion | Azure for Students |
| Resource group | `rg-securekubeops-lab` |
| AKS | `aks-securekubeops-lab` |
| Region | `westeurope` |
| Node resource group | pendiente de variable `$NODE_RG` |
| VNet AKS | `aks-vnet-10084315` |
| Subred Application Gateway for Containers | `aks-appgateway` (`10.238.0.0/24`) |
| Namespace app referencia | `application` |
| Namespace Juice Shop | `vulnerable-lab` |

## Estado ya preparado

Aplicacion de referencia:

```powershell
kubectl apply -f k8s/application/namespace.yaml
kubectl apply -f k8s/application/deployment.yaml
kubectl apply -f k8s/application/service.yaml
kubectl get all -n application
```

Juice Shop:

```powershell
kubectl apply -k k8s/labs/juice-shop
kubectl get all -n vulnerable-lab
```

Variables de trabajo:

```powershell
$RESOURCE_GROUP="rg-securekubeops-lab"
$AKS_NAME="aks-securekubeops-lab"
$LOCATION="westeurope"
```

Workload Identity y OIDC issuer activados:

```powershell
az aks show `
  --resource-group $RESOURCE_GROUP `
  --name $AKS_NAME `
  --query "{oidc:oidcIssuerProfile.enabled, workloadIdentity:securityProfile.workloadIdentity.enabled}" `
  -o json
```

Resultado esperado:

```json
{
  "oidc": true,
  "workloadIdentity": true
}
```

Providers de Azure:

```powershell
az provider register --namespace Microsoft.ServiceNetworking
az provider register --namespace Microsoft.Network
az provider register --namespace Microsoft.ContainerService

az provider show --namespace Microsoft.ServiceNetworking --query "registrationState" -o tsv
az provider show --namespace Microsoft.Network --query "registrationState" -o tsv
az provider show --namespace Microsoft.ContainerService --query "registrationState" -o tsv
```

Resultado esperado:

```text
Registered
Registered
Registered
```

Preview features necesarias para el add-on:

```powershell
az feature register --namespace "Microsoft.ContainerService" --name "ManagedGatewayAPIPreview"
az feature register --namespace "Microsoft.ContainerService" --name "ApplicationLoadBalancerPreview"

az feature show --namespace "Microsoft.ContainerService" --name "ManagedGatewayAPIPreview" --query "properties.state" -o tsv
az feature show --namespace "Microsoft.ContainerService" --name "ApplicationLoadBalancerPreview" --query "properties.state" -o tsv
```

Resultado esperado:

```text
Registered
Registered
```

Despues de que ambas features aparezcan como `Registered`, refrescar el provider:

```powershell
az provider register --namespace Microsoft.ContainerService
```

Extensiones Azure CLI:

```powershell
az extension add --name alb --upgrade
az extension add --name aks-preview --upgrade
az extension list -o table
```

Resultado esperado:

```text
alb
aks-preview
```

## Recursos que pueden generar coste

Los pasos anteriores preparan el entorno. El gasto relevante empieza al crear recursos gestionados de entrada y WAF, especialmente:

- Application Gateway for Containers.
- Frontend y asociaciones de red.
- Azure WAF Policy asociada al trafico.
- Capacidad consumida durante las pruebas.

Por este motivo, la capa WAF se desplegara solo durante ventanas de validacion y se eliminara al terminar.

## Azure WAF Policy

Politica creada:

```powershell
$WAF_POLICY_NAME="waf-securekubeops-detection"

az network application-gateway waf-policy create `
  --resource-group $RESOURCE_GROUP `
  --name $WAF_POLICY_NAME `
  --location $LOCATION `
  --type Microsoft_DefaultRuleSet `
  --version 2.1
```

Resultado inicial:

```text
mode=Detection
state=Disabled
ruleSetType=Microsoft_DefaultRuleSet
ruleSetVersion=2.1
```

Activacion:

```powershell
az network application-gateway waf-policy policy-setting update `
  --resource-group $RESOURCE_GROUP `
  --policy-name $WAF_POLICY_NAME `
  --mode Detection `
  --state Enabled
```

Estado validado:

```text
Name                         Mode       State    ProvisioningState
waf-securekubeops-detection  Detection  Enabled  Succeeded
```

Asociacion desde Kubernetes:

```powershell
$AZURE_WAF_POLICY_RESOURCE_ID = az network application-gateway waf-policy show `
  --resource-group $RESOURCE_GROUP `
  --name $WAF_POLICY_NAME `
  --query id `
  -o tsv

(Get-Content azure-waf/manifests/waf-policy-association.template.yaml) `
  -replace '<AZURE_WAF_POLICY_RESOURCE_ID>', $AZURE_WAF_POLICY_RESOURCE_ID `
  | Set-Content azure-waf/manifests/waf-policy-association.yaml

kubectl apply -f azure-waf/manifests/waf-policy-association.yaml
```

Resultado inicial:

```text
webapplicationfirewallpolicy.alb.networking.azure.io/juice-shop-waf-policy created
webapplicationfirewallpolicy.alb.networking.azure.io/securekubeops-waf-policy created
DEPLOYMENT=False inicialmente
```

Permiso adicional necesario:

Al asociar la WAF Policy aparecio `LinkedAuthorizationFailed` porque la identidad del ALB Controller no tenia permiso para ejecutar:

```text
microsoft.network/applicationgatewaywebapplicationfirewallpolicies/join/action
```

Se concedio `Contributor` sobre la WAF Policy concreta:

```powershell
az role assignment create `
  --assignee-object-id $ALB_PRINCIPAL_ID `
  --assignee-principal-type ServicePrincipal `
  --scope $AZURE_WAF_POLICY_RESOURCE_ID `
  --role "Contributor"
```

Role assignment creado:

```text
a713342a-2b04-44bf-a7b4-2197c0db69c1
```

Reconciliacion forzada tras propagacion RBAC:

```powershell
kubectl annotate webapplicationfirewallpolicy securekubeops-waf-policy `
  -n application `
  securekubeops.io/reconcile="$(Get-Date -Format o)" `
  --overwrite

kubectl annotate webapplicationfirewallpolicy juice-shop-waf-policy `
  -n vulnerable-lab `
  securekubeops.io/reconcile="$(Get-Date -Format o)" `
  --overwrite
```

Estado validado:

```text
NAMESPACE        NAME                       DEPLOYMENT
application      securekubeops-waf-policy   True
vulnerable-lab   juice-shop-waf-policy      True
```

Prueba de trafico normal con WAF en `Detection`:

```powershell
Invoke-WebRequest `
  -UseBasicParsing `
  -Uri "http://$fqdn/health" `
  -Headers @{ Host = "app.securekubeops.local" }

Invoke-WebRequest `
  -UseBasicParsing `
  -Uri "http://$fqdn/" `
  -Headers @{ Host = "juice-shop.securekubeops.local" }
```

Resultado:

```text
app.securekubeops.local/health -> HTTP 200
juice-shop.securekubeops.local/ -> HTTP 200
```

## Red detectada

La VNet del AKS tiene el rango:

```text
10.224.0.0/12
```

Subredes relevantes:

| Subred | Rango | Delegacion |
| --- | --- | --- |
| `aks-subnet` | `10.224.0.0/16` | sin delegacion |
| `aks-appgateway` | `10.238.0.0/24` | `Microsoft.ServiceNetworking/trafficControllers` |
| `aks-virtualkubelet` | `10.239.0.0/16` | `Microsoft.ContainerInstance/containerGroups` |

La subred `aks-appgateway` ya esta delegada correctamente para Application Gateway for Containers, por lo que se usara como valor de `<ALB_SUBNET_ID>`.

## ApplicationLoadBalancer

YAML aplicado:

```powershell
kubectl apply -f azure-waf/manifests/application-load-balancer.yaml
```

Resultado:

```text
namespace/alb-infra created
applicationloadbalancer.alb.networking.azure.io/securekubeops-alb created
```

Estado inicial:

```text
Accepted=True
Deployment=True / Reason=InProgress
Azure resource: alb-e01606e4
```

Este paso crea o actualiza el recurso gestionado de Application Gateway for Containers, por lo que puede empezar a generar coste mientras este activo.

## Gateway y rutas

YAML aplicado:

```powershell
kubectl apply -f azure-waf/manifests/gateway-and-routes.yaml
```

Resultado:

```text
gateway.gateway.networking.k8s.io/securekubeops-gateway created
httproute.gateway.networking.k8s.io/juice-shop-route created
httproute.gateway.networking.k8s.io/securekubeops-route created
```

Estado inicial:

```text
Gateway securekubeops-gateway PROGRAMMED=Unknown
Accepted=Unknown / Reason=Pending / Message="Waiting for controller"
```

Rutas creadas:

| Namespace | HTTPRoute | Hostname |
| --- | --- | --- |
| `application` | `securekubeops-route` | `app.securekubeops.local` |
| `vulnerable-lab` | `juice-shop-route` | `juice-shop.securekubeops.local` |

Estado validado:

```text
Gateway securekubeops-gateway
ADDRESS=akckecdnb3fkdba6.fz84.alb.azure.com
Accepted=True
Programmed=True
Listeners: juice-shop-http y securekubeops-http
AttachedRoutes=1 en cada listener
```

Prueba inicial de trafico:

```powershell
$fqdn = "akckecdnb3fkdba6.fz84.alb.azure.com"

Invoke-WebRequest `
  -UseBasicParsing `
  -Uri "http://$fqdn/" `
  -Headers @{ Host = "juice-shop.securekubeops.local" }
```

Resultado:

```text
Juice Shop responde HTTP 200.
```

Prueba inicial de la aplicacion de referencia:

```powershell
Invoke-WebRequest `
  -UseBasicParsing `
  -Uri "http://$fqdn/health" `
  -Headers @{ Host = "app.securekubeops.local" }
```

Resultado:

```text
no healthy upstream
```

Diagnostico:

- el `Gateway` esta `Accepted=True` y `Programmed=True`;
- el `HTTPRoute` de la aplicacion esta `Accepted=True`, `ResolvedRefs=True` y `Programmed=True`;
- el Service `secure-kube-ops` tiene endpoint activo en `10.244.0.105:3000`;
- Juice Shop funciona por el mismo Gateway;
- por tanto, el problema se limita a la salud del backend de la API de referencia.

Causa probable:

La API de referencia desplegada en AKS estaba usando una imagen antigua. Antes de modificar probes o politicas, se debe comprobar que el Deployment usa el ultimo tag publicado en GHCR.

Correccion aplicada en manifiesto:

```text
ghcr.io/zinedinealvarez/secure-kube-ops:c8bb3311048aef2694adb3a5705e20916e58cff5
```

Correccion recomendada:

Mantener la ultima imagen publicada por el workflow `Publish Image` y configurar el health check del ALB para que use `/health`, que es el endpoint de salud real de la API. Para ello se define:

```text
azure-waf/manifests/health-check-policy.yaml
```

Este manifiesto crea una `HealthCheckPolicy` en el namespace `application` asociada al Service `secure-kube-ops`, con path `/health` y codigos esperados `200-299`.

Nota de validacion:

La CRD instalada no permite `spec.targetRef.sectionNames` para `HealthCheckPolicy`. Si aparece el error `SectionNamesNotPermitted`, eliminar ese campo y asociar la policy directamente al Service.

Estado validado:

```powershell
$fqdn = kubectl get gateway securekubeops-gateway -n alb-infra -o jsonpath="{.status.addresses[0].value}"

Invoke-WebRequest `
  -UseBasicParsing `
  -Uri "http://$fqdn/health" `
  -Headers @{ Host = "app.securekubeops.local" }
```

Resultado:

```text
HTTP 200
{"status":"ok"}
Server: Microsoft-Azure-Application-LB
```

## Siguiente paso pendiente

Habilitar los add-ons gestionados de Gateway API y Application Gateway for Containers en AKS:

```powershell
az aks update `
  --resource-group $RESOURCE_GROUP `
  --name $AKS_NAME `
  --enable-gateway-api `
  --enable-application-load-balancer
```

Comprobaciones esperadas:

```powershell
kubectl get pods -n kube-system | Select-String alb-controller
kubectl get gatewayclass azure-alb-external -o yaml
```

Resultado esperado:

- dos Pods `alb-controller` en estado `Running`;
- `GatewayClass` `azure-alb-external` aceptada.

Estado validado:

```text
alb-controller-cd4d8bd64-5nnfq  1/1  Running
alb-controller-cd4d8bd64-5sj4d  1/1  Running
azure-alb-external              ACCEPTED=True
```

Nota sobre identidad gestionada:

Al usar el add-on gestionado de AKS, la identidad no se llama `azure-alb-identity`. Microsoft crea una identidad en el node resource group con el patron:

```text
applicationloadbalancer-<cluster-name>
```

Para este entorno, el nombre esperado es:

```text
applicationloadbalancer-aks-securekubeops-lab
```

Comprobacion:

```powershell
az identity show `
  --resource-group $NODE_RG `
  --name "applicationloadbalancer-aks-securekubeops-lab" `
  --query "{name:name, principalId:principalId, clientId:clientId}" `
  -o json
```

Estado validado:

```json
{
  "clientId": "3ed73675-150c-4b2f-a08c-13f6ca6f3367",
  "name": "applicationloadbalancer-aks-securekubeops-lab",
  "principalId": "78a34632-8454-413a-9e3e-dfbcf55e79a9"
}
```

Permisos asignados:

```powershell
$ALB_PRINCIPAL_ID = az identity show `
  --resource-group $NODE_RG `
  --name $IDENTITY_RESOURCE_NAME `
  --query principalId `
  -o tsv

$NODE_RG_ID = az group show `
  --name $NODE_RG `
  --query id `
  -o tsv

az role assignment create `
  --assignee-object-id $ALB_PRINCIPAL_ID `
  --assignee-principal-type ServicePrincipal `
  --scope $NODE_RG_ID `
  --role "AppGW for Containers Configuration Manager"

az role assignment create `
  --assignee-object-id $ALB_PRINCIPAL_ID `
  --assignee-principal-type ServicePrincipal `
  --scope $ALB_SUBNET_ID `
  --role "Network Contributor"
```

Comando de desinstalacion del add-on si se quiere revertir esta preparacion:

```powershell
az aks update `
  --resource-group $RESOURCE_GROUP `
  --name $AKS_NAME `
  --disable-gateway-api `
  --disable-application-load-balancer
```

## Recursos a eliminar al finalizar

Pendiente de completar cuando se creen los recursos reales:

- `ApplicationLoadBalancer` en AKS.
- `Gateway`, `HTTPRoute` y `WebApplicationFirewallPolicy`.
- Azure WAF Policy.
- Recursos gestionados de Application Gateway for Containers.
- Subred dedicada si no se reutiliza.
- Permisos/identidad gestionada si se crean exclusivamente para esta prueba.

## Objetivo de validacion

1. Acceso normal a la aplicacion de referencia:

   ```text
   app.<BASE_DOMAIN>/health
   ```

2. Acceso normal a Juice Shop:

   ```text
   juice-shop.<BASE_DOMAIN>/
   ```

3. WAF en modo `Detection`: registrar ataques controlados sin bloquear necesariamente.
4. WAF en modo `Prevention`: bloquear payloads maliciosos.
5. Guardar evidencias y eliminar recursos de coste.
