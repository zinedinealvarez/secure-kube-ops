# Evidencia de despliegue en AKS

Este documento recoge los pasos ejecutados para trasladar SecureKubeOps desde el entorno local a un cluster Azure Kubernetes Service.

El objetivo de esta fase es validar que los manifiestos Kubernetes ya versionados en el repositorio funcionan sobre AKS antes de incorporar observabilidad completa, automatizacion de metricas y WAF.

## Datos del cluster

| Campo | Valor |
| --- | --- |
| Grupo de recursos | `rg-securekubeops-lab` |
| Cluster AKS | `aks-securekubeops-lab` |
| Region | `westeurope` |
| Tier | `free` |
| Node pool | `nodepool1` |
| Tamano usado | `Standard_DS2_v2` |
| Kubernetes observado | `1.34.8` |

## Comprobacion de estado del cluster

El cluster se habia dejado parado para reducir costes. Antes de desplegar la aplicacion se arranco desde Azure y se comprobo su estado:

```powershell
az aks start `
  --resource-group rg-securekubeops-lab `
  --name aks-securekubeops-lab
```

```powershell
az aks show `
  --resource-group rg-securekubeops-lab `
  --name aks-securekubeops-lab `
  --query "powerState.code" `
  --output tsv
```

Resultado esperado:

```text
Running
```

## Conexion de kubectl con AKS

Desde la terminal local de Visual Studio Code se configuraron las credenciales del cluster:

```powershell
az aks get-credentials `
  --resource-group rg-securekubeops-lab `
  --name aks-securekubeops-lab `
  --overwrite-existing
```

Resultado observado:

```text
Merged "aks-securekubeops-lab" as current context in C:\Users\Usuario\.kube\config
```

Se comprobo el contexto activo:

```powershell
kubectl config current-context
```

Resultado observado:

```text
aks-securekubeops-lab
```

Se validaron los nodos:

```powershell
kubectl get nodes
```

Resultado observado:

```text
NAME                                STATUS   ROLES    AGE   VERSION
aks-nodepool1-10070852-vmss000001   Ready    <none>   83s   v1.34.8
```

## Secret de acceso a GHCR

La imagen de la aplicacion de referencia se encuentra en GitHub Container Registry:

```text
ghcr.io/zinedinealvarez/secure-kube-ops:0d3414a6a6aa916eb1daa21c55094c459c472e28
```

Como GHCR es un registro externo a Azure, AKS necesita un `imagePullSecret` para autenticar la descarga de la imagen privada.

Las credenciales se pasaron mediante variables de entorno locales, sin guardarlas en el repositorio:

```powershell
$env:GHCR_USERNAME="zinedinealvarez"
$env:GHCR_TOKEN="TOKEN_DE_GITHUB_CON_READ_PACKAGES"
```

Se creo el Secret de tipo Docker registry:

```powershell
kubectl create secret docker-registry ghcr-pull-secret `
  --docker-server=ghcr.io `
  --docker-username=$env:GHCR_USERNAME `
  --docker-password=$env:GHCR_TOKEN `
  --dry-run=client `
  -o yaml | kubectl apply -f -
```

Resultado observado:

```text
secret/ghcr-pull-secret created
```

Se comprobo el Secret:

```powershell
kubectl get secret ghcr-pull-secret
```

Resultado observado:

```text
NAME               TYPE                             DATA   AGE
ghcr-pull-secret   kubernetes.io/dockerconfigjson   1      69s
```

## Despliegue de la aplicacion de referencia

La aplicacion propia de SecureKubeOps es una API Node/Express sencilla usada para validar el flujo DevSecOps: construccion, analisis, publicacion de imagen y despliegue en Kubernetes.

Se aplicaron los manifiestos:

```powershell
kubectl apply -f k8s/deployment.yaml
kubectl apply -f k8s/service.yaml
```

Resultado observado:

```text
deployment.apps/secure-kube-ops created
service/secure-kube-ops created
```

Inicialmente el Pod quedo en error de descarga de imagen:

```powershell
kubectl get pods
```

Resultado observado:

```text
NAME                               READY   STATUS             RESTARTS   AGE
secure-kube-ops-6999546646-mwwwx   0/1     ImagePullBackOff   0          43s
```

