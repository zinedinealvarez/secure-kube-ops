# Trivy Operator

Esta carpeta contiene la configuracion minima de Trivy Operator para la fase de seguridad runtime de SecureKubeOps.

El operador se instala en el namespace `runtime-security` y analiza los workloads desplegados en el cluster en modo observacion. Su funcion es generar reports de seguridad sin bloquear despliegues ni modificar la aplicacion de referencia, Juice Shop, workflows, WAF, AKS o NetworkPolicies.

Reports esperados:

- `VulnerabilityReport`: vulnerabilidades detectadas en imagenes que estan ejecutandose.
- `ConfigAuditReport`: configuraciones inseguras en recursos Kubernetes desplegados.
- `ExposedSecretReport`: posibles secretos embebidos dentro de imagenes de contenedor.

La instalacion y verificacion estan documentadas en `docs/runtime-security-monitoring.md`.
