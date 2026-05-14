# Dashboard del pipeline DevSecOps

Este documento define el diseño del dashboard de observabilidad del pipeline DevSecOps de SecureKubeOps. El objetivo es visualizar el estado, estabilidad, seguridad y promoción del flujo CI/CD a partir de las métricas agregadas generadas en `reports/metrics.prom`.

El dashboard se diseña sobre métricas de baja cardinalidad. No utiliza como labels commits, `run_id`, CVE, paquetes, ficheros, reglas, secretos ni mensajes de error. Los artifacts técnicos siguen siendo la fuente de detalle; el dashboard muestra tendencias y estado agregado.

## Fuente de datos

Las métricas se generan en formato Prometheus text format dentro de los artifacts de GitHub Actions. Cada workflow genera su propio archivo:

```text
reports/metrics.prom
```

El envío de estas métricas hacia Prometheus se valida manualmente mediante Pushgateway. La integración está documentada en `docs/pipeline-metrics-integration.md` y la instalación de Prometheus, Grafana y Pushgateway en `docs/observability.md`.

Las métricas disponibles son:

| Métrica | Tipo | Workflows |
| --- | --- | --- |
| `securekubeops_pipeline_execution_total` | `counter` | `Pre Analysis`, `Image Validation`, `Branch Policy`, `Publish Image` |
| `securekubeops_pipeline_control_total` | `counter` | `Pre Analysis`, `Image Validation`, `Branch Policy`, `Publish Image` |
| `securekubeops_security_findings` | `gauge` | `Pre Analysis`, `Image Validation` |
| `securekubeops_promotion_total` | `counter` | `Branch Policy`, `Publish Image` |
| `securekubeops_supply_chain_artifact` | `gauge` | `Image Validation` |

## Paneles propuestos

### Estado global de pipelines

Pregunta que responde:

¿Cuántas ejecuciones del pipeline terminan correctamente y cuántas fallan?

| Campo | Valor |
| --- | --- |
| Métrica | `securekubeops_pipeline_execution_total` |
| Tipo de panel | Stat o time series |
| Labels usados | `workflow`, `result` |
| Query PromQL | `sum by (result) (increase(securekubeops_pipeline_execution_total[30d]))` |
| Interpretación | Muestra la distribución global entre ejecuciones correctas y fallidas. |

### Ejecuciones por workflow

Pregunta que responde:

¿Qué workflows se ejecutan más y con qué resultado?

| Campo | Valor |
| --- | --- |
| Métrica | `securekubeops_pipeline_execution_total` |
| Tipo de panel | Bar chart o time series |
| Labels usados | `workflow`, `result` |
| Query PromQL | `sum by (workflow, result) (increase(securekubeops_pipeline_execution_total[30d]))` |
| Interpretación | Permite comparar la actividad de `pre_analysis`, `image_validation`, `branch_policy` y `publish_image`. |

### Tasa de éxito por workflow

Pregunta que responde:

¿Qué porcentaje de ejecuciones termina correctamente por workflow?

| Campo | Valor |
| --- | --- |
| Métrica | `securekubeops_pipeline_execution_total` |
| Tipo de panel | Gauge o stat |
| Labels usados | `workflow`, `result` |
| Query PromQL | `sum by (workflow) (increase(securekubeops_pipeline_execution_total{result="success"}[30d])) / sum by (workflow) (increase(securekubeops_pipeline_execution_total[30d])) * 100` |
| Interpretación | Muestra la estabilidad de cada workflow en porcentaje. |

### Fallos por control

Pregunta que responde:

¿Qué controles fallan más dentro del pipeline?

| Campo | Valor |
| --- | --- |
| Métrica | `securekubeops_pipeline_control_total` |
| Tipo de panel | Bar chart |
| Labels usados | `workflow`, `control`, `category`, `result` |
| Query PromQL | `sum by (workflow, control, category) (increase(securekubeops_pipeline_control_total{result="failure"}[30d]))` |
| Interpretación | Identifica controles inestables o puntos del pipeline que requieren revisión. |

### Controles omitidos

Pregunta que responde:

¿Qué controles quedan sin ejecutar por dependencias previas?

| Campo | Valor |
| --- | --- |
| Métrica | `securekubeops_pipeline_control_total` |
| Tipo de panel | Bar chart |
| Labels usados | `workflow`, `control`, `result` |
| Query PromQL | `sum by (workflow, control) (increase(securekubeops_pipeline_control_total{result="skipped"}[30d]))` |
| Interpretación | Permite ver casos donde un control no se ejecuta porque otro paso anterior no termina correctamente. |

### Vulnerabilidades de imagen por severidad

Pregunta que responde:

¿Qué severidades aparecen en el escaneo de la imagen Docker?