Se revisaron los eventos del Pod:

```powershell
kubectl describe pod secure-kube-ops-6999546646-mwwwx
```

Error relevante:

```text
failed to authorize: failed to fetch oauth token
unexpected status from GET request to https://ghcr.io/token?...: 403 Forbidden
```

El error indicaba que AKS llegaba a GHCR, pero GHCR rechazaba las credenciales. Se verifico el token localmente:

```powershell
$env:GHCR_TOKEN | docker login ghcr.io -u zinedinealvarez --password-stdin
```

El primer intento devolvio:

```text
denied: denied
```

Se genero o sustituyo el token por uno valido de GitHub con permiso de lectura de paquetes y se recreo el Secret `ghcr-pull-secret`. Despues se reinicio el Deployment:

```powershell
kubectl rollout restart deployment secure-kube-ops
```

Resultado observado:

```text
deployment.apps/secure-kube-ops restarted
```

Se comprobo el estado:

```powershell
kubectl get pods
```

Resultado observado:

```text
NAME                               READY   STATUS    RESTARTS   AGE
secure-kube-ops-5d5d68d4c6-4sxjt   1/1     Running   0          44s
```

Con esto se valido que AKS podia descargar la imagen desde GHCR usando el `imagePullSecret`.

## Despliegue de OWASP Juice Shop

OWASP Juice Shop se despliega como aplicacion vulnerable de laboratorio en el namespace `vulnerable-lab`.

Se aplicaron los manifiestos con Kustomize:

```powershell
kubectl apply -k k8s/juice-shop
```

Se comprobaron los recursos:

```powershell
kubectl get all -n vulnerable-lab
```

Resultado observado inicialmente:

```text
namespace/vulnerable-lab created
service/juice-shop created
deployment.apps/juice-shop created

NAME                              READY   STATUS              RESTARTS   AGE
pod/juice-shop-5d489796f5-7lv77   0/1     ContainerCreating   0          1s

NAME                 TYPE        CLUSTER-IP    EXTERNAL-IP   PORT(S)    AGE
service/juice-shop   ClusterIP   10.0.161.17   <none>        3000/TCP   1s

NAME                         READY   UP-TO-DATE   AVAILABLE   AGE
deployment.apps/juice-shop   0/1     1            0           1s
```

Tras esperar a que la imagen se descargase y el contenedor arrancase, se valido que Juice Shop funcionaba correctamente mediante `port-forward`.

Comando de acceso local:

```powershell
kubectl port-forward -n vulnerable-lab service/juice-shop 3001:3000
```

URL de validacion:

```text
http://localhost:3001
```

## Observabilidad con Prometheus y Grafana

Se instalo la base de observabilidad en el namespace `monitoring` usando el chart `kube-prometheus-stack` y los valores versionados en `monitoring/values.yaml`.

Antes de instalar el chart se creo un Secret para las credenciales de administrador de Grafana. La contrasena no se guarda en el repositorio:

```powershell
$env:GRAFANA_ADMIN_USER="admin"
$env:GRAFANA_ADMIN_PASSWORD="PASSWORD_LOCAL_NO_VERSIONADO"
```

```powershell
kubectl create secret generic monitoring-grafana-admin `
  --namespace monitoring `
  --from-literal=admin-user=$env:GRAFANA_ADMIN_USER `
  --from-literal=admin-password=$env:GRAFANA_ADMIN_PASSWORD `
  --dry-run=client `
  -o yaml | kubectl apply -f -
```

Se actualizo el repositorio Helm de Prometheus Community:

```powershell
helm repo add prometheus-community https://prometheus-community.github.io/helm-charts
helm repo update
```

Se instalo `kube-prometheus-stack`:

```powershell
helm upgrade --install monitoring prometheus-community/kube-prometheus-stack `
  --namespace monitoring `
  --version 84.5.0 `
  -f monitoring/values.yaml
```

Resultado observado:

```text
Release "monitoring" does not exist. Installing it now.
STATUS: deployed
DESCRIPTION: Install complete
```

Se comprobaron los Pods del namespace `monitoring`:

```powershell
kubectl get pods -n monitoring
```

Resultado observado:

