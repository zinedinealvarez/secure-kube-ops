# Despliegue local en Minikube

Este documento recoge notas de apoyo para desplegar localmente la API de referencia de SecureKubeOps en Minikube.

La imagen se obtiene desde GitHub Container Registry usando el tag generado por el pipeline:

```text
ghcr.io/zinedinealvarez/secure-kube-ops:<commit-sha>
```

El valor `<commit-sha>` se sustituye por el SHA del commit publicado por el pipeline en GHCR.

Como ejemplo de prueba, durante esta fase se ha utilizado la siguiente imagen:

```text
ghcr.io/zinedinealvarez/secure-kube-ops:0d3414a6a6aa916eb1daa21c55094c459c472e28
```

Este SHA es solo un ejemplo asociado a una ejecución concreta del pipeline y no funciona como valor fijo permanente.

## Acceso a GHCR privado

Minikube no tiene acceso automático a imágenes privadas de GHCR. Para que Kubernetes descargue la imagen, se crea un `imagePullSecret` local en el clúster.

Los tokens reales quedan fuera de los manifiestos y del repositorio.

## Validación realizada

Durante la validación local con Minikube se ha comprobado:

- creación del `imagePullSecret` para permitir el acceso a la imagen privada alojada en GHCR;
- despliegue del `Deployment` definido en `k8s/application/deployment.yaml`;
- creación del `Service` definido en `k8s/application/service.yaml`;
- acceso correcto al endpoint `/health` mediante `kubectl port-forward`.

No se incluyen capturas en el repositorio. La evidencia técnica queda representada por los manifiestos, los comandos documentados y la ejecución local del flujo de despliegue.