| Campo | Valor |
| --- | --- |
| Métrica | `securekubeops_security_findings` |
| Tipo de panel | Bar chart o stacked time series |
| Labels usados | `workflow`, `tool`, `scan_type`, `severity` |
| Query PromQL | `sum by (severity) (securekubeops_security_findings{workflow="image_validation",tool="trivy",scan_type="image"})` |
| Interpretación | Resume los hallazgos de Trivy image por severidad sin exponer CVE ni paquetes. |

### Configuración Kubernetes por severidad

Pregunta que responde:

¿Qué severidades aparecen en el escaneo de manifiestos Kubernetes?

| Campo | Valor |
| --- | --- |
| Métrica | `securekubeops_security_findings` |
| Tipo de panel | Bar chart o stacked time series |
| Labels usados | `workflow`, `tool`, `scan_type`, `severity` |
| Query PromQL | `sum by (severity) (securekubeops_security_findings{workflow="pre_analysis",tool="trivy",scan_type="config"})` |
| Interpretación | Resume los hallazgos de Trivy config sobre `k8s/` por severidad. |

### Findings SAST por severidad

Pregunta que responde:

¿Qué volumen de findings SAST detecta Semgrep por severidad?

| Campo | Valor |
| --- | --- |
| Métrica | `securekubeops_security_findings` |
| Tipo de panel | Bar chart |
| Labels usados | `workflow`, `tool`, `scan_type`, `severity` |
| Query PromQL | `sum by (severity) (securekubeops_security_findings{workflow="pre_analysis",tool="semgrep",scan_type="sast"})` |
| Interpretación | Muestra el resultado agregado del análisis estático sin exponer reglas ni rutas de ficheros. |

### Promoción de cambios

Pregunta que responde:

¿Cuántas Pull Requests cumplen la política de ramas y cuántas quedan bloqueadas?

| Campo | Valor |
| --- | --- |
| Métrica | `securekubeops_promotion_total` |
| Tipo de panel | Stat o bar chart |
| Labels usados | `stage`, `result` |
| Query PromQL | `sum by (result) (increase(securekubeops_promotion_total{stage="branch_policy"}[30d]))` |
| Interpretación | Muestra si la política `pre-* -> main` se cumple en las Pull Requests hacia `main`. |

### Publicación de imágenes

Pregunta que responde:

¿Cuántas publicaciones en GHCR terminan correctamente, fallan o quedan omitidas?

| Campo | Valor |
| --- | --- |
| Métrica | `securekubeops_promotion_total` |
| Tipo de panel | Stat o bar chart |
| Labels usados | `stage`, `result` |
| Query PromQL | `sum by (result) (increase(securekubeops_promotion_total{stage="ghcr_publish"}[30d]))` |
| Interpretación | Muestra la promoción final hacia GHCR. El resultado `skipped` indica que el push no se ejecuta por una condición previa no satisfecha. |

### Generación de SBOM

Pregunta que responde:

¿Las imágenes candidatas generan SBOM correctamente?

| Campo | Valor |
| --- | --- |
| Métrica | `securekubeops_supply_chain_artifact` |
| Tipo de panel | Stat o gauge |
| Labels usados | `workflow`, `artifact_type`, `result` |
| Query PromQL | `sum by (result) (securekubeops_supply_chain_artifact{artifact_type="sbom_cyclonedx"})` |
| Interpretación | Muestra si el artifact de cadena de suministro queda generado durante `Image Validation`. |

## Organización recomendada del dashboard

| Fila | Paneles |
| --- | --- |
| Salud general | Estado global, ejecuciones por workflow, tasa de éxito por workflow |
| Estabilidad de controles | Fallos por control, controles omitidos |
| Seguridad detectada | Vulnerabilidades de imagen, configuración Kubernetes, findings SAST |
| Promoción | Política de ramas, publicación en GHCR |
| Cadena de suministro | Generación de SBOM |

## Criterios de diseño

- Las métricas agregan resultados por workflow, control, categoría y severidad.
- Los artifacts conservan el detalle técnico completo.
- El dashboard no expone CVE, paquetes, rutas de ficheros, reglas, secretos, commits ni `run_id` como labels.
- Los paneles priorizan tendencias, estabilidad y estado agregado del flujo DevSecOps.
- Las consultas usan ventanas temporales como `[30d]` para facilitar la revisión del periodo de validación del TFG.

## Fuentes

- Prometheus documenta `counter` y `gauge` como tipos de métrica. Un `counter` representa un valor acumulativo que aumenta o se reinicia, mientras que un `gauge` representa un valor que puede subir o bajar.
- Prometheus define PromQL como el lenguaje de consulta para seleccionar y agregar series temporales.
- Grafana documenta que el editor de consultas de la fuente Prometheus permite crear consultas en PromQL.
