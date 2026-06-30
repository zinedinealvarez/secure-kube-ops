# Despliegue de OWASP Juice Shop en Kubernetes

Este documento recoge la incorporacion de OWASP Juice Shop como aplicacion vulnerable complementaria dentro de SecureKubeOps.

SecureKubeOps representa la solucion completa del TFG: pipeline DevSecOps, controles de seguridad, despliegue en Kubernetes, evidencias y observabilidad. La aplicacion de referencia actual se mantiene sin cambios para validar el flujo propio de construccion, analisis, publicacion y despliegue.

OWASP Juice Shop se incorpora como carga vulnerable independiente para futuras pruebas de seguridad en runtime y para la validacion posterior de un WAF. En esta fase no se anade WAF, no se modifican workflows y no se cambia la aplicacion actual.

## Rol dentro del laboratorio

La separacion queda definida asi:

| Componente | Rol |
| --- | --- |
| Aplicacion de referencia | Valida el flujo SecureKubeOps existente sobre una imagen propia publicada en GHCR. |
| OWASP Juice Shop | Actua como aplicacion vulnerable de laboratorio para pruebas de runtime y futuras comparativas antes/despues del WAF. |

Juice Shop se despliega en un namespace independiente llamado `vulnerable-lab`. Esta separacion permite tratar la aplicacion vulnerable como un objetivo controlado sin mezclar sus recursos con los manifiestos actuales de la aplicacion de referencia.

## Manifiestos

Los manifiestos se encuentran en:

```text
k8s/labs/juice-shop/
```

Contenido:

| Archivo | Funcion |
| --- | --- |
| `namespace.yaml` | Crea el namespace `vulnerable-lab`. |
| `deployment.yaml` | Despliega OWASP Juice Shop usando la imagen publica `bkimminich/juice-shop:v19.2.1`. |
| `service.yaml` | Crea un Service interno `ClusterIP` para la aplicacion. |
| `kustomization.yaml` | Agrupa los recursos para aplicarlos de forma conjunta con Kustomize. |

El Service no expone la aplicacion publicamente. El acceso inicial se realiza mediante `kubectl port-forward`.

## Despliegue

Antes de aplicar los manifiestos, `kubectl` debe apuntar al cluster Kubernetes de destino.

Comprobar el contexto activo:

```powershell
kubectl config current-context
```

Comprobar los nodos:

```powershell
kubectl get nodes
```

Aplicar Juice Shop:

```powershell
kubectl apply -k k8s/labs/juice-shop
```

Comprobar los recursos:

```powershell
kubectl get all -n vulnerable-lab
```

Revisar el Deployment:

```powershell
kubectl describe deployment juice-shop -n vulnerable-lab
```

Revisar logs:

```powershell
kubectl logs deployment/juice-shop -n vulnerable-lab
```

## Acceso con port-forward

Abrir el acceso local:

```powershell
kubectl port-forward -n vulnerable-lab service/juice-shop 3001:3000
```

La terminal queda ocupada mientras el reenvio de puerto esta activo.

Desde otra terminal o desde el navegador:

```powershell
Invoke-WebRequest -UseBasicParsing -Uri http://localhost:3001
```

La aplicacion queda accesible en:

```text
http://localhost:3001
```

Se usa el puerto local `3001` para evitar conflicto con la aplicacion de referencia, que puede usar `3000` durante sus validaciones.

## Resultados esperados

Tras aplicar los manifiestos se espera:

- namespace `vulnerable-lab` creado;
- Deployment `juice-shop` disponible;
- Pod de Juice Shop en estado `Running`;
- Service interno `juice-shop` de tipo `ClusterIP`;
- acceso local correcto mediante `kubectl port-forward`;
- interfaz web de OWASP Juice Shop accesible en `http://localhost:3001`.

## Evidencias recomendadas

Para documentar esta fase en el TFG conviene conservar:

- salida de `kubectl config current-context`;
- salida de `kubectl get nodes`;
- salida de `kubectl get all -n vulnerable-lab`;
- salida de `kubectl describe deployment juice-shop -n vulnerable-lab`;
- salida de `kubectl logs deployment/juice-shop -n vulnerable-lab`;
- captura del navegador con Juice Shop cargado mediante `http://localhost:3001`;
- referencia a la imagen `bkimminich/juice-shop:v19.2.1`;
- referencia a los manifiestos versionados en `k8s/labs/juice-shop`;
- explicacion de que Juice Shop queda preparado como objetivo vulnerable para futuras pruebas de runtime y WAF.

## Alcance actual

Esta fase solo prepara y despliega Juice Shop como aplicacion vulnerable independiente.

Queda fuera de esta fase:

- configuracion de WAF;
- exposicion publica mediante Ingress o LoadBalancer;
- cambios en Prometheus, Grafana o metricas;
- cambios en AKS;
- cambios en workflows de GitHub Actions;
- sustitucion de la aplicacion de referencia actual.
