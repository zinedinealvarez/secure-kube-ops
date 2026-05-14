# Validación del pipeline DevSecOps

Este documento registra una validación real del pipeline DevSecOps de SecureKubeOps dentro del Trabajo Fin de Grado. La validación se basa en los artifacts generados por GitHub Actions y permite relacionar cada fase del flujo con las evidencias técnicas conservadas por el repositorio.

## Flujo validado

El flujo validado sigue la organización de ramas y workflows definida para SecureKubeOps:

1. Los cambios se integran en una rama con prefijo `pre-`.
2. El workflow **Pre Analysis** valida la rama de trabajo.
3. Se abre una Pull Request desde la rama `pre-*` hacia `main`.
4. Los workflows **Branch Policy** e **Image Validation** validan la Pull Request.
5. Tras el merge en `main`, el workflow **Publish Image** publica la imagen en GitHub Container Registry.

Cada workflow genera un artifact normalizado con:

- `metadata.json`;
- `metrics.prom`;
- informe HTML del workflow;
- evidencias técnicas en `tools/` cuando aplica.

El resumen Markdown se muestra en GitHub Actions mediante `GITHUB_STEP_SUMMARY`, pero no se conserva dentro del artifact porque el paquete descargable ya incluye un informe HTML.

## Evidencias revisadas

| Workflow | Run ID | Commit | Resultado | Artifact revisado |
| --- | --- | --- | --- | --- |
| `Pre Analysis` | `25827461410` | `3a9863cf4d9dad0979dd95b287216aa82591070b` | `success` | `securekubeops-pre-analysis-security-results-25827461410-3a9863cf4d9dad0979dd95b287216aa82591070b.zip` |
| `Branch Policy` | `25846960060` | `626f961d10ec98461ff8e8ca47aba9cff35da588` | `success` | `securekubeops-branch-policy-results-25846960060-626f961d10ec98461ff8e8ca47aba9cff35da588.zip` |
| `Image Validation` | `25846960067` | `626f961d10ec98461ff8e8ca47aba9cff35da588` | `success` | `securekubeops-image-validation-security-results-25846960067-626f961d10ec98461ff8e8ca47aba9cff35da588.zip` |
| `Publish Image` | `25847030208` | `91307035f93db7893a96263a39e43bc304b4c009` | `success` | `securekubeops-ghcr-publish-results-25847030208-91307035f93db7893a96263a39e43bc304b4c009.zip` |

Los commits no tienen que coincidir en todos los workflows, ya que cada artifact corresponde a una etapa distinta del ciclo de vida: validación de una rama `pre-*`, validación de Pull Request y publicación tras la actualización de `main`.

## Resultados por workflow

### Pre Analysis

El artifact de **Pre Analysis** contiene:

- `metadata.json`;
- `metrics.prom`;
- `pre-analysis-security-report.html`;
- `tools/gitleaks-summary.json`;
- `tools/semgrep.json`;
- `tools/trivy-config.json`.

Los controles registrados en `metadata.json` son:

| Control | Resultado |
| --- | --- |
| GitLeaks | `success` |
| Semgrep SAST | `success` |
| Trivy config | `success` |

Las métricas de seguridad agregadas registran:

| Herramienta | Tipo de análisis | Severidad | Hallazgos |
| --- | --- | --- | --- |
| Trivy | `config` | `UNKNOWN` | `0` |
| Trivy | `config` | `LOW` | `11` |
| Trivy | `config` | `MEDIUM` | `4` |
| Trivy | `config` | `HIGH` | `3` |
| Trivy | `config` | `CRITICAL` | `0` |
| Semgrep | `sast` | `INFO` | `2` |
| Semgrep | `sast` | `WARNING` | `1` |
| Semgrep | `sast` | `ERROR` | `12` |

### Branch Policy

El artifact de **Branch Policy** contiene:

- `branch-policy-report.html`;
- `metadata.json`;
- `metrics.prom`.

La Pull Request validada tiene como rama base `main` y como rama origen una rama con prefijo `pre-`. El control `Validate source branch` termina con resultado `success`.

La métrica de promoción asociada queda registrada como:

```prom
securekubeops_promotion_total{stage="branch_policy",result="allowed"} 1
```

### Image Validation

El artifact de **Image Validation** contiene:

- `image-validation-security-report.html`;
- `metadata.json`;
- `metrics.prom`;
- `tools/sbom.cyclonedx.json`;
- `tools/trivy-image.json`.

Los controles registrados en `metadata.json` son:

| Control | Resultado |
| --- | --- |
| Docker build | `success` |
| Trivy image scan | `success` |
| Trivy SBOM | `success` |

La imagen validada es:

```text
secure-kube-ops:626f961d10ec98461ff8e8ca47aba9cff35da588
```

Las métricas de vulnerabilidades de imagen registran:

| Herramienta | Tipo de análisis | Severidad | Hallazgos |
| --- | --- | --- | --- |
| Trivy | `image` | `UNKNOWN` | `0` |
| Trivy | `image` | `LOW` | `2` |
| Trivy | `image` | `MEDIUM` | `2` |
| Trivy | `image` | `HIGH` | `11` |
| Trivy | `image` | `CRITICAL` | `0` |

El SBOM CycloneDX se genera correctamente y queda registrado mediante:

```prom
securekubeops_supply_chain_artifact{workflow="image_validation",artifact_type="sbom_cyclonedx",result="generated"} 1
```

### Publish Image

El artifact de **Publish Image** contiene:

- `metadata.json`;
- `metrics.prom`;
- `publish-image-report.html`.

Los controles registrados en `metadata.json` son:

| Control | Resultado |
| --- | --- |
| Docker build | `success` |
| GHCR login | `success` |
| GHCR push | `success` |

La imagen publicada en GitHub Container Registry es:

```text
ghcr.io/zinedinealvarez/secure-kube-ops:91307035f93db7893a96263a39e43bc304b4c009
```

La métrica de promoción asociada queda registrada como:

```prom
securekubeops_promotion_total{stage="ghcr_publish",result="success"} 1
```

## Conclusión de la validación

La validación confirma que el pipeline DevSecOps de SecureKubeOps ejecuta correctamente las fases principales del ciclo:

- análisis previo de secretos, código y manifiestos Kubernetes en ramas `pre-*`;
- validación de política de ramas en Pull Requests hacia `main`;
- construcción, escaneo y generación de SBOM de la imagen candidata;
- publicación de la imagen final en GitHub Container Registry tras la actualización de `main`;
- generación de evidencias normalizadas por workflow.

Los artifacts revisados mantienen coherencia entre `metadata.json`, `metrics.prom`, los informes HTML y los informes técnicos. Las métricas agregadas reflejan los resultados de los controles y permiten preparar paneles de observabilidad del pipeline sin exponer datos sensibles ni labels de alta cardinalidad.
