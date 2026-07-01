# SecureKubeOps

Trabajo Fin de Grado de Zinedine Alvarez Sais.

SecureKubeOps es una arquitectura de laboratorio para validar un ciclo de vida DevSecOps sobre Kubernetes. El proyecto no busca construir una aplicacion de negocio compleja, sino demostrar como integrar seguridad, automatizacion, despliegue, proteccion y observabilidad alrededor de una aplicacion de referencia.

La solucion parte de cambios en GitHub, ejecuta validaciones automaticas en GitHub Actions, construye y analiza imagenes Docker, publica artefactos en GitHub Container Registry, despliega workloads en Kubernetes y recoge evidencias tecnicas para su revision.

## Componentes Principales

- API de referencia en Node.js y Express.
- Workflows CI/CD con GitHub Actions.
- Deteccion de secretos con GitLeaks.
- Analisis estatico con Semgrep.
- Analisis de manifiestos e imagenes con Trivy.
- Publicacion de imagenes en GitHub Container Registry.
- Despliegue Kubernetes de la aplicacion de referencia.
- Laboratorio vulnerable OWASP Juice Shop.
- Observabilidad con Prometheus, Grafana y Pushgateway.
- Actions Runner Controller en AKS para enviar metricas internas sin exponer Pushgateway.
- Seguridad runtime con Trivy Operator.
- WAF en AKS con Azure Application Gateway for Containers y Azure WAF.

## Estructura

| Ruta | Contenido |
| --- | --- |
| `.github/` | Workflows y Dependabot. |
| `src/` | API de referencia. |
| `k8s/` | Recursos desplegables en Kubernetes: aplicacion, laboratorio, observabilidad, runtime security y ARC. |
| `azure-waf/` | Plantillas, scripts y runbook de la capa WAF en Azure. |
| `security-tools/` | Configuracion de GitLeaks y Semgrep. |
| `manuales/` | Manuales de instalacion, uso y scripts operativos. |
| `docs/` | Documentacion tecnica, evidencias y decisiones del proyecto. |

## Uso Rapido

Ejecucion local de la API:

```bash
npm install
npm start
```

Ejecucion con Docker:

```bash
docker build -t secure-kube-ops:local .
docker run --rm -p 3000:3000 secure-kube-ops:local
```

Instalacion en Kubernetes:

```powershell
powershell -ExecutionPolicy Bypass -File .\manuales\scripts\install-securekubeops.ps1
```

El script se ejecuta sobre un cluster Kubernetes ya disponible y puede instalar la aplicacion, Juice Shop, observabilidad, Trivy Operator y, opcionalmente, la capa WAF.

## Pipeline DevSecOps

Los workflows principales son:

| Workflow | Funcion |
| --- | --- |
| `Pre Analysis` | Analiza secretos, codigo y manifiestos Kubernetes en ramas `pre-*`. |
| `Branch Policy` | Valida que las Pull Requests hacia `main` procedan de ramas permitidas. |
| `Image Validation` | Construye y escanea la imagen candidata antes de integrarla. |
| `Publish Image` | Publica la imagen validada en GHCR tras actualizar `main`. |

Cada ejecucion genera evidencias como `metadata.json`, `metrics.prom`, reportes HTML, resultados JSON y SBOM cuando aplica.

## Kubernetes y Observabilidad

Los recursos Kubernetes se agrupan en `k8s/`:

- `application/`: API de referencia.
- `labs/juice-shop/`: laboratorio vulnerable.
- `monitoring/`: Prometheus, Grafana, Pushgateway y dashboards.
- `runtime-security/`: Trivy Operator.
- `arc/`: localizacion de Actions Runner Controller.

Pushgateway se mantiene como servicio interno. Para enviar metricas del pipeline sin exponerlo publicamente, un runner efimero de ARC ejecuta el job `push-pipeline-metrics` dentro de AKS.

## WAF

La capa WAF se mantiene separada en `azure-waf/` porque depende de recursos especificos de Azure y puede generar coste. Se despliega solo durante pruebas:

```powershell
powershell -ExecutionPolicy Bypass -File .\azure-waf\scripts\deploy-waf.ps1
```

Y se elimina al finalizar:

```powershell
powershell -ExecutionPolicy Bypass -File .\azure-waf\scripts\delete-waf.ps1 -DeleteGeneratedManifests -DeleteLogAnalyticsWorkspace
```

## Documentacion

- `manuales/manual-instalacion.md`: instalacion y requisitos.
- `manuales/manual-uso.md`: uso y comprobaciones.
- `docs/README.md`: indice de documentacion tecnica.
- `k8s/README.md`: organizacion de recursos Kubernetes.
- `security-tools/README.md`: configuracion de herramientas de seguridad.
- `azure-waf/README.md`: diseno operativo de la capa WAF.

## Seguridad

El repositorio no debe contener secretos reales. Las credenciales necesarias para GHCR, Grafana, ARC o Azure se gestionan mediante variables de entorno, Secrets de Kubernetes o servicios externos.

Los valores de `.env.example` son datos falsos de laboratorio.
