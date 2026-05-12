# Observabilidad en Kubernetes

Este documento describe la configuración inicial de observabilidad de SecureKubeOps en Kubernetes.

La observabilidad se plantea como una fase de la solución práctica del TFG, orientada a comprobar el estado del despliegue, los recursos del clúster y el comportamiento básico de la API de referencia desplegada en Kubernetes.

## Enfoque

Para esta fase se utiliza `kube-prometheus-stack` mediante Helm y un archivo `monitoring/values.yaml` versionado en el repositorio.

El objetivo es disponer de una configuración reproducible que pueda instalarse tanto en Minikube como en otros clústeres Kubernetes, manteniendo una configuración mínima y sin añadir componentes fuera del alcance actual.

No se añaden por ahora:

- métricas propias de la aplicación;
- endpoint `/metrics`;
- Ingress;
- Argo CD;
- WAF;
- alertas personalizadas.

## Componentes incluidos

La configuración inicial habilita:

- Prometheus;
- Grafana;
- Prometheus Operator;
- kube-state-metrics;
- node-exporter.

Alertmanager queda deshabilitado en esta fase para mantener el alcance simple, ya que todavía no se definen alertas personalizadas.

## Instalación

Añadir el repositorio de Helm:

```bash
helm repo add prometheus-community https://prometheus-community.github.io/helm-charts
helm repo update
```

Aplicar el namespace de observabilidad:

```bash
kubectl apply -f monitoring/namespace.yaml
```

Antes de instalar el chart, crear el Secret externo que utilizará Grafana para sus credenciales de administrador:

```powershell
$env:GRAFANA_ADMIN_USER="admin"
$env:GRAFANA_ADMIN_PASSWORD="TU_PASSWORD_LOCAL_NO_VERSIONADO"

kubectl create secret generic monitoring-grafana-admin `
  --namespace monitoring `
  --from-literal=admin-user=$env:GRAFANA_ADMIN_USER `
  --from-literal=admin-password=$env:GRAFANA_ADMIN_PASSWORD
```

Las contraseñas reales quedan fuera de `README.md`, `docs/` y `monitoring/values.yaml`. El Secret se crea localmente en el clúster antes de instalar Helm. El archivo `monitoring/values.yaml` solo referencia el Secret y no contiene credenciales.

Instalar `kube-prometheus-stack` fijando la versión del chart:

```bash
helm install monitoring prometheus-community/kube-prometheus-stack \
  --namespace monitoring \
  --version 84.5.0 \
  -f monitoring/values.yaml
```


## Comprobación de recursos

Comprobar los Pods del namespace de observabilidad:

```bash
kubectl get pods -n monitoring
```

Comprobar los Services:

```bash
kubectl get svc -n monitoring
```

## Acceso a Grafana

Acceder a Grafana mediante `port-forward`:

```bash
kubectl port-forward -n monitoring svc/monitoring-grafana 3000:80
```

Abrir en el navegador:

```text
http://localhost:3000
```

Usuario por defecto:

```text
admin
```

El usuario y la contraseña corresponden a los valores definidos en las variables de entorno utilizadas al crear el Secret `monitoring-grafana-admin`.

## Acceso a Prometheus

Acceder a Prometheus mediante `port-forward`:

```bash
kubectl port-forward -n monitoring svc/monitoring-kube-prometheus-prometheus 9090:9090
```

Abrir en el navegador:

```text
http://localhost:9090
```

## Métricas iniciales a observar

En esta fase no se modifica la aplicación Express ni se añade un endpoint `/metrics`.

Las métricas iniciales se centran en Kubernetes:

- estado del Pod de la API de referencia;
- reinicios del contenedor;
- uso de CPU y memoria;
- estado del Deployment;
- disponibilidad de réplicas;
- métricas del nodo Minikube;
- estado general del clúster.

## Encaje con SecureKubeOps

La API Express sigue siendo una aplicación de referencia. La observabilidad se incorpora a SecureKubeOps como parte de la solución DevSecOps completa, junto con el pipeline, los controles de seguridad, la imagen Docker publicada en GHCR y el despliegue Kubernetes.

Esta fase permite validar que el despliegue puede ser observado sin introducir todavía lógica específica de métricas dentro de la aplicación.

## Evidencias para el TFG

Como evidencias técnicas pueden utilizarse:

- `monitoring/values.yaml`;
- salida de `kubectl get pods -n monitoring`;
- salida de `kubectl get svc -n monitoring`;
- acceso a Grafana mediante `port-forward`;
- acceso a Prometheus mediante `port-forward`;
- visualización del Pod o Deployment de SecureKubeOps desde dashboards de Kubernetes.

No se requieren capturas dentro del repositorio.
