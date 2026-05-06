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

También incluye documentación inicial del contexto académico del proyecto, un archivo `.env.example` con valores falsos de laboratorio y una nota sobre datos de prueba en `docs/lab-vulnerabilities.md`.

En este estado todavía no se ha incorporado Docker, GitHub Actions, herramientas de análisis de seguridad, manifiestos Kubernetes, observabilidad ni WAF.

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

- Dockerización de la aplicación de referencia.
- Creación de un pipeline CI/CD con GitHub Actions.
- Integración de análisis estático de código.
- Detección de secretos y valores sensibles.
- Escaneo de vulnerabilidades en imágenes Docker.
- Definición de Security Gates basados en criticidad.
- Despliegue automatizado en Kubernetes.
- Incorporación de observabilidad mediante herramientas como Prometheus y Grafana.
- Evaluación de mecanismos de protección perimetral, como un WAF.

## Seguridad y datos de prueba

No se deben incluir secretos reales, credenciales reales, tokens reales, claves privadas reales ni contraseñas reales en este repositorio.

Los valores presentes en `.env.example` son falsos y están marcados como datos de laboratorio académico. Su finalidad es apoyar futuras validaciones del pipeline sin comprometer información sensible real.
