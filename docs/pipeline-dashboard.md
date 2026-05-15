# Dashboard del pipeline DevSecOps

Este documento define los paneles de Grafana para visualizar el estado, estabilidad, seguridad y promoción del flujo DevSecOps de SecureKubeOps a partir de las métricas generadas en `reports/metrics.prom`.

Las métricas se generan dentro de los artifacts de GitHub Actions, se envían manualmente a Pushgateway y Prometheus las obtiene mediante scraping. La instalación de Prometheus, Grafana y Pushgateway se documenta en `docs/observability.md`, y el envío manual de `metrics.prom` se documenta en `docs/pipeline-metrics-integration.md`.

## Métricas disponibles

| Métrica | Tipo | Workflows | Uso principal |
| --- | --- | --- | --- |
| `securekubeops_pipeline_execution_total` | `counter` | `Pre Analysis`, `Image Validation`, `Branch Policy`, `Publish Image` | Estado global de workflows. |
| `securekubeops_pipeline_control_total` | `counter` | `Pre Analysis`, `Image Validation`, `Branch Policy`, `Publish Image` | Resultado de controles individuales. |
| `securekubeops_security_finding_info` | `gauge` | `Pre Analysis`, `Image Validation` | Hallazgos de seguridad enriquecidos. |
| `securekubeops_promotion_total` | `counter` | `Branch Policy`, `Publish Image` | Promoción hacia `main` y GHCR. |
| `securekubeops_supply_chain_artifact` | `gauge` | `Image Validation` | Generación del SBOM CycloneDX. |

Todas las métricas incluyen el label `time` con la fecha de generación de la métrica en formato UTC, por ejemplo `2026-05-14T12:30:00Z`.

## Paneles recomendados

### 1. Estado global del pipeline

| Campo | Valor |
| --- | --- |
| Pregunta | ¿Cuántas ejecuciones terminan en éxito o fallo? |
| Tipo de panel | Stat |
| Query | `sum by (result) (securekubeops_pipeline_execution_total)` |
| Visualización | Un Stat por resultado (`success`, `failure`). |
| Labels clave | `result` |

### 2. Ejecuciones por workflow

| Campo | Valor |
| --- | --- |
| Pregunta | ¿Qué workflows se ejecutan y con qué resultado? |
| Tipo de panel | Bar chart |
| Query | `sum by (workflow, result) (securekubeops_pipeline_execution_total)` |
| Visualización | Barras agrupadas por `workflow` y coloreadas por `result`. |
| Labels clave | `workflow`, `result` |

### 3. Resultado por control

| Campo | Valor |
| --- | --- |
| Pregunta | ¿Qué controles pasan, fallan o quedan omitidos? |
| Tipo de panel | Bar chart |
| Query | `sum by (workflow, control, result) (securekubeops_pipeline_control_total)` |
| Visualización | Barras por control y resultado. |
| Labels clave | `workflow`, `control`, `result` |

### 4. Fallos por categoría de control

| Campo | Valor |
| --- | --- |
| Pregunta | ¿Qué área del pipeline concentra más fallos? |
| Tipo de panel | Bar chart |
| Query | `sum by (category, result) (securekubeops_pipeline_control_total{result="failure"})` |
| Visualización | Barras por categoría (`secret_detection`, `sast`, `iac_scan`, `image_scan`, `registry_publish`). |
| Labels clave | `category`, `result` |

### 5. Secretos detectados

| Campo | Valor |
| --- | --- |
| Pregunta | ¿GitLeaks ha detectado secretos potenciales? |
| Tipo de panel | Stat |
| Query | `sum(securekubeops_security_finding_info{tool="gitleaks",scan_type="secret_detection"})` |
| Visualización | Número total de secretos detectados. |
| Labels clave | `tool`, `scan_type`, `severity` |

La métrica de GitLeaks solo exporta el número de secretos detectados. No exporta el valor del secreto, fichero, línea, commit, autor ni fingerprint.

### 6. Hallazgos por herramienta y severidad

| Campo | Valor |
| --- | --- |
| Pregunta | ¿Qué herramientas generan más hallazgos y con qué severidad? |
| Tipo de panel | Stacked bar chart |
| Query | `sum by (tool, scan_type, severity) (securekubeops_security_finding_info)` |
| Visualización | Barras apiladas por herramienta y severidad. |
| Labels clave | `tool`, `scan_type`, `severity` |

### 7. Vulnerabilidades de imagen por CVE

| Campo | Valor |
| --- | --- |
| Pregunta | ¿Qué CVE aparecen en la imagen Docker candidata? |
| Tipo de panel | Table |
| Query | `sum by (id, severity, title, description, time) (securekubeops_security_finding_info{tool="trivy",scan_type="image"})` |
| Visualización | Tabla con `id`, `severity`, `title`, `description` y `time`. |
| Labels clave | `id`, `severity`, `title`, `description`, `time` |

### 8. Misconfigurations Kubernetes por ID

