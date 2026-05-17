# Implementación de un ciclo de vida DevSecOps

Trabajo Fin de Grado de Zinedine Álvarez Sais.

Este repositorio contiene el desarrollo técnico del Trabajo Fin de Grado "Implementación de un ciclo de vida DevSecOps: Automatización de despliegues seguros y observabilidad en Kubernetes".

La solución práctica desarrollada para validar este flujo se denomina **SecureKubeOps**. Incluye el pipeline DevSecOps, los controles de seguridad, la construcción de imágenes Docker, el despliegue en Kubernetes y la configuración de observabilidad. El nombre técnico utilizado para el paquete, la imagen Docker y las referencias operativas es `secure-kube-ops`.

El proyecto se centra en el diseño y validación de un flujo DevSecOps para automatizar controles de seguridad dentro del ciclo de vida del software. La finalidad principal es construir un proceso CI/CD capaz de integrar análisis estático, detección de secretos, escaneo de imágenes Docker, controles de calidad basados en criticidad, despliegue en Kubernetes y observabilidad del sistema desplegado.

## Objetivo del proyecto

El objetivo principal del TFG es demostrar cómo un flujo CI/CD seguro puede reducir riesgos operativos y mejorar la fiabilidad de despliegues en entornos cloud nativos.

Para ello, el proyecto plantea una arquitectura basada en GitHub Actions como sistema de automatización, herramientas de análisis de seguridad para evaluar código e imágenes, Security Gates para condicionar el avance del pipeline y Kubernetes como entorno final de despliegue. La observabilidad forma parte del seguimiento del estado de la aplicación y de la infraestructura.

## Aplicación de referencia

La aplicación incluida en este repositorio es una API mínima desarrollada con Node.js y Express dentro de la solución SecureKubeOps.

Su función es servir como API de referencia para validar la solución SecureKubeOps dentro del TFG. No representa una aplicación de negocio compleja ni constituye el producto principal del proyecto. Su valor está en proporcionar una base sencilla y controlada sobre la que probar construcción, análisis, escaneo, aplicación de políticas y despliegue automatizado.

## Estado actual

El repositorio contiene actualmente una aplicación Express mínima con endpoints básicos para comprobar su ejecución local.

La aplicación puede ejecutarse directamente con Node.js o empaquetarse como imagen Docker mediante el `Dockerfile` incluido. La imagen puede construirse localmente y ejecutarse en un contenedor para validar que el comportamiento de la API se mantiene.

El pipeline de GitHub Actions se organiza en workflows separados para facilitar la validación del flujo DevSecOps. **Pre Analysis** se ejecuta al hacer push a ramas con prefijo `pre-` y agrupa GitLeaks, Semgrep y el escaneo de manifiestos Kubernetes con Trivy. **Image Validation** se ejecuta en Pull Requests hacia `main` y valida la construcción de la imagen Docker junto con el escaneo informativo de vulnerabilidades de imagen. **Publish Image** se ejecuta al actualizar `main` y publica la imagen validada en GHCR.

También se incluye documentación inicial del contexto académico del proyecto, un archivo `.env.example` con valores falsos de laboratorio y una nota sobre datos de prueba en `docs/lab-vulnerabilities.md`.

En este estado se incluye un despliegue Kubernetes básico para Minikube, una configuración inicial de observabilidad con `kube-prometheus-stack` y un despliegue independiente de OWASP Juice Shop como aplicación vulnerable complementaria para futuras pruebas de seguridad en runtime y WAF. Todavía no se ha incorporado WAF.

Dependabot está configurado para revisar semanalmente las dependencias npm, las acciones de GitHub Actions y la imagen base definida en el `Dockerfile`.

## Ejecución local

Instalar dependencias:

```bash
npm install
```

Arrancar la aplicación:

```bash
npm start
```

La API queda disponible por defecto en:

```text
http://localhost:3000
```

## Ejecución con Docker

