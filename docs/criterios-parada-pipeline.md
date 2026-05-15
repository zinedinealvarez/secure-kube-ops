# Criterios de parada del pipeline

Este documento define los criterios de validación y parada de los controles del pipeline DevSecOps de SecureKubeOps.

La especificación se organiza por workflow y describe el comportamiento esperado de cada control cuando el pipeline está configurado de forma completa.

## Resumen de workflows

| Workflow | Evento | Función |
| --- | --- | --- |
| `Pre Analysis` | `push` a ramas `pre-*` | Analiza secretos, código fuente y manifiestos Kubernetes antes de promover cambios a `main`. |
| `Image Validation` | Pull Request hacia `main` | Construye la imagen Docker y valida sus vulnerabilidades antes del merge. |
| `Publish Image` | `push` a `main` | Construye y publica la imagen validada en GHCR. |
| `Branch Policy` | Pull Request hacia `main` | Valida que la PR hacia `main` proviene de una rama con prefijo `pre-`. |

## Required checks de `main`

La Branch protection rule de `main` utiliza estos checks obligatorios:

```text
Image Validation
Validate source branch
```

El merge hacia `main` se permite cuando ambos checks finalizan correctamente.

## Workflow: Pre Analysis

Evento:

```yaml
on:
  push:
    branches:
      - 'pre-*'
```

### Checkout del repositorio

Objetivo del control:
Descargar el contenido del repositorio para que los controles posteriores analicen el código, la configuración y los manifiestos versionados.

Criterio de paso:
El checkout finaliza correctamente y el runner dispone del contenido del repositorio.

Criterio de fallo:
El checkout falla por error de permisos, conectividad o referencia Git no disponible.

Efecto del fallo:
El workflow se detiene porque no existe código local sobre el que ejecutar los controles.

Configuración YAML esperada:

```yaml
- name: Checkout repository
  uses: actions/checkout@v6
  with:
    fetch-depth: 0
```

Este criterio de checkout se toma como referencia para el resto de workflows que necesitan disponer del contenido del repositorio antes de ejecutar sus controles.

### GitLeaks

Objetivo del control:
Detectar secretos, credenciales, tokens, claves privadas o patrones definidos como sensibles dentro del repositorio.

Criterio de paso:
GitLeaks no detecta secretos reales ni patrones definidos como secretos de laboratorio.

Criterio de fallo:
GitLeaks detecta un secreto, una credencial o un patrón controlado como `TFG_FAKE_SECRET`.

Efecto del fallo:
El pipeline se detiene y los cambios no quedan validados en la rama `pre-*`.

Configuración YAML esperada:

```yaml
- name: Detect secrets with GitLeaks
  if: github.actor != 'dependabot[bot]'
  env:
    WORKSPACE: ${{ github.workspace }}
  run: |
    mkdir -p reports/gitleaks-source
    rsync -a --exclude='.git' --exclude='reports' ./ reports/gitleaks-source/
    docker run --rm \
      -v "$WORKSPACE/reports/gitleaks-source:/repo:ro" \
      -v "$WORKSPACE/reports/tools:/reports" \
      ghcr.io/gitleaks/gitleaks:v8.24.2 dir /repo \
      --config /repo/.gitleaks.toml \
      --report-format json \
      --report-path /reports/gitleaks.json \
      --redact \
      --exit-code 1 \
      --no-banner
```

### Semgrep SAST

Objetivo del control:
Analizar el código fuente para detectar patrones inseguros mediante análisis estático. Semgrep utiliza reglas automáticas adaptadas al contenido del repositorio y reglas locales versionadas en `.semgrep.yml`.

Criterio de paso:
Semgrep completa el análisis sin hallazgos que incumplan las reglas activas del proyecto.

Criterio de fallo:
Semgrep detecta hallazgos que incumplen las reglas automáticas seleccionadas o las reglas locales definidas en `.semgrep.yml`.

Efecto del fallo:
El pipeline se detiene antes de construir o promover artefactos derivados del código.

Configuración YAML esperada:

```yaml
- name: Run Semgrep SAST
  run: docker run --rm -v "${{ github.workspace }}:/src" --workdir /src semgrep/semgrep semgrep scan --config auto --config .semgrep.yml . --error
```

El criterio de parada se configura mediante `--error`, que convierte los hallazgos de Semgrep en fallo del step. La configuración `--config auto --config .semgrep.yml` combina reglas obtenidas automáticamente con reglas locales versionadas en el repositorio.

### Trivy config sobre Kubernetes

Objetivo del control:
Analizar los manifiestos Kubernetes ubicados en `k8s/` como configuración IaC.

Criterio de paso:
Trivy no detecta configuraciones Kubernetes de severidad `HIGH` o `CRITICAL`.

Criterio de fallo:
Trivy detecta configuraciones de severidad `HIGH` o `CRITICAL` en los manifiestos de `k8s/`.

Efecto del fallo:
El pipeline se detiene antes de que los manifiestos queden validados como parte de la solución.

Configuración YAML esperada:

```yaml
- name: Trivy Kubernetes config Security Gate
  uses: aquasecurity/trivy-action@v0.36.0
  with:
    scan-type: config
    scan-ref: k8s/
    format: table
    exit-code: 1
    severity: HIGH,CRITICAL
```

El criterio de parada se configura mediante `exit-code: 1` y `severity: HIGH,CRITICAL`.

## Workflow: Image Validation

Evento:

```yaml
on:
  pull_request:
    branches:
      - main
```

### Checkout del repositorio

Este workflow aplica el criterio de checkout descrito previamente. El repositorio se descarga antes de construir y analizar la imagen Docker propuesta para `main`.

Configuración YAML esperada:

```yaml
- name: Checkout repository
  uses: actions/checkout@v6
```

