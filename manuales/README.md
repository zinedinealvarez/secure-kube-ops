# Manuales de SecureKubeOps

Esta carpeta contiene documentacion orientada al uso operativo de SecureKubeOps. A diferencia de `docs/`, que conserva evidencias y documentacion tecnica de detalle, los manuales estan pensados para instalar, utilizar, comprobar y desmontar la solucion.

| Manual | Contenido |
| --- | --- |
| `manual-instalacion.md` | Requisitos previos, variables necesarias y ejecucion del script de instalacion. |
| `manual-uso.md` | Uso basico de la aplicacion, Juice Shop, observabilidad, seguridad runtime y WAF. |
| `scripts/install-securekubeops.ps1` | Script operativo de instalacion completa o parcial. |

## Separacion entre `k8s/` y `azure-waf/`

La carpeta `k8s/` contiene recursos desplegables en Kubernetes: aplicacion de referencia, laboratorio vulnerable, observabilidad, seguridad runtime y notas de ARC. Esos recursos pueden aplicarse en Minikube, AKS u otro cluster Kubernetes con pocos cambios, salvo las partes que dependen de Helm o de servicios externos.

La carpeta `azure-waf/` se mantiene separada porque no contiene solo Kubernetes. Incluye plantillas que dependen de Azure, una Azure WAF Policy, Application Gateway for Containers, ALB Controller, permisos de identidad gestionada, configuracion de diagnostico y scripts de creacion/eliminacion. Ademas, esta capa puede generar coste, por lo que se despliega unicamente durante pruebas controladas.
