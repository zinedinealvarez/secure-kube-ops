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
securekubeops-pre-analysis-<run_id>-<commit-sha>
securekubeops-image-validation-<run_id>-<commit-sha>
securekubeops-branch-policy-<run_id>-<commit-sha>
securekubeops-publish-image-<run_id>-<commit-sha>
```

Esta fase permitió validar que GitHub Actions conserva evidencias descargables por ejecución sin versionarlas dentro del repositorio.

## Fase 2: estructura normalizada

La segunda fase normaliza el contenido interno de los artifacts. Todos los workflows generan la misma estructura base:

```text
reports/
  metadata.json
  summary.md
  report.html
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

`summary.md` contiene el resumen en Markdown que también se muestra en GitHub Actions. El directorio `tools/` contiene informes específicos de herramientas cuando aplica, por ejemplo:

```text
reports/tools/gitleaks-summary.json
reports/tools/semgrep.json
reports/tools/trivy-config.json
reports/tools/trivy-image.json
```

Esta estructura facilita comparar ejecuciones, localizar evidencias concretas y justificar los controles aplicados en el TFG.

## Fase 3: SBOM de imagen

La tercera fase incorpora un SBOM de la imagen Docker generada en **Image Validation**. El SBOM se genera con Trivy en formato CycloneDX y se conserva dentro del artifact normalizado:

```text
reports/tools/sbom.cyclonedx.json
```

El SBOM permite identificar los componentes incluidos en la imagen construida para la Pull Request. Esta evidencia complementa el escaneo de vulnerabilidades porque documenta la composición del artefacto analizado.

## Fase 4: informe HTML descargable

La cuarta fase incorpora un informe HTML estático dentro de cada artifact:

```text
reports/report.html
```

Este informe presenta de forma visual los metadatos principales de la ejecución, los controles ejecutados, el resultado de cada control y los archivos de evidencia generados. El HTML no sustituye a los JSON, SARIF o SBOM originales; funciona como una vista resumida para revisión y documentación académica.

## Evidencias por workflow

### Pre Analysis

Evento:

```text
push a pre
```

Controles:

- GitLeaks;
- Semgrep SAST;
- Trivy config sobre `k8s/`.

Evidencias:

```text
reports/metadata.json
reports/summary.md
reports/report.html
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
reports/summary.md
reports/report.html
reports/tools/trivy-image.json
reports/tools/sbom.cyclonedx.json
```

### Branch Policy

Evento:

```text
pull_request hacia main
```

Control:

- validación de rama origen `pre`.

Evidencias:

```text
reports/metadata.json
reports/summary.md
reports/report.html
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
reports/summary.md
reports/report.html
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
- `report.html` como informe visual descargable;
- informes de `tools/` para justificar hallazgos de seguridad;
- SBOM CycloneDX para evidenciar los componentes incluidos en la imagen;
- enlace al run correspondiente en GitHub Actions.
