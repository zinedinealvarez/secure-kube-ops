# Implementación de un ciclo de vida DevSecOps

Trabajo Fin de Grado de Zinedine Álvarez Sais.

Este repositorio contiene el desarrollo técnico del Trabajo Fin de Grado "Implementación de un ciclo de vida DevSecOps: Automatización de despliegues seguros y observabilidad en Kubernetes".

El proyecto se centra en el diseño y validación de un flujo DevSecOps para automatizar controles de seguridad dentro del ciclo de vida del software. La finalidad principal es construir un proceso CI/CD capaz de integrar análisis estático, detección de secretos, escaneo de imágenes Docker, controles de calidad basados en criticidad, despliegue en Kubernetes y observabilidad del sistema desplegado.

## Objetivo del proyecto

El objetivo principal del TFG es demostrar cómo un flujo CI/CD seguro puede reducir riesgos operativos y mejorar la fiabilidad de despliegues en entornos cloud nativos.

Para ello, el proyecto plantea una arquitectura basada en GitHub Actions como sistema de automatización, herramientas de análisis de seguridad para evaluar código e imágenes, Security Gates para condicionar el avance del pipeline y Kubernetes como entorno final de despliegue. La observabilidad se incorporará como parte del seguimiento del estado de la aplicación y de la infraestructura.

## Aplicación de referencia

La aplicación incluida en este repositorio es una API mínima desarrollada con Node.js y Express.

Su función es servir como aplicación de referencia para validar el pipeline DevSecOps del TFG. No representa una aplicación de negocio compleja ni constituye el producto principal del proyecto. Su valor está en proporcionar una base sencilla y controlada sobre la que probar construcción, análisis, escaneo, aplicación de políticas y despliegue automatizado.

## Estado actual

El repositorio contiene actualmente una aplicación Express mínima con endpoints básicos para comprobar su ejecución local.

La aplicación puede ejecutarse directamente con Node.js o empaquetarse como imagen Docker mediante el `Dockerfile` incluido. La imagen puede construirse localmente y ejecutarse en un contenedor para validar que el comportamiento de la API se mantiene.

También existe un workflow principal de GitHub Actions llamado **DevSecOps Pipeline**, ubicado en `.github/workflows/devsecops-pipeline.yml`. En su versión actual, este workflow ejecuta el job **DevSecOps check**, que detecta posibles secretos con GitLeaks, analiza el código JavaScript/Node.js con Semgrep, valida la construcción de la imagen Docker en cada `push` y `pull_request` y ejecuta un escaneo informativo de vulnerabilidades con Trivy.

También se incluye documentación inicial del contexto académico del proyecto, un archivo `.env.example` con valores falsos de laboratorio y una nota sobre datos de prueba en `docs/lab-vulnerabilities.md`.

