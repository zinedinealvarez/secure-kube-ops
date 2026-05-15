# Informes y evidencias del pipeline

Este documento recoge la evolución seguida para generar, conservar y consultar evidencias del pipeline DevSecOps de SecureKubeOps.

La documentación se centra en evidencias generadas por GitHub Actions. Los informes se conservan como artifacts asociados a cada ejecución y los resúmenes se muestran en la página del workflow run.

## Enlaces de consulta

- Repositorio: https://github.com/zinedinealvarez/secure-kube-ops
- Workflows de GitHub Actions: https://github.com/zinedinealvarez/secure-kube-ops/actions
- Packages en GHCR: https://github.com/users/zinedinealvarez/packages/container/package/secure-kube-ops

## Fase 1: evidencias por ejecución

La primera fase incorporó evidencias básicas en cada workflow. Cada ejecución genera un resumen visible en GitHub Actions mediante `GITHUB_STEP_SUMMARY` y sube un artifact descargable con los resultados del workflow.

Los artifacts generados siguen un nombre asociado al workflow, al `run_id` y al SHA del commit:

```text
securekubeops-pre-analysis-security-results-<run_id>-<commit-sha>
securekubeops-image-validation-security-results-<run_id>-<commit-sha>
securekubeops-branch-policy-results-<run_id>-<commit-sha>
securekubeops-ghcr-publish-results-<run_id>-<commit-sha>
```

Esta fase permitió validar que GitHub Actions conserva evidencias descargables por ejecución sin versionarlas dentro del repositorio.

## Fase 2: estructura normalizada

La segunda fase normaliza el contenido interno de los artifacts. Todos los workflows generan la misma estructura base:

```text
reports/
  metadata.json
  metrics.prom
  <workflow-report>.html
  tools/
```

`metadata.json` contiene la información común de la ejecución:

- workflow ejecutado;
- `run_id`;
- evento que disparó el workflow;
- rama o ramas implicadas;
- SHA del commit;
- tipo de artifact;
- resultado de los controles ejecutados.

El resumen en Markdown se muestra directamente en GitHub Actions mediante `GITHUB_STEP_SUMMARY`. El artifact conserva `metadata.json`, `metrics.prom`, un informe HTML específico del workflow y los informes específicos de herramientas dentro de `tools/`, por ejemplo:

```text
reports/tools/gitleaks-summary.json
reports/tools/gitleaks.json
reports/tools/semgrep.json
reports/tools/trivy-config.json
reports/tools/trivy-image.json
```

Esta estructura facilita comparar ejecuciones, localizar evidencias concretas y justificar los controles aplicados en el TFG.

La evidencia de GitLeaks se conserva dentro del artifact normalizado de SecureKubeOps mediante un reporte JSON redactado y un resumen sin valores de secretos.

### Trazabilidad en caso de fallo

Los workflows separan la ejecución de controles, la generación de evidencias y la decisión final de fallo.

El flujo aplicado es:

```text
controles -> evidencias -> artifact -> fallo final si corresponde
```

Los controles principales registran su resultado sin detener inmediatamente el job. Después se generan `metadata.json`, `metrics.prom`, el resumen visible en GitHub Actions, el informe HTML y el artifact. Finalmente, un step de cierre evalúa los controles obligatorios y marca el workflow como fallido si corresponde.

Este diseño permite conservar evidencias incluso cuando el pipeline termina en rojo.

## Fase 3: SBOM de imagen

La tercera fase incorpora un SBOM de la imagen Docker generada en **Image Validation**. El SBOM se genera con Trivy en formato CycloneDX y se conserva dentro del artifact normalizado:

```text
reports/tools/sbom.cyclonedx.json
```

El SBOM permite identificar los componentes incluidos en la imagen construida para la Pull Request. Esta evidencia complementa el escaneo de vulnerabilidades porque documenta la composición del artefacto analizado.

## Fase 4: informe HTML descargable