```text
NAME                                                   READY   STATUS    RESTARTS   AGE
monitoring-grafana-b5ff6544f-c6m2z                     3/3     Running   0          27m
monitoring-kube-prometheus-operator-7fdc7f994c-494tk   1/1     Running   0          27m
monitoring-kube-state-metrics-676c88cc4-4mpgl          1/1     Running   0          27m
monitoring-prometheus-node-exporter-9zckn              1/1     Running   0          27m
prometheus-monitoring-kube-prometheus-prometheus-0     2/2     Running   0          27m
```

Se comprobaron los volumenes persistentes:

```powershell
kubectl get pvc -n monitoring
```

Resultado observado:

```text
NAME                                                                                                     STATUS   CAPACITY   ACCESS MODES   STORAGECLASS
monitoring-grafana                                                                                       Bound    1Gi        RWO            default
prometheus-monitoring-kube-prometheus-prometheus-db-prometheus-monitoring-kube-prometheus-prometheus-0   Bound    5Gi        RWO            default
```

Se comprobaron los Services:

```powershell
kubectl get svc -n monitoring
```

Resultado observado:

```text
NAME                                    TYPE        CLUSTER-IP     EXTERNAL-IP   PORT(S)
monitoring-grafana                      ClusterIP   10.0.238.176   <none>        80/TCP
monitoring-kube-prometheus-operator     ClusterIP   10.0.149.244   <none>        443/TCP
monitoring-kube-prometheus-prometheus   ClusterIP   10.0.36.56     <none>        9090/TCP,8080/TCP
monitoring-kube-state-metrics           ClusterIP   10.0.14.225    <none>        8080/TCP
monitoring-prometheus-node-exporter     ClusterIP   10.0.211.239   <none>        9100/TCP
prometheus-operated                     ClusterIP   None           <none>        9090/TCP
```

Se aplicaron los dashboards propios de SecureKubeOps:

```powershell
kubectl apply -f monitoring/grafana-dashboard-securekubeops-pipeline.yaml
kubectl apply -f monitoring/grafana-dashboard-securekubeops-cluster-overview.yaml
```

## Pushgateway interno para metricas del pipeline

Pushgateway se despliega como componente interno para recibir metricas de jobs efimeros, como los workflows de GitHub Actions. El Service se mantiene como `ClusterIP`, sin `Ingress` ni `LoadBalancer`, por lo que no queda expuesto publicamente.

La configuracion versionada se encuentra en:

```text
monitoring/pushgateway-values.yaml
monitoring/pushgateway-servicemonitor.yaml
```

Se instalo Pushgateway con Helm:

```powershell
helm upgrade --install pushgateway prometheus-community/prometheus-pushgateway `
  --namespace monitoring `
  --version 3.6.0 `
  -f monitoring/pushgateway-values.yaml
```

Se aplico el `ServiceMonitor` para que Prometheus scrapee Pushgateway:

```powershell
kubectl apply -f monitoring/pushgateway-servicemonitor.yaml
```

Se valido con una metrica de prueba usando `port-forward` local:

```powershell
kubectl port-forward -n monitoring svc/pushgateway 9091:9091
```

Desde otra terminal:

```powershell
$body = "securekubeops_pipeline_test_metric 1`n"
Invoke-WebRequest -UseBasicParsing `
  -Uri http://localhost:9091/metrics/job/securekubeops-test `
  -Method Post `
  -Body $body `
  -ContentType "text/plain"
