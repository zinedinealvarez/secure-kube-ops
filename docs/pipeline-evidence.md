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
- Trivy image scan informativo.

Evidencias:

```text
reports/metadata.json
reports/summary.md
reports/tools/trivy-image.json
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
- informes de `tools/` para justificar hallazgos de seguridad;
- enlace al run correspondiente en GitHub Actions.