La cuarta fase incorpora un informe HTML estático dentro de cada artifact. Cada workflow genera un nombre de informe adaptado a su función:

```text
reports/pre-analysis-security-report.html
reports/image-validation-security-report.html
reports/branch-policy-report.html
reports/publish-image-report.html
```

Este informe presenta de forma visual los metadatos principales de la ejecución, los controles ejecutados, el resultado de cada control y los archivos de evidencia generados. El HTML no sustituye a los JSON o SBOM originales; funciona como una vista resumida para revisión y documentación académica.

## Fase 5: métricas para Grafana

La quinta fase incorpora un archivo de métricas en formato Prometheus text format dentro de cada artifact:

```text
reports/metrics.prom
```

Estas métricas se conservan como artifact de la ejecución y mantienen un formato compatible con Prometheus text format. Su estructura permite construir paneles agregados en Grafana a partir de los resultados de los pipelines.

Las métricas combinan estado agregado de workflows y controles con hallazgos de seguridad enriquecidos para su visualización en Grafana. Los secretos, commits, `run_id`, rutas de ficheros, líneas, paquetes y valores sensibles permanecen fuera de los labels.

### Resumen de métricas

| Métrica | Tipo | Workflows que la generan | Objetivo en Grafana |
| --- | --- | --- | --- |
| `securekubeops_pipeline_execution_total` | `counter` | `Pre Analysis`, `Image Validation`, `Branch Policy`, `Publish Image` | Salud general del pipeline, total de ejecuciones y porcentaje de éxito/fallo. |
| `securekubeops_pipeline_control_total` | `counter` | `Pre Analysis`, `Image Validation`, `Branch Policy`, `Publish Image` | Fallos por control, herramientas más inestables y evolución de resultados por step. |
| `securekubeops_security_finding_info` | `gauge` | `Pre Analysis`, `Image Validation` | Hallazgos de seguridad enriquecidos para tablas y agregaciones en Grafana. |
| `securekubeops_promotion_total` | `counter` | `Branch Policy`, `Publish Image` | Promoción del flujo: PRs permitidas/bloqueadas e imágenes publicadas en GHCR. |
| `securekubeops_supply_chain_artifact` | `gauge` | `Image Validation` | Generación de evidencias de cadena de suministro, como el SBOM CycloneDX. |

### Detalle de métricas

#### `securekubeops_pipeline_execution_total`

| Campo | Valor |
| --- | --- |
| Finalidad | Contabiliza ejecuciones de workflows para paneles de salud general. |
| Paneles | Total de ejecuciones, ejecuciones por workflow, porcentaje de éxito/fallo global y porcentaje de éxito/fallo por workflow. |
| Labels | `workflow`, `event`, `branch_type`, `result`, `time` |
| Posibles `workflow` | `pre_analysis`, `image_validation`, `branch_policy`, `publish_image` |
| Posibles `event` | `push`, `pull_request` |
| Posibles `branch_type` | `pre`, `main`, `pull_request` |
| Posibles `result` | `success`, `failure` |
| Valor | `1` por ejecución del workflow. |
| Origen | Resultado agregado calculado a partir de los outcomes de los controles principales del workflow. |
| Cardinalidad/privacidad | Riesgo bajo. No usa `commit`, `run_id` ni nombres de ramas arbitrarias como labels. El label `time` identifica la fecha declarada de generación de la métrica. |

Generación por workflow:

| Workflow | Cómo se genera |
| --- | --- |
| `Pre Analysis` | Si GitLeaks, Semgrep o Trivy config fallan, `result="failure"`; en caso contrario, `result="success"`. |
| `Image Validation` | Si Docker build, Trivy image o Trivy SBOM fallan, `result="failure"`; en caso contrario, `result="success"`. |
| `Branch Policy` | Si la validación de rama falla, `result="failure"`; en caso contrario, `result="success"`. |
| `Publish Image` | Si Docker build, login en GHCR o push a GHCR fallan, `result="failure"`; en caso contrario, `result="success"`. |