```

Se comprobo que la metrica estaba disponible en Pushgateway:

```powershell
(Invoke-WebRequest -UseBasicParsing -Uri http://localhost:9091/metrics).Content | Select-String "securekubeops_pipeline_test_metric"
```

Despues se comprobo en Prometheus mediante la consulta:

```promql
securekubeops_pipeline_test_metric
```

La misma metrica aparecio tambien en Grafana, validando la cadena:

```text
Pushgateway -> Prometheus -> Grafana
```

### Evidencia final de observabilidad

Se ejecuto una comprobacion conjunta del namespace `monitoring`:

```powershell
kubectl get pods -n monitoring
kubectl get svc -n monitoring
kubectl get servicemonitor -n monitoring
kubectl get pvc -n monitoring
```

Resultado observado:

```text
NAME                                                   READY   STATUS    RESTARTS   AGE
monitoring-grafana-b5ff6544f-x9brr                     3/3     Running   0          40h
monitoring-kube-prometheus-operator-7fdc7f994c-jgn2m   1/1     Running   0          40h
monitoring-kube-state-metrics-676c88cc4-728ch          1/1     Running   0          40h
monitoring-prometheus-node-exporter-vqfmh              1/1     Running   0          18m
prometheus-monitoring-kube-prometheus-prometheus-0     2/2     Running   0          40h
pushgateway-758745bd7f-fjwlj                           1/1     Running   0          15m

NAME                                    TYPE        CLUSTER-IP     EXTERNAL-IP   PORT(S)             AGE
monitoring-grafana                      ClusterIP   10.0.238.176   <none>        80/TCP              42h
monitoring-kube-prometheus-operator     ClusterIP   10.0.149.244   <none>        443/TCP             42h
monitoring-kube-prometheus-prometheus   ClusterIP   10.0.36.56     <none>        9090/TCP,8080/TCP   42h
monitoring-kube-state-metrics           ClusterIP   10.0.14.225    <none>        8080/TCP            42h
monitoring-prometheus-node-exporter     ClusterIP   10.0.211.239   <none>        9100/TCP            42h
prometheus-operated                     ClusterIP   None           <none>        9090/TCP            42h
pushgateway                             ClusterIP   10.0.108.58    <none>        9091/TCP            15m

NAME                                                 AGE
monitoring-grafana                                   42h
monitoring-kube-prometheus-apiserver                 42h
monitoring-kube-prometheus-coredns                   42h
monitoring-kube-prometheus-kube-controller-manager   42h
monitoring-kube-prometheus-kube-etcd                 42h
monitoring-kube-prometheus-kube-proxy                42h
monitoring-kube-prometheus-kube-scheduler            42h
monitoring-kube-prometheus-kubelet                   42h
monitoring-kube-prometheus-operator                  42h
monitoring-kube-prometheus-prometheus                42h
monitoring-kube-state-metrics                        42h
monitoring-prometheus-node-exporter                  42h
pushgateway                                          14m
trivy-operator                                       11s

NAME                                                                                                     STATUS   VOLUME                                     CAPACITY   ACCESS MODES   STORAGECLASS
monitoring-grafana                                                                                       Bound    pvc-50099564-d2c6-45bd-8903-a55c45f418ca   1Gi        RWO            default
prometheus-monitoring-kube-prometheus-prometheus-db-prometheus-monitoring-kube-prometheus-prometheus-0   Bound    pvc-d8585e41-3681-453b-8080-358357996898   5Gi        RWO            default
```

Esta salida confirma que Pushgateway se mantiene como `ClusterIP`, que Prometheus dispone del `ServiceMonitor` correspondiente y que la persistencia de Prometheus y Grafana esta ligada mediante PVC.

## Seguridad runtime con Trivy Operator

Trivy Operator se despliega en modo observacion para generar reports y metricas de seguridad runtime sin bloquear workloads ni modificar el flujo de despliegue. La configuracion versionada se encuentra en:

```text
runtime-security/trivy-operator/namespace.yaml
runtime-security/trivy-operator/values.yaml
```

La configuracion habilita escaneo de vulnerabilidades, configuracion, secretos expuestos, RBAC e infraestructura, y crea un `ServiceMonitor` en el namespace `monitoring` para que Prometheus scrapee sus metricas.

Comandos de instalacion:

```powershell
kubectl apply -f runtime-security/trivy-operator/namespace.yaml
```

```powershell
helm repo add aqua https://aquasecurity.github.io/helm-charts/
helm repo update
```

```powershell
helm upgrade --install trivy-operator aqua/trivy-operator `
  --namespace runtime-security `
  --version 0.32.1 `
  -f runtime-security/trivy-operator/values.yaml
```

Se comprobo el estado de los Pods:

```powershell
kubectl get pods -n runtime-security
```

Resultado observado:

```text
NAME                                        READY   STATUS      RESTARTS   AGE
scan-vulnerabilityreport-74b6d5f4b4-pmc8h   0/1     Completed   0          75s
scan-vulnerabilityreport-c4f9f7746-wmbm4    0/1     Completed   0          74s
trivy-operator-85747d47d5-wvgs7             1/1     Running     0          80s
```

Se comprobo la release Helm:

```powershell
helm list -n runtime-security
```

Resultado observado:

```text
NAME            NAMESPACE          REVISION   STATUS     CHART                   APP VERSION
trivy-operator  runtime-security   1          deployed   trivy-operator-0.32.1   0.30.1
```

Se comprobaron los recursos del namespace:

```powershell
kubectl get all -n runtime-security
```

Resultado observado:

```text
NAME                                            READY   STATUS      RESTARTS   AGE
pod/scan-vulnerabilityreport-74b6d5f4b4-pmc8h   0/1     Completed   0          81s
pod/scan-vulnerabilityreport-c4f9f7746-wmbm4    0/1     Completed   0          80s
pod/trivy-operator-85747d47d5-wvgs7             1/1     Running     0          86s

NAME                     TYPE        CLUSTER-IP   EXTERNAL-IP   PORT(S)   AGE
service/trivy-operator   ClusterIP   None         <none>        80/TCP    86s

NAME                             READY   UP-TO-DATE   AVAILABLE   AGE
deployment.apps/trivy-operator   1/1     1            1           86s

NAME                                        DESIRED   CURRENT   READY   AGE
replicaset.apps/trivy-operator-85747d47d5   1         1         1       86s

NAME                                            STATUS     COMPLETIONS   DURATION   AGE
job.batch/scan-vulnerabilityreport-74b6d5f4b4   Complete   1/1           37s        81s
job.batch/scan-vulnerabilityreport-c4f9f7746    Complete   1/1           28s        80s
```

La salida confirma que el operador queda activo y que los Jobs iniciales de escaneo de vulnerabilidades han completado correctamente.

### Reports generados por Trivy Operator

Se comprobaron los reports creados por Trivy Operator en los namespaces monitorizados.

VulnerabilityReports:

```powershell
kubectl get vulnerabilityreports -A
```

Resultado observado:

```text
NAMESPACE   NAME                                                        REPOSITORY                        TAG                                        SCANNER   AGE
default     replicaset-secure-kube-ops-5d5d68d4c6-secure-kube-ops-api   zinedinealvarez/secure-kube-ops   0d3414a6a6aa916eb1daa21c55094c459c472e28   Trivy     101s
```

ConfigAuditReports:

```powershell
kubectl get configauditreports -A
```

Resultado observado:

```text
NAMESPACE        NAME                                    SCANNER   AGE
default          replicaset-secure-kube-ops-5d5d68d4c6   Trivy     2m20s
default          service-kubernetes                      Trivy     2m20s
default          service-secure-kube-ops                 Trivy     2m20s
vulnerable-lab   replicaset-juice-shop-5d489796f5        Trivy     2m20s
vulnerable-lab   service-juice-shop                      Trivy     2m20s
```

ExposedSecretReports:

```powershell
kubectl get exposedsecretreports -A
```

Resultado observado:

```text
NAMESPACE   NAME                                                        REPOSITORY                        TAG                                        SCANNER   AGE
default     replicaset-secure-kube-ops-5d5d68d4c6-secure-kube-ops-api   zinedinealvarez/secure-kube-ops   0d3414a6a6aa916eb1daa21c55094c459c472e28   Trivy     105s
```

RBACAssessmentReports e InfraAssessmentReports:

```powershell
kubectl get rbacassessmentreports -A
kubectl get infraassessmentreports -A
```

Resultado observado:

```text
No resources found
No resources found
```

Esta salida indica que la fase runtime ya genera reports sobre workloads desplegados. En este estado aparecen reports de vulnerabilidades, auditoria de configuracion y secretos expuestos, mientras que RBAC e infraestructura no presentan recursos reportados.

### Validacion de metricas y dashboard de Trivy

Se valido en Prometheus/Grafana que las metricas de Trivy Operator estaban disponibles mediante consultas PromQL como:

```promql
trivy_image_vulnerabilities
```

```promql
trivy_resource_configaudits
```

```promql
trivy_image_exposedsecrets
```

Tambien se comprobaron agregaciones por severidad y namespace:

```promql
sum by (severity) (trivy_image_vulnerabilities)
```

```promql
sum by (namespace, severity) (trivy_resource_configaudits)
```

Las metricas aparecieron correctamente en Prometheus/Grafana.

Se aplico el dashboard versionado de Trivy Operator:

```powershell
kubectl apply --server-side -f monitoring/grafana-dashboard-trivy-operator.yaml
```

Con esto queda validada la cadena:

```text
Trivy Operator reports -> metricas -> Prometheus -> Grafana
```

## Self-hosted runner en AKS con Actions Runner Controller

Para automatizar el envio futuro de metricas del pipeline a Pushgateway sin exponer Pushgateway publicamente, se desplego Actions Runner Controller (ARC) en AKS.

La arquitectura validada es:

```text
GitHub Actions -> ARC listener -> runner efimero en AKS
```

El objetivo posterior es ampliar esta cadena para enviar `reports/metrics.prom` desde el runner efimero hacia el Service interno de Pushgateway:

```text
GitHub Actions -> runner en AKS -> Pushgateway ClusterIP -> Prometheus -> Grafana
```

### Instalacion del controller

Primero se limpiaron credenciales locales erroneas de GHCR que impedian a Helm descargar el chart OCI de ARC:

```powershell
docker logout ghcr.io
helm registry logout ghcr.io
```

Se instalo el controller de ARC:

```powershell
helm install arc `
  --namespace arc-systems `
  --create-namespace `
  oci://ghcr.io/actions/actions-runner-controller-charts/gha-runner-scale-set-controller
```

Resultado observado:

```text
Pulled: ghcr.io/actions/actions-runner-controller-charts/gha-runner-scale-set-controller:0.14.2
NAME: arc
NAMESPACE: arc-systems
STATUS: deployed
DESCRIPTION: Install complete
```

Se comprobo el controller:

```powershell
kubectl get pods -n arc-systems
```

Resultado observado tras completar la configuracion:

```text
NAME                                    READY   STATUS    RESTARTS   AGE
arc-gha-rs-controller-f6b864554-sj59p   1/1     Running   0          11m
securekubeops-aks-f998cb8f-listener     1/1     Running   0          3m8s
```

### Token y Secret de ARC

Se creo un token de GitHub limitado al repositorio `zinedinealvarez/secure-kube-ops` con permiso de administracion de repositorio en lectura y escritura, necesario para registrar self-hosted runners.

El token no se guarda en el repositorio. Se paso mediante variable local:

```powershell
$env:GITHUB_ARC_TOKEN="TOKEN_DE_GITHUB_NO_VERSIONADO"
```

Se creo el namespace de runners y el Secret:

```powershell
kubectl create namespace arc-runners
```

```powershell
kubectl create secret generic arc-github-token `
  --namespace arc-runners `
  --from-literal=github_token=$env:GITHUB_ARC_TOKEN
```

### Runner scale set

Se instalo el runner scale set con el nombre `securekubeops-aks`. Este nombre se usa despues como valor de `runs-on` en GitHub Actions:

```powershell
helm install securekubeops-aks `
  --namespace arc-runners `
  --set githubConfigUrl="https://github.com/zinedinealvarez/secure-kube-ops" `
  --set githubConfigSecret=arc-github-token `
  oci://ghcr.io/actions/actions-runner-controller-charts/gha-runner-scale-set
```

Inicialmente se habia usado una URL de repositorio incorrecta. El controller devolvia errores `404 Not Found` al registrar el runner scale set:

```text
POST https://api.github.com/actions/runner-registration failed(status="404 Not Found")
```

Se corrigio el valor `githubConfigUrl` para apuntar al repositorio real:

```powershell
helm upgrade securekubeops-aks `
  --namespace arc-runners `
  --set githubConfigUrl="https://github.com/zinedinealvarez/secure-kube-ops" `
  --set githubConfigSecret=arc-github-token `
  oci://ghcr.io/actions/actions-runner-controller-charts/gha-runner-scale-set
```

Los logs del controller confirmaron que el runner scale set se creo o reutilizo correctamente:

```text
Created/Reused a runner scale set
Created a new EphemeralRunnerSet resource
Creating a new AutoscalingListener
Created listener pod
```

Se comprobaron los recursos:

```powershell
kubectl get autoscalingrunnersets -n arc-runners
kubectl get ephemeralrunnersets -n arc-runners
```

Resultado observado:

```text
NAME                MINIMUM RUNNERS   MAXIMUM RUNNERS   CURRENT RUNNERS   STATE   PENDING RUNNERS   RUNNING RUNNERS   FINISHED RUNNERS   DELETING RUNNERS
securekubeops-aks

NAME                      DESIREDREPLICAS   CURRENTREPLICAS   PENDING RUNNERS   RUNNING RUNNERS   FINISHED RUNNERS   DELETING RUNNERS
securekubeops-aks-7qx76                     0
```

El valor `0` es esperado mientras no haya jobs pendientes, porque ARC crea runners efimeros bajo demanda.

### Workflow de prueba

Se creo un workflow manual para validar que GitHub Actions puede ejecutar jobs dentro de AKS:

```text
.github/workflows/arc-runner-test.yml
```

Contenido relevante:

```yaml
name: ARC Runner Test

on:
  workflow_dispatch:

jobs:
  test-runner:
    name: Test AKS self-hosted runner
    runs-on: securekubeops-aks

    steps:
      - name: Show runner context
        run: |
          echo "Runner is working inside AKS"
          hostname
```

Se lanzo manualmente desde GitHub Actions contra `main`. Durante la ejecucion, ARC creo un runner efimero en el namespace `arc-runners`:

```powershell
kubectl get pods -n arc-runners -w
```

Resultado observado:

```text
NAME                                   READY   STATUS              RESTARTS   AGE
securekubeops-aks-7qx76-runner-g74st   0/1     Pending             0          0s
securekubeops-aks-7qx76-runner-g74st   0/1     ContainerCreating   0          0s
securekubeops-aks-7qx76-runner-g74st   1/1     Running             0          33s
securekubeops-aks-7qx76-runner-g74st   0/1     Completed           0          43s
securekubeops-aks-7qx76-runner-g74st   0/1     Terminating         0          43s
```

El workflow termino en GitHub Actions con estado `Success` y una duracion aproximada de 46 segundos.

Con esta prueba queda validada la cadena:

```text
GitHub Actions -> ARC -> runner efimero en AKS -> job completado
```

## Estado alcanzado

En este punto ya se ha trasladado a AKS la parte base de SecureKubeOps:

- cluster AKS arrancado y accesible desde `kubectl`;
- `imagePullSecret` creado para descargar imagenes desde GHCR;
- aplicacion de referencia desplegada y en estado `Running`;
- OWASP Juice Shop desplegado en namespace independiente y validado por `port-forward`.
- observabilidad base con Prometheus, Grafana, `kube-state-metrics` y `node-exporter`;
- persistencia de Prometheus y Grafana mediante PVC en AKS;
- Pushgateway interno instalado y scrapeado por Prometheus;
- metrica de prueba visible en Prometheus y Grafana.
- Trivy Operator desplegado en modo observacion;
- Jobs iniciales de escaneo de vulnerabilidades completados.
- reports de vulnerabilidades, configuracion y secretos expuestos generados por Trivy Operator.
- metricas de Trivy visibles en Prometheus/Grafana;
- dashboard de Trivy Operator aplicado en Grafana.
- Actions Runner Controller desplegado en AKS;
- runner scale set `securekubeops-aks` registrado en GitHub;
- workflow manual ejecutado correctamente sobre runner efimero dentro de AKS.

Quedan para las siguientes fases:

- automatizacion del envio de `reports/metrics.prom` desde GitHub Actions hacia Pushgateway interno;
- Azure Application Gateway WAF delante del cluster.

## Referencias

- Microsoft Learn: AKS puede integrarse directamente con ACR, pero para registros privados externos se usa `imagePullSecret`.
- Kubernetes: `imagePullSecrets` es el mecanismo estandar para descargar imagenes desde registros privados.
- GitHub Docs: GHCR requiere autenticacion con token para descargar imagenes privadas, usando al menos `read:packages`.
- Kubernetes: `ClusterIP` expone un Service solo dentro del cluster.
- Prometheus: Pushgateway se recomienda solo para casos limitados, como jobs efimeros que no pueden ser scrapeados directamente.
- GitHub Docs: self-hosted runners y Actions Runner Controller permiten ejecutar jobs de GitHub Actions en infraestructura propia, incluyendo Kubernetes.