Construir la imagen localmente:

```bash
docker build -t secure-kube-ops:local .
```

Ejecutar el contenedor:

```bash
docker run --rm -p 3000:3000 secure-kube-ops:local
```

La API queda disponible por defecto en:

```text
http://localhost:3000
```

Docker permite empaquetar la aplicación como una imagen reproducible. Esta imagen actúa como artefacto analizable dentro del pipeline DevSecOps y como base para el despliegue en Kubernetes.

## Publicación de imagen en GHCR

El workflow **Publish Image** publica automáticamente la imagen Docker en GitHub Container Registry cuando se ejecuta sobre un `push` a la rama `main`. No se publican imágenes desde eventos `pull_request`.

La imagen publicada sigue este formato:

```text
ghcr.io/zinedinealvarez/secure-kube-ops:<commit-sha>
```

El uso del SHA del commit como etiqueta permite relacionar cada imagen con el código, los controles ejecutados y la ejecución del pipeline que la generó.

## Despliegue local en Minikube

SecureKubeOps incluye manifiestos Kubernetes básicos en `k8s/` para desplegar la API de referencia en un clúster local de Minikube.

La imagen se obtiene desde GHCR usando el tag publicado por el pipeline:

```text
ghcr.io/zinedinealvarez/secure-kube-ops:<commit-sha>
```

El valor `<commit-sha>` se sustituye por el tag publicado por el pipeline en GitHub Container Registry.

Como la imagen está en un registry privado, Minikube utiliza un `imagePullSecret`. Los tokens reales quedan fuera de los manifiestos y del repositorio.

Comprobar herramientas:

```bash
kubectl version --client
minikube version
minikube status
```

Arrancar Minikube:

```bash
minikube start
```

Crear el `imagePullSecret` para GHCR:

```powershell
$env:GHCR_USERNAME="zinedinealvarez"
$env:GHCR_TOKEN="TU_TOKEN_DE_GITHUB_CON_READ_PACKAGES"
kubectl create secret docker-registry ghcr-pull-secret --docker-server=ghcr.io --docker-username=$env:GHCR_USERNAME --docker-password=$env:GHCR_TOKEN
```

Aplicar los manifiestos:

```bash
kubectl apply -f k8s/deployment.yaml
kubectl apply -f k8s/service.yaml
```

Comprobar recursos:

```bash
kubectl get pods
kubectl get services
kubectl describe pod -l app=secure-kube-ops
```

Probar el endpoint `/health` mediante `port-forward`:

```bash
kubectl port-forward service/secure-kube-ops 3000:3000
```

En otra terminal:

```bash
curl http://localhost:3000/health
```

## Aplicación vulnerable de laboratorio

OWASP Juice Shop se incorpora como una aplicación vulnerable complementaria dentro de SecureKubeOps. Su finalidad no es sustituir la aplicación de referencia actual, sino servir como objetivo controlado para futuras pruebas de seguridad en runtime y para la comparativa antes/después de incorporar un WAF.

Los manifiestos se encuentran en `k8s/juice-shop/` e incluyen namespace, Deployment, Service y Kustomization. El acceso inicial se realiza mediante `kubectl port-forward`, sin Ingress, LoadBalancer ni WAF:

```bash
kubectl apply -k k8s/juice-shop
kubectl port-forward -n vulnerable-lab service/juice-shop 3001:3000
```

La guía completa está disponible en `docs/juice-shop-deployment.md`.

## Observabilidad en Kubernetes

La configuración inicial de observabilidad se encuentra en `monitoring/values.yaml` y está documentada en `docs/observability.md`.

El orden recomendado para instalar y comprobar la observabilidad es:

1. Instalar `kube-prometheus-stack` siguiendo `docs/observability.md`.
2. Instalar Pushgateway con `monitoring/pushgateway-values.yaml`.
3. Aplicar `monitoring/pushgateway-servicemonitor.yaml`.
4. Enviar una métrica de prueba o un archivo `metrics.prom` siguiendo `docs/pipeline-metrics-integration.md`.
5. Consultar la métrica en Prometheus.
6. Crear el dashboard de Grafana usando `docs/pipeline-dashboard.md` como diseño de paneles.

La instalación se realiza con Helm fijando la versión `84.5.0` del chart. El namespace se entrega como manifiesto en `monitoring/namespace.yaml` y la contraseña de Grafana se configura mediante un Secret de Kubernetes que queda fuera del repositorio:

```bash
helm upgrade --install monitoring prometheus-community/kube-prometheus-stack --namespace monitoring --version 84.5.0 -f monitoring/values.yaml
```

`monitoring/values.yaml` activa persistencia para Prometheus y Grafana. Prometheus solicita `5Gi` y conserva métricas durante `7d`; Grafana solicita `1Gi` para conservar su estado local entre reinicios del Pod.

Las métricas del pipeline se validan con la capa de observabilidad mediante Pushgateway, instalado como servicio interno del namespace `monitoring`. Los archivos `metrics.prom` se conservan como artifacts de GitHub Actions y se envían manualmente a Pushgateway durante la validación usando un `job` estable por workflow, por ejemplo `securekubeops-pre-analysis`, `securekubeops-image-validation`, `securekubeops-branch-policy` o `securekubeops-publish-image`:

```bash
helm upgrade --install pushgateway prometheus-community/prometheus-pushgateway --namespace monitoring --version 3.6.0 -f monitoring/pushgateway-values.yaml
```

```bash
kubectl apply -f monitoring/pushgateway-servicemonitor.yaml
```

## Escaneo de imagen con Trivy

El workflow **Image Validation** incluye un escaneo de la imagen Docker con Trivy.

Trivy se mantiene en modo informativo y muestra todos los hallazgos de severidad `UNKNOWN`, `LOW`, `MEDIUM`, `HIGH` y `CRITICAL` sin bloquear la ejecución.

El Security Gate de Trivy ya fue validado durante el desarrollo del TFG y queda documentado en el workflow como criterio bloqueante para vulnerabilidades `HIGH` o `CRITICAL` con corrección disponible.

## Escaneo de manifiestos Kubernetes con Trivy

El workflow **Pre Analysis** incorpora un escaneo informativo de configuración sobre el directorio `k8s/` mediante Trivy `config`. Este control revisa los manifiestos Kubernetes como IaC durante la validación previa en ramas con prefijo `pre-`.

El escaneo no bloquea el pipeline; se utiliza para obtener visibilidad sobre la configuración de Kubernetes y conservar evidencia de los hallazgos detectados.

## Detección de secretos con GitLeaks

El workflow **Pre Analysis** incorpora GitLeaks como control de detección de secretos. Este paso analiza el estado actual del repositorio para identificar posibles credenciales, tokens o claves expuestas en el código versionado.

GitLeaks mantiene sus reglas por defecto mediante la configuración incluida en `.gitleaks.toml`. Además, se añade una regla controlada para detectar `TFG_FAKE_SECRET`, utilizada únicamente para validar el caso negativo del TFG y comprobar que el pipeline falla cuando aparece un patrón definido como secreto.

El caso negativo ya fue validado activando temporalmente un falso secreto de laboratorio en `.env.example`. Tras comprobar que GitLeaks lo detecta y que el pipeline falla correctamente, el valor se elimina del repositorio para devolver el pipeline a verde.

Este control puede bloquear el pipeline si detecta secretos. El repositorio no contiene secretos reales; los valores de ejemplo incluidos en `.env.example` son falsos y están documentados como datos de laboratorio académico.

En las pull requests creadas por Dependabot, el step de GitLeaks no se ejecuta porque el `GITHUB_TOKEN` asociado a este tipo de evento puede no disponer de permisos suficientes para consultar información de la PR. La excepción se limita únicamente a GitLeaks; el resto de controles del pipeline se mantienen.