#### `securekubeops_pipeline_control_total`

| Campo | Valor |
| --- | --- |
| Finalidad | Contabiliza el resultado de cada control ejecutado. |
| Paneles | Controles que más fallan, fallos por categoría y evolución de estabilidad por step. |
| Labels | `workflow`, `control`, `category`, `result`, `time` |
| Posibles `result` | `success`, `failure`, `skipped`, `cancelled` |
| Valor | `1` por control ejecutado. |
| Origen | `${{ steps.<id>.outcome }}` de cada step con identificador. |
| Cardinalidad/privacidad | Riesgo bajo. Los controles y categorías son listas cerradas. |

Controles registrados:

| Workflow | Control | Categoría | Origen |
| --- | --- | --- | --- |
| `Pre Analysis` | `gitleaks` | `secret_detection` | `steps.gitleaks.outcome` |
| `Pre Analysis` | `semgrep_sast` | `sast` | `steps.semgrep_sast.outcome` |
| `Pre Analysis` | `trivy_config` | `iac_scan` | `steps.trivy_config_scan.outcome` |
| `Image Validation` | `docker_build` | `image_build` | `steps.docker_build.outcome` |
| `Image Validation` | `trivy_image` | `image_scan` | `steps.trivy_image_scan.outcome` |
| `Image Validation` | `trivy_sbom` | `sbom` | `steps.trivy_sbom.outcome` |
| `Branch Policy` | `branch_policy` | `branch_policy` | `steps.branch_policy.outcome` |
| `Publish Image` | `docker_build` | `image_build` | `steps.docker_build.outcome` |
| `Publish Image` | `ghcr_login` | `registry_publish` | `steps.ghcr_login.outcome` |
| `Publish Image` | `ghcr_push` | `registry_publish` | `steps.ghcr_push.outcome` |

En **Publish Image**, `ghcr_login` queda con `result="skipped"` cuando no existe una imagen construida correctamente. `ghcr_push` queda con `result="skipped"` cuando no existe una imagen construida correctamente o cuando el login en GHCR no ha finalizado con éxito.

#### `securekubeops_security_finding_info`

| Campo | Valor |
| --- | --- |
| Finalidad | Registra hallazgos de seguridad como muestras consultables en Grafana. |
| Paneles | Secretos detectados, vulnerabilidades por CVE, misconfigurations Kubernetes, findings SAST por CWE y tablas de detalle. |
| Labels | `workflow`, `tool`, `scan_type`, `id`, `severity`, `title`, `description`, `time` y, para Semgrep, `cwe`, `owasp`, `confidence`, `impact`, `likelihood`. |
| Valor | Número de ocurrencias para esa combinación de labels. Si el finding es único, el valor es `1`. En GitLeaks, el valor es el número total de secretos detectados. |
| Origen | Informes JSON generados en `reports/tools/`. |
| Cardinalidad/privacidad | Riesgo controlado para el TFG. No se exportan secretos, rutas, líneas, paquetes, commits ni `run_id`. |

Generación por workflow:

| Workflow | Tool | Scan type | Severidades | Origen |
| --- | --- | --- | --- | --- |
| `Pre Analysis` | `gitleaks` | `secret_detection` | `CRITICAL` | `reports/tools/gitleaks.json` y `reports/tools/gitleaks-summary.json` |
| `Pre Analysis` | `trivy` | `config` | `UNKNOWN`, `LOW`, `MEDIUM`, `HIGH`, `CRITICAL` | `reports/tools/trivy-config.json` |
| `Pre Analysis` | `semgrep` | `sast` | `INFO`, `WARNING`, `ERROR` | `reports/tools/semgrep.json` |
| `Image Validation` | `trivy` | `image` | `UNKNOWN`, `LOW`, `MEDIUM`, `HIGH`, `CRITICAL` | `reports/tools/trivy-image.json` |

#### `securekubeops_promotion_total`

