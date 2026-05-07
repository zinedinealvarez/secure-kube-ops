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

También existe un workflow principal de GitHub Actions llamado **DevSecOps Pipeline**, ubicado en `.github/workflows/devsecops-pipeline.yml`. En su versión actual, este workflow valida la construcción de la imagen Docker en cada `push` y `pull_request` y ejecuta un primer escaneo informativo de vulnerabilidades con Trivy.

También se incluye documentación inicial del contexto académico del proyecto, un archivo `.env.example` con valores falsos de laboratorio y una nota sobre datos de prueba en `docs/lab-vulnerabilities.md`.

En este estado todavía no se ha incorporado análisis estático, detección de secretos, bloqueo por criticidad, publicación de imágenes, despliegue en Kubernetes, observabilidad ni WAF.

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

El workflow **DevSecOps Pipeline** incluye un primer escaneo de la imagen Docker con Trivy. En esta fase, el escaneo tiene carácter informativo: muestra los resultados en GitHub Actions, pero no bloquea todavía el pipeline en función de la criticidad de las vulnerabilidades detectadas.

Este enfoque permite observar los hallazgos iniciales y preparar una política de Security Gates antes de convertir el escaneo en un control bloqueante.

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

- Integración de análisis estático de código.
- Detección de secretos y valores sensibles.
- Definición de Security Gates basados en criticidad.
- Publicación controlada de imágenes en un registry.
- Despliegue automatizado en Kubernetes.
- Incorporación de observabilidad mediante herramientas como Prometheus y Grafana.
- Evaluación de mecanismos de protección perimetral, como un WAF.

## Seguridad y datos de prueba

No se deben incluir secretos reales, credenciales reales, tokens reales, claves privadas reales ni contraseñas reales en este repositorio.

Los valores presentes en `.env.example` son falsos y están marcados como datos de laboratorio académico. Su finalidad es apoyar futuras validaciones del pipeline sin comprometer información sensible real.
