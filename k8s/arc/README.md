# Actions Runner Controller en AKS

Esta carpeta localiza la parte de Actions Runner Controller (ARC) dentro del bloque Kubernetes de SecureKubeOps.

ARC permite ejecutar jobs de GitHub Actions dentro de AKS. En este proyecto se usa para el job final `Push Pipeline Metrics`, que descarga el artifact `metrics.prom` generado por el workflow y lo envia al Pushgateway interno del cluster.

## Por que no hay manifiestos YAML propios

La instalacion de ARC se realiza mediante charts Helm OCI oficiales de GitHub:

- `gha-runner-scale-set-controller`;
- `gha-runner-scale-set`.

Por este motivo, el repositorio no versiona los manifiestos Kubernetes generados por Helm. Se versiona la documentacion operativa y la evidencia de instalacion.

## Namespaces usados

| Namespace | Uso |
| --- | --- |
| `arc-systems` | Controller de ARC y listener asociado al runner scale set. |
| `arc-runners` | Runners efimeros creados bajo demanda. |

## Relacion con el pipeline

Los workflows principales ejecutan analisis y construccion en runners de GitHub (`ubuntu-latest`). Solo el envio de metricas se ejecuta en AKS:

```text
GitHub Actions -> artifact metrics.prom -> ARC runner en AKS -> Pushgateway ClusterIP -> Prometheus -> Grafana
```

Esto permite enviar metricas a Pushgateway sin exponerlo publicamente.

Los workflows usan el label:

```yaml
runs-on: securekubeops-aks
```

Ese nombre coincide con el runner scale set instalado mediante Helm.

## Documentacion relacionada

La instalacion y validacion de ARC se describe en:

```text
docs/deployment/aks-deployment-evidence.md
```