| Campo | Valor |
| --- | --- |
| Pregunta | ¿Qué problemas detecta Trivy config en los manifiestos Kubernetes? |
| Tipo de panel | Table |
| Query | `sum by (id, severity, title, description, time) (securekubeops_security_finding_info{tool="trivy",scan_type="config"})` |
| Visualización | Tabla de IDs de Trivy config, severidad y descripción. |
| Labels clave | `id`, `severity`, `title`, `description`, `time` |

### 9. Findings SAST por CWE

| Campo | Valor |
| --- | --- |
| Pregunta | ¿Qué categorías CWE aparecen en el análisis estático? |
| Tipo de panel | Bar chart |
| Query | `sum by (cwe, severity) (securekubeops_security_finding_info{tool="semgrep",scan_type="sast"})` |
| Visualización | Barras por CWE y severidad. |
| Labels clave | `cwe`, `severity` |

### 10. Findings SAST detallados

| Campo | Valor |
| --- | --- |
| Pregunta | ¿Qué reglas SAST han generado findings? |
| Tipo de panel | Table |
| Query | `sum by (id, severity, title, description, cwe, owasp, confidence, impact, likelihood, time) (securekubeops_security_finding_info{tool="semgrep",scan_type="sast"})` |
| Visualización | Tabla con regla, severidad, clase de vulnerabilidad, CWE, OWASP e información de confianza. |
| Labels clave | `id`, `severity`, `title`, `description`, `cwe`, `owasp`, `confidence`, `impact`, `likelihood`, `time` |

### 11. Pull Requests permitidas o bloqueadas

| Campo | Valor |
| --- | --- |
| Pregunta | ¿La política de ramas permite o bloquea las Pull Requests hacia `main`? |
| Tipo de panel | Stat o bar chart |
| Query | `sum by (result) (securekubeops_promotion_total{stage="branch_policy"})` |
| Visualización | Conteo de `allowed` y `blocked`. |
| Labels clave | `stage`, `result` |

### 12. Publicación de imágenes en GHCR

| Campo | Valor |
| --- | --- |
| Pregunta | ¿La imagen se publica correctamente en GHCR? |
| Tipo de panel | Stat o bar chart |
| Query | `sum by (result) (securekubeops_promotion_total{stage="ghcr_publish"})` |
| Visualización | Conteo de `success`, `failure` y `skipped`. |
| Labels clave | `stage`, `result` |

### 13. Generación de SBOM

| Campo | Valor |
| --- | --- |
| Pregunta | ¿Las validaciones de imagen generan SBOM CycloneDX? |
| Tipo de panel | Stat |
| Query | `sum by (result) (securekubeops_supply_chain_artifact{artifact_type="sbom_cyclonedx"})` |
| Visualización | Conteo de `generated` y `missing`. |
| Labels clave | `artifact_type`, `result` |

### 14. Tabla de ejecuciones por fecha declarada

| Campo | Valor |
| --- | --- |
| Pregunta | ¿Cuándo se generaron las métricas de cada workflow? |
| Tipo de panel | Table |
| Query | `sum by (workflow, result, time) (securekubeops_pipeline_execution_total)` |
| Visualización | Tabla con workflow, resultado y label `time`. |
| Labels clave | `workflow`, `result`, `time` |

El label `time` identifica la fecha declarada de generación dentro del artifact. El eje temporal real de Prometheus sigue siendo el momento en el que Prometheus scrapea Pushgateway.

## Organización del dashboard

| Fila | Paneles |
| --- | --- |
| Salud general | Estado global, ejecuciones por workflow, tabla de ejecuciones por fecha declarada. |
| Controles | Resultado por control, fallos por categoría. |
| Seguridad | Secretos detectados, hallazgos por herramienta y severidad. |
| Detalle técnico | Vulnerabilidades de imagen por CVE, misconfigurations Kubernetes, findings SAST detallados. |
| Promoción | Pull Requests permitidas/bloqueadas, publicación en GHCR. |
| Cadena de suministro | Generación de SBOM. |

## Criterios de diseño

- `securekubeops_security_finding_info` genera una muestra por combinación de labels. Si varios findings comparten la misma combinación, el valor de la muestra refleja el número de ocurrencias.
- GitLeaks genera una muestra agregada con el número de secretos detectados.
- Los secretos no se exportan como labels.
- Los valores `commit`, `run_id`, paquete, ruta de fichero, línea y rama exacta permanecen en `metadata.json` o en los JSON técnicos, no en Prometheus.
- `time` se utiliza como label para identificar la fecha declarada de generación de la métrica.

## Fuentes

- Prometheus define el formato text exposition con métricas, labels y valores numéricos.
- Prometheus define PromQL como lenguaje de consulta para seleccionar y agregar series temporales.
- Grafana permite crear paneles con fuente Prometheus usando consultas PromQL.
- Semgrep documenta en su salida JSON campos como `check_id`, `extra.message`, `extra.severity` y `extra.metadata`.
- Trivy documenta campos de salida como `VulnerabilityID`, `Severity`, `Title` y `Description` para reportes de vulnerabilidades.
