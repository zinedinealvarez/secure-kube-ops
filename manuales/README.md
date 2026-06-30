# Manuales de SecureKubeOps

Esta carpeta contiene documentación orientada al uso operativo de SecureKubeOps. A diferencia de `docs/`, que conserva evidencias y documentación técnica de detalle, los manuales están pensados para instalar, utilizar, comprobar y desmontar la solución.

| Manual | Contenido |
| --- | --- |
| `manual-instalacion.md` | Requisitos previos, variables necesarias y ejecución del script de instalación. |
| `manual-uso.md` | Uso básico de la aplicación, Juice Shop, observabilidad, seguridad runtime y WAF. |
| `scripts/install-securekubeops.ps1` | Script operativo de instalación completa o parcial. |

## Separación entre `k8s/` y `azure-waf/`

La carpeta `k8s/` contiene recursos desplegables en Kubernetes: aplicación de referencia, laboratorio vulnerable, observabilidad, seguridad runtime y notas de ARC. Esos recursos pueden aplicarse en Minikube, AKS u otro clúster Kubernetes con pocos cambios, salvo las partes que dependen de Helm o de servicios externos.

La carpeta `azure-waf/` se mantiene separada porque no contiene solo Kubernetes. Incluye plantillas que dependen de Azure, una Azure WAF Policy, Application Gateway for Containers, ALB Controller, permisos de identidad gestionada, configuración de diagnóstico y scripts de creación/eliminación. Además, esta capa puede generar coste, por lo que se despliega únicamente durante pruebas controladas.
