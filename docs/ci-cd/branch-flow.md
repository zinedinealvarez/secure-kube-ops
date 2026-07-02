# Flujo de ramas

El repositorio de SecureKubeOps utiliza un flujo de ramas basado en ramas de validacion con prefijo `pre-` y una rama principal `main`.

- `pre-*`: ramas de trabajo y validacion. En estas ramas se trabaja directamente y se permite hacer push.
- `dependabot/*`: ramas automaticas creadas por Dependabot para actualizar dependencias, acciones de GitHub Actions e imagenes base.
- `main`: rama principal del proyecto. Solo se actualiza mediante Pull Request.

## Flujo de trabajo

1. Crear una rama con prefijo `pre-`, por ejemplo `pre-waf` o `pre-observability`.
2. Introducir los cambios y hacer push a la rama `pre-*`.
3. Revisar el resultado del workflow `Pre Analysis`.
4. Abrir una Pull Request desde la rama `pre-*` hacia `main`.
5. Esperar a que se ejecuten los checks de Pull Request.
6. Integrar la Pull Request cuando los checks obligatorios esten en verde.
7. Tras el merge en `main`, se ejecuta el workflow de publicacion de imagen.

Las Pull Requests de Dependabot siguen el mismo control de entrada a `main`, pero se permiten desde ramas `dependabot/*`. La excepcion queda limitada por actor: la rama solo se acepta si la Pull Request la abre `dependabot[bot]`.

## Proteccion de `main`

La rama `main` se protege mediante una Branch protection rule.

Configuracion aplicada:

- Pull Request obligatoria antes del merge.
- Status checks obligatorios antes del merge.
- Allow force pushes: desactivado.
- Allow deletions: desactivado.

Checks obligatorios:

```text
Image Validation
Validate source branch
```

El control de entrada a `main` se basa en Pull Request obligatoria y checks requeridos en verde. De esta forma, los cambios manuales entran desde ramas `pre-*` y las actualizaciones automaticas entran desde ramas `dependabot/*`.

## Validacion rapida

Para comprobar que el flujo esta activo:

1. Crear una rama `pre-*`.
2. Hacer un cambio sencillo.
3. Subir la rama.
4. Abrir una Pull Request hacia `main`.
5. Comprobar que se ejecutan los checks obligatorios.

Si se intenta modificar `main` directamente, GitHub debe rechazar el push porque la rama esta protegida.

## Nota sobre disponibilidad

Branch protection depende de la configuracion y del plan disponible en GitHub. En este proyecto se usa una configuracion compatible con los controles requeridos por SecureKubeOps.