### Docker build

Objetivo del control:
Validar que el `Dockerfile`, el código fuente y las dependencias permiten construir una imagen Docker reproducible.

Criterio de paso:
La imagen `secure-kube-ops:${{ github.sha }}` se construye correctamente.

Criterio de fallo:
El build falla por error en Dockerfile, dependencias, contexto de build o comandos de instalación.

Efecto del fallo:
El pipeline se detiene y la PR no queda preparada para merge hacia `main`.

Configuración YAML esperada:

```yaml
- name: Build Docker image
  run: docker build -t secure-kube-ops:${{ github.sha }} .
```

### Trivy image

Objetivo del control:
Analizar vulnerabilidades del sistema operativo y librerías incluidas en la imagen Docker construida.

Criterio de paso:
Trivy no detecta vulnerabilidades `HIGH` o `CRITICAL` con corrección disponible.

Criterio de fallo:
Trivy detecta vulnerabilidades `HIGH` o `CRITICAL` con corrección disponible.

Efecto del fallo:
El pipeline se detiene y la PR no supera el check obligatorio `Image Validation`.

Configuración YAML esperada:

```yaml
- name: Trivy image Security Gate
  uses: aquasecurity/trivy-action@v0.36.0
  with:
    scan-type: image
    image-ref: secure-kube-ops:${{ github.sha }}
    scanners: vuln
    format: table
    exit-code: 1
    ignore-unfixed: true
    vuln-type: os,library
    severity: HIGH,CRITICAL
```

El criterio de parada se configura mediante `exit-code: 1`, `severity: HIGH,CRITICAL` e `ignore-unfixed: true`.

## Workflow: Branch Policy

Evento:

```yaml
on:
  pull_request:
    branches:
      - main
```

### Validate source branch

Objetivo del control:
Garantizar que las Pull Requests hacia `main` provienen exclusivamente de ramas con prefijo `pre-`.

Criterio de paso:
La rama origen de la Pull Request comienza por `pre-`.

Criterio de fallo:
La Pull Request hacia `main` proviene de una rama que no comienza por `pre-`.

Efecto del fallo:
El check `Validate source branch` falla y la Branch protection rule impide el merge hacia `main`.

Configuración YAML esperada:

```yaml
- name: Ensure PR to main comes from pre-prefixed branch
  env:
    SOURCE_BRANCH: ${{ github.head_ref }}
  run: |
    echo "Base branch: ${{ github.base_ref }}"
    echo "Source branch: ${SOURCE_BRANCH}"

    if [[ "${SOURCE_BRANCH}" != pre-* ]]; then
      echo "Pull Requests to main must come from a branch with the pre- prefix."
      exit 1
    fi
```

El criterio de parada se configura mediante la comprobación del prefijo `pre-` sobre `github.head_ref`.

## Workflow: Publish Image

Evento:

```yaml
on:
  push:
    branches:
      - main
```

### Checkout del repositorio

Este workflow aplica el criterio de checkout descrito previamente. El repositorio se descarga desde `main` para construir la imagen final publicable.

Configuración YAML esperada:

```yaml
- name: Checkout repository
  uses: actions/checkout@v6
```

### Docker build para publicación

Objetivo del control:
Construir la imagen Docker final a partir del código ya fusionado en `main`.

Criterio de paso:
La imagen `ghcr.io/zinedinealvarez/secure-kube-ops:${{ github.sha }}` se construye correctamente.

Criterio de fallo:
La construcción de la imagen falla.

Efecto del fallo:
El workflow se detiene y no se realiza login ni publicación en GHCR.

Configuración YAML esperada:

```yaml
- name: Build Docker image
  run: docker build -t ghcr.io/zinedinealvarez/secure-kube-ops:${{ github.sha }} .
```

### Login en GHCR

Objetivo del control:
Autenticar el runner contra GitHub Container Registry usando `GITHUB_TOKEN`.

Criterio de paso:
El login en `ghcr.io` finaliza correctamente.

Criterio de fallo:
El login falla por permisos insuficientes, token no válido o indisponibilidad del registry.

Efecto del fallo:
El workflow se detiene y la imagen no se publica.

Configuración YAML esperada:

```yaml
- name: Login to GitHub Container Registry
  uses: docker/login-action@v4
  with:
    registry: ghcr.io
    username: ${{ github.actor }}
    password: ${{ secrets.GITHUB_TOKEN }}
```

Permisos esperados del workflow:

```yaml
permissions:
  contents: read
  packages: write
```

### Push de imagen a GHCR

Objetivo del control:
Publicar la imagen Docker validada en GitHub Container Registry con etiqueta basada en el SHA del commit.

Criterio de paso:
La imagen se publica correctamente en GHCR.

Criterio de fallo:
El comando `docker push` falla por error de autenticación, permisos, conectividad o conflicto con el registry.

Efecto del fallo:
El workflow queda en estado fallido y no existe artefacto publicado para el commit.

Configuración YAML esperada:

```yaml
- name: Push Docker image to GHCR
  run: docker push ghcr.io/zinedinealvarez/secure-kube-ops:${{ github.sha }}
```

## Criterios globales

- Los secretos bloquean el pipeline en la fase de análisis previa.
- Los hallazgos SAST que incumplen la política del proyecto bloquean el pipeline antes de construir artefactos.
- Las configuraciones Kubernetes `HIGH` o `CRITICAL` bloquean la validación de manifiestos.
- Las vulnerabilidades de imagen `HIGH` o `CRITICAL` con corrección disponible bloquean la PR hacia `main`.
- La rama `main` solo recibe cambios desde ramas con prefijo `pre-` mediante Pull Request.
- La imagen se publica en GHCR únicamente desde código fusionado en `main`.
