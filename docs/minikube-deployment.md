# Despliegue local en Minikube

Este documento recoge notas de apoyo para desplegar localmente la API de referencia de SecureKubeOps en Minikube.

La imagen debe obtenerse desde GitHub Container Registry usando el tag generado por el pipeline:

```text
ghcr.io/zinedinealvarez/secure-kube-ops:<commit-sha>
```

El valor `<commit-sha>` debe sustituirse por el SHA del commit publicado por el pipeline en GHCR.

Como ejemplo de prueba, durante esta fase se ha utilizado la siguiente imagen:

```text
ghcr.io/zinedinealvarez/secure-kube-ops:0d3414a6a6aa916eb1daa21c55094c459c472e28
```

Este SHA es solo un ejemplo asociado a una ejecución concreta del pipeline y no debe interpretarse como valor fijo permanente.

## Acceso a GHCR privado

Minikube no tiene acceso automático a imágenes privadas de GHCR. Para permitir que Kubernetes descargue la imagen, se debe crear un `imagePullSecret` local en el clúster.

No se deben guardar tokens reales en los manifiestos ni en el repositorio.
