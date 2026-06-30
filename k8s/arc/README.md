# Actions Runner Controller en AKS

Esta carpeta localiza la parte de Actions Runner Controller (ARC) dentro del bloque Kubernetes de SecureKubeOps.

ARC se utiliza para ejecutar jobs de GitHub Actions dentro de AKS. En este proyecto se usa para el job final `push-pipeline-metrics`, que descarga el artifact `metrics.prom` generado por el workflow y lo envía al Pushgateway interno del clúster.

## Por qué no hay manifiestos YAML propios

La instalación de ARC se realizó mediante charts Helm OCI oficiales de GitHub:

- `gha-runner-scale-set-controller`;
- `gha-runner-scale-set`.

Por ese motivo, el repositorio no versiona manifiestos Kubernetes generados por Helm. Lo que se versiona es la documentación operativa y las evidencias de instalación.

## Namespaces usados

| Namespace | Uso |
| --- | --- |
| `arc-systems` | Controller de ARC. |
| `arc-runners` | Listener y runners efímeros creados bajo demanda. |

## Relación con el pipeline

Los workflows principales siguen ejecutando análisis y construcción en runners de GitHub. Solo el envío de métricas se ejecuta en AKS:

```text
GitHub Actions -> artifact metrics.prom -> ARC runner en AKS -> Pushgateway ClusterIP -> Prometheus -> Grafana
```

Esto evita exponer Pushgateway públicamente.

## Evidencia y comandos

La instalación y validación de ARC se documenta en:

```text
docs/deployment/aks-deployment-evidence.md
```

Los workflows usan el label:

```yaml
runs-on: securekubeops-aks
```