## Análisis estático con Semgrep

El workflow **Pre Analysis** incorpora Semgrep Community Edition como análisis estático de seguridad para el código fuente de la solución SecureKubeOps.

CodeQL se evaluó como opción inicial, pero el repositorio se mantiene privado y GitHub requiere Code Security habilitado para usar code scanning en repositorios privados. Por ese motivo, Semgrep se utiliza como alternativa SAST ejecutable en CI sin publicar el repositorio ni depender de code scanning.

Semgrep se ejecuta mediante la imagen oficial `semgrep/semgrep` con el comando `semgrep scan --config auto --config .semgrep.yml .`. La configuración `--config auto` mantiene una selección automática de reglas adaptada al contenido del repositorio y `.semgrep.yml` añade reglas locales versionadas para documentar criterios propios del TFG.

La política inicial versionada incluye una regla que detecta el uso de `eval()` en JavaScript y TypeScript, al tratarse de un patrón inseguro que puede ejecutar código arbitrario.

## Informes y evidencias del pipeline

Los workflows de SecureKubeOps generan evidencias por ejecución para facilitar la revisión técnica del pipeline DevSecOps dentro del TFG.

Cada ejecución incorpora un resumen en GitHub Actions mediante `GITHUB_STEP_SUMMARY`, con el resultado de los controles ejecutados y la referencia al commit analizado. Además, los workflows suben artefactos con informes en formatos estructurados cuando aplica:

- **Pre Analysis** conserva evidencias de GitLeaks, Semgrep y Trivy config.
- **Image Validation** conserva metadatos de la imagen local construida, el informe de Trivy image y el SBOM CycloneDX de la imagen.
- **Publish Image** conserva metadatos de la imagen publicada en GHCR.
- **Branch Policy** conserva la validación de rama origen y rama destino.

Los artefactos se publican con nombres asociados al workflow, al `run_id` y al SHA del commit. La retención configurada es de 90 días, suficiente para conservar evidencias por ejecución durante el desarrollo y validación del TFG.

Cada artifact incluye `metadata.json`, `metrics.prom`, un informe HTML específico del workflow y los informes técnicos dentro de `tools/` cuando aplica. El resumen Markdown se muestra en GitHub Actions mediante `GITHUB_STEP_SUMMARY`, mientras que el HTML funciona como informe estático descargable de la ejecución. La evolución de esta estrategia y la estructura normalizada de los artifacts se documenta en `docs/pipeline-evidence.md`.

El artifact SARIF automático de GitLeaks queda desactivado para evitar duplicar evidencias fuera del paquete normalizado de SecureKubeOps.

## Documentación técnica

La documentación técnica del repositorio se organiza en los siguientes documentos:

| Documento | Contenido |
| --- | --- |
| `docs/branch-flow.md` | Flujo de ramas `pre-* -> main` y protección de `main`. |
| `docs/criterios-parada-pipeline.md` | Criterios de validación y parada de los controles del pipeline. |
| `docs/pipeline-evidence.md` | Estructura de artifacts, evidencias, métricas y reportes generados por los workflows. |
| `docs/pipeline-validation.md` | Validación real del pipeline a partir de artifacts generados por GitHub Actions. |
| `docs/pipeline-dashboard.md` | Diseño del dashboard de Grafana para visualizar métricas del pipeline. |
| `docs/pipeline-metrics-integration.md` | Integración de métricas del pipeline mediante Pushgateway, Prometheus y Grafana. |
| `docs/cluster-portability.md` | Puesta en marcha completa de SecureKubeOps en otro clúster Kubernetes. |
| `docs/minikube-deployment.md` | Despliegue local de la API de referencia en Minikube. |
| `docs/juice-shop-deployment.md` | Despliegue de OWASP Juice Shop como aplicación vulnerable complementaria para futuras pruebas de runtime y WAF. |
| `docs/observability.md` | Configuración de observabilidad con `kube-prometheus-stack`. |
| `docs/dependabot-decisions.md` | Decisiones tomadas sobre Pull Requests de Dependabot. |
| `docs/lab-vulnerabilities.md` | Nota sobre datos de prueba y valores falsos utilizados en el contexto académico del TFG. |

