# Decisiones sobre Pull Requests de Dependabot

Este documento registra la revisión inicial de las Pull Requests generadas por Dependabot en el contexto del Trabajo Fin de Grado.

SecureKubeOps es la solución práctica del TFG, no la aplicación Express. La aplicación incluida en el repositorio es una API de referencia utilizada como base controlada para validar el pipeline DevSecOps. Por ese motivo, las actualizaciones propuestas por Dependabot se revisan teniendo en cuenta su impacto sobre la estabilidad del entorno de pruebas.

## PR #1: actions/checkout de v4 a v6

- Enlace: https://github.com/zinedinealvarez/secure-cicd-kubernetes/pull/1
- Cambio propuesto: actualizar `actions/checkout` de `v4` a `v6`.
- Decisión: aceptar si el pipeline **DevSecOps Pipeline** finaliza correctamente.
- Motivo: el cambio afecta a una acción del propio pipeline y puede mejorar el mantenimiento de la automatización sin modificar la lógica de la aplicación de referencia.

## PR #2: imagen Docker base de Node 20 Alpine a Node 26 Alpine

- Enlace: https://github.com/zinedinealvarez/secure-cicd-kubernetes/pull/2
- Cambio propuesto: actualizar la imagen base del `Dockerfile` de `node:20-alpine` a `node:26-alpine`.
- Decisión: dejar pendiente.
- Motivo: el cambio afecta al runtime de ejecución de la aplicación. Aunque la actualización puede ser necesaria más adelante, se pospone para no introducir variaciones en el entorno mientras se está construyendo y validando el pipeline DevSecOps.

## PR #3: Express de 4.22.1 a 5.2.1

- Enlace: https://github.com/zinedinealvarez/secure-cicd-kubernetes/pull/3
- Cambio propuesto: actualizar `express` de `4.22.1` a `5.2.1`.
- Decisión: dejar pendiente.
- Motivo: el cambio afecta al framework de la aplicación de referencia. Se pospone para evitar cambios funcionales mientras el objetivo principal es consolidar los controles del pipeline.

## Criterio aplicado

Las PRs de Dependabot no se aceptan automáticamente. En esta fase del TFG, la prioridad es mantener estable la aplicación de referencia para poder evaluar el comportamiento del pipeline DevSecOps.

Las actualizaciones que afectan directamente al pipeline pueden aceptarse si los controles finalizan correctamente. Las actualizaciones que modifican el runtime o el framework de la aplicación se mantienen pendientes hasta que la base del pipeline esté consolidada.