En este estado todavía no se ha incorporado publicación de imágenes, despliegue en Kubernetes, observabilidad ni WAF.

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
docker build -t secure-cicd-kubernetes:local .
```

Ejecutar el contenedor:

```bash
docker run --rm -p 3000:3000 secure-cicd-kubernetes:local
```

La API queda disponible por defecto en:

```text
http://localhost:3000
```

Docker permite empaquetar la aplicación como una imagen reproducible. Esta imagen será el artefacto que podrá analizarse en fases posteriores del pipeline DevSecOps y servirá como base para el futuro despliegue en Kubernetes.

## Escaneo de imagen con Trivy

El workflow **DevSecOps Pipeline** incluye un escaneo de la imagen Docker con Trivy.

Durante la integración del pipeline, Trivy se mantiene en modo informativo y muestra todos los hallazgos de severidad `UNKNOWN`, `LOW`, `MEDIUM`, `HIGH` y `CRITICAL` sin bloquear la ejecución.

El Security Gate de Trivy ya fue validado durante el desarrollo del TFG y queda preparado en el workflow para reactivarse en la fase final. Cuando se active, bloqueará la ejecución si detecta vulnerabilidades `HIGH` o `CRITICAL` con corrección disponible.

## Detección de secretos con GitLeaks

El workflow **DevSecOps Pipeline** incorpora GitLeaks como control de detección de secretos. Este paso analiza el repositorio para identificar posibles credenciales, tokens o claves expuestas en el código o en el historial.

GitLeaks mantiene sus reglas por defecto mediante la configuración incluida en `.gitleaks.toml`. Además, se añade una regla controlada para detectar `TFG_FAKE_SECRET`, utilizada únicamente para validar el caso negativo del TFG y comprobar que el pipeline falla cuando aparece un patrón definido como secreto.

El caso negativo ya fue validado activando temporalmente un falso secreto de laboratorio en `.env.example`. Tras comprobar que GitLeaks lo detecta y que el pipeline falla correctamente, el valor se elimina del repositorio para devolver el pipeline a verde.

Este control puede bloquear el pipeline si detecta secretos. El repositorio no debe contener secretos reales; los valores de ejemplo incluidos en `.env.example` son falsos y están documentados como datos de laboratorio académico.

En las pull requests creadas por Dependabot, el step de GitLeaks no se ejecuta porque el `GITHUB_TOKEN` asociado a este tipo de evento puede no disponer de permisos suficientes para consultar información de la PR. La excepción se limita únicamente a GitLeaks; el resto de controles del pipeline se mantienen.

## Análisis estático con Semgrep

El workflow **DevSecOps Pipeline** incorpora Semgrep Community Edition como análisis estático de seguridad para el código JavaScript/Node.js de la aplicación de referencia.

CodeQL se evaluó como opción inicial, pero el repositorio se mantiene privado y GitHub requiere Code Security habilitado para usar code scanning en repositorios privados. Por ese motivo, Semgrep se utiliza como alternativa SAST ejecutable en CI sin publicar el repositorio ni depender de code scanning.

Semgrep se ejecuta dentro del job principal mediante la imagen oficial `semgrep/semgrep` y el comando `semgrep scan --config auto`, manteniendo el análisis estático antes de la construcción de la imagen Docker.

## Endpoints disponibles

Comprobar el estado de la aplicación:

```bash
curl http://localhost:3000/health
```

Consultar la versión de la aplicación de referencia:

```bash
curl http://localhost:3000/version
```

Consultar datos de ejemplo:

```bash
curl http://localhost:3000/items
```

## Evolución prevista

La evolución técnica del repositorio se realizará de forma progresiva, incorporando los componentes necesarios para validar el ciclo de vida DevSecOps definido en el TFG.

Las siguientes fases previstas incluyen:

- Publicación controlada de imágenes en un registry.
- Despliegue automatizado en Kubernetes.
- Incorporación de observabilidad mediante herramientas como Prometheus y Grafana.
- Evaluación de mecanismos de protección perimetral, como un WAF.

## Seguridad y datos de prueba

No se deben incluir secretos reales, credenciales reales, tokens reales, claves privadas reales ni contraseñas reales en este repositorio.

Los valores presentes en `.env.example` son falsos y están marcados como datos de laboratorio académico. Su finalidad es apoyar futuras validaciones del pipeline sin comprometer información sensible real.

## Mantenimiento de dependencias

El repositorio incorpora Dependabot mediante `.github/dependabot.yml`. Su función es revisar semanalmente tres superficies de actualización relevantes para el pipeline DevSecOps:

- dependencias npm de la aplicación;
- acciones utilizadas por GitHub Actions;
- imagen base Docker utilizada por el `Dockerfile`.

Este control permite detectar nuevas versiones disponibles y reducir la exposición a dependencias obsoletas sin introducir secretos ni configuración de registries privados.

Las decisiones sobre las Pull Requests generadas por Dependabot se documentan en `docs/dependabot-decisions.md`.