## Endpoints disponibles

Comprobar el estado de la aplicación:

```bash
curl http://localhost:3000/health
```

Consultar la versión de la API de referencia:

```bash
curl http://localhost:3000/version
```

Consultar datos de ejemplo:

```bash
curl http://localhost:3000/items
```

## Alcance técnico

El repositorio reúne los componentes necesarios para validar el ciclo de vida DevSecOps definido en el TFG:

- publicación controlada de imágenes en GHCR;
- validación de imágenes y manifiestos Kubernetes;
- despliegue local en Kubernetes con Minikube;
- despliegue independiente de OWASP Juice Shop como aplicación vulnerable de laboratorio;
- configuración de observabilidad con Prometheus y Grafana mediante `kube-prometheus-stack`;
- documentación de evidencias, métricas y decisiones técnicas del pipeline.

El WAF no forma parte de la configuración implementada en este estado del repositorio.

## Seguridad y datos de prueba

El repositorio no incluye secretos reales, credenciales reales, tokens reales, claves privadas reales ni contraseñas reales.

Los valores presentes en `.env.example` son falsos y están marcados como datos de laboratorio académico. Su finalidad es apoyar validaciones del pipeline sin comprometer información sensible real.

## Mantenimiento de dependencias

El repositorio incorpora Dependabot mediante `.github/dependabot.yml`. Su función es revisar semanalmente tres superficies de actualización relevantes para el pipeline DevSecOps:

- dependencias npm de la aplicación;
- acciones utilizadas por GitHub Actions;
- imagen base Docker utilizada por el `Dockerfile`.

Este control permite detectar nuevas versiones disponibles y reducir la exposición a dependencias obsoletas sin introducir secretos ni configuración de registries privados.

Las decisiones sobre las Pull Requests generadas por Dependabot se documentan en `docs/dependabot-decisions.md`.

## Flujo de ramas

El repositorio utiliza un flujo de ramas simple basado en ramas de validación con prefijo `pre-` y una rama de producción:

- `pre-*`: ramas de trabajo y validación. En estas ramas se trabaja directamente y se permite hacer push.
- `main`: rama de producción. Esta rama está protegida mediante una Branch protection rule.

El flujo funciona así:

1. Los cambios se hacen directamente en una rama con prefijo `pre-`, por ejemplo `pre-observability` o `pre-pipeline`.
2. Se hace push a esa rama `pre-*`.
3. Se abre una Pull Request desde la rama `pre-*` hacia `main`.
4. `main` solo se actualiza mediante Pull Request.
5. El merge a `main` se realiza cuando pasan los checks obligatorios.

Checks obligatorios configurados:

```text
Image Validation
Validate source branch
```

La opción equivalente a `Require branches to be up to date before merging` queda desactivada. Durante la validación del flujo generaba bloqueos del tipo `This branch is out-of-date with the base branch`, especialmente después de merges que actualizaban la rama base y dejaban la Pull Request pendiente de sincronización. El control de entrada a `main` se mantiene mediante Pull Request obligatoria y checks requeridos en verde.

El bloqueo de push directo a `main` se validó correctamente. GitHub devolvió este error al intentar actualizar la rama protegida directamente:

```text
GH006: Protected branch update failed for refs/heads/main.
Changes must be made through a pull request.
2 of 2 required status checks are expected.
```

La documentación completa del flujo de ramas se encuentra en `docs/branch-flow.md`.

Para que la protección de ramas se aplicase en el entorno del TFG, el repositorio funcionó en modo público o con un plan de GitHub compatible con Branch protection en repositorios privados.