| Campo | Valor |
| --- | --- |
| Finalidad | Contabiliza eventos de promoción del flujo DevSecOps. |
| Paneles | PRs permitidas o bloqueadas, publicaciones de imagen en GHCR y evolución de promoción hacia producción. |
| Labels | `stage`, `result`, `time` |
| Valor | `1` por evento de promoción. |
| Cardinalidad/privacidad | Riesgo bajo. `stage` y `result` son listas cerradas. |

Eventos registrados:

| Workflow | Stage | Posibles result | Origen |
| --- | --- | --- | --- |
| `Branch Policy` | `branch_policy` | `allowed`, `blocked` | `steps.branch_policy.outcome` |
| `Publish Image` | `ghcr_publish` | `success`, `failure`, `skipped` | `steps.ghcr_push.outcome` |

#### `securekubeops_supply_chain_artifact`

| Campo | Valor |
| --- | --- |
| Finalidad | Indica si se ha generado una evidencia de cadena de suministro. |
| Paneles | Porcentaje de imágenes con SBOM y ejecuciones donde el SBOM está disponible. |
| Labels | `workflow`, `artifact_type`, `result`, `time` |
| Posibles `artifact_type` | `sbom_cyclonedx` |
| Posibles `result` | `generated`, `missing` |
| Valor | `1` cuando se registra el estado del artifact. |
| Origen | Existencia de `reports/tools/sbom.cyclonedx.json` en `Image Validation`. |
| Cardinalidad/privacidad | Riesgo bajo. No exporta nombres de componentes ni paquetes. |

El número de componentes del SBOM no se exporta como métrica. El detalle de componentes queda en `reports/tools/sbom.cyclonedx.json`.

## Evidencias por workflow

### Pre Analysis

Evento:

```text
push a ramas pre-*
```

Controles:

- GitLeaks;
- Semgrep SAST;
- Trivy config sobre `k8s/`.

Evidencias:

```text
reports/metadata.json
reports/metrics.prom
reports/pre-analysis-security-report.html
reports/tools/gitleaks.json
reports/tools/gitleaks-summary.json
reports/tools/semgrep.json
reports/tools/trivy-config.json
```

### Image Validation

Evento:

```text
pull_request hacia main
```

Controles:

- Docker build;
- Trivy image scan informativo;
- generación de SBOM CycloneDX.

Evidencias:

```text
reports/metadata.json
reports/metrics.prom
reports/image-validation-security-report.html
reports/tools/trivy-image.json
reports/tools/sbom.cyclonedx.json
```

### Branch Policy

Evento:

```text
pull_request hacia main
```

Control:

- validación de rama origen con prefijo `pre-`.

Evidencias:

```text
reports/metadata.json
reports/metrics.prom
reports/branch-policy-report.html
```

### Publish Image

Evento:

```text
push a main
```

Controles:

- Docker build;
- login en GHCR;
- publicación de imagen en GHCR.

Evidencias:

```text
reports/metadata.json
reports/metrics.prom
reports/publish-image-report.html
```

La imagen publicada queda disponible en GHCR con etiqueta basada en el SHA del commit:

```text
ghcr.io/zinedinealvarez/secure-kube-ops:<commit-sha>
```

## Conservación

Los artifacts se conservan durante 90 días mediante `retention-days: 90`. Esta retención permite mantener evidencias suficientes durante el desarrollo y validación del TFG sin almacenar informes generados dentro del repositorio.

## Uso como evidencia académica

Para documentar una ejecución en la memoria del TFG se usa:

- captura o referencia al summary del workflow;
- artifact descargado de la ejecución;
- `metadata.json` para identificar commit, workflow y resultado;
- `metrics.prom` como preparación de visualización en Prometheus/Grafana;
- informe HTML del workflow como evidencia visual descargable;
- informes de `tools/` para justificar hallazgos de seguridad;
- SBOM CycloneDX para evidenciar los componentes incluidos en la imagen;
- enlace al run correspondiente en GitHub Actions.
