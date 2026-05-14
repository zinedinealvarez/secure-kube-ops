# Flujo de ramas

El repositorio de SecureKubeOps utiliza un flujo de ramas simple basado en ramas de validación con prefijo `pre-` y una rama de producción `main`.

- `pre-*`: ramas de trabajo y validación. En estas ramas se trabaja directamente y se permite hacer push.
- `main`: rama de producción. Esta rama está protegida mediante una Branch protection rule.

## Flujo de trabajo

El flujo operativo funciona así:

1. Los cambios se hacen directamente en una rama con prefijo `pre-`, por ejemplo `pre-observability` o `pre-pipeline`.
2. Se hace push a esa rama `pre-*`.
3. Se abre una Pull Request desde la rama `pre-*` hacia `main`.
4. `main` solo se actualiza mediante Pull Request.
5. El merge a `main` se realiza cuando pasan los checks obligatorios de GitHub Actions.

## Protección de `main`

La rama `main` está protegida mediante una Branch protection rule.

La regla está configurada con:

- Pull Request obligatoria antes del merge.
- Aprobaciones requeridas: desactivado.
- Status checks obligatorios antes del merge.
- Rama actualizada antes del merge: desactivado.
- Allow force pushes: desactivado.
- Allow deletions: desactivado.

Checks obligatorios configurados:

```text
Image Validation
Validate source branch
```

La opción equivalente a `Require branches to be up to date before merging` queda desactivada. Durante la validación del flujo generaba bloqueos del tipo `This branch is out-of-date with the base branch`, especialmente después de merges que actualizaban la rama base y dejaban la Pull Request pendiente de sincronización. El control de entrada a `main` se mantiene mediante Pull Request obligatoria y checks requeridos en verde.

## Validación del bloqueo de push directo

El bloqueo de push directo a `main` se validó correctamente. Al intentar hacer push directo a la rama protegida, GitHub devolvió el siguiente error:

```text
GH006: Protected branch update failed for refs/heads/main.
Changes must be made through a pull request.
2 of 2 required status checks are expected.
```

Este resultado confirma que `main` queda protegida y que los cambios entran mediante Pull Request desde ramas con prefijo `pre-`.

## Nota sobre disponibilidad de Branch protection

Para que la protección de ramas se aplicase en el entorno del TFG, el repositorio funcionó en modo público o con un plan de GitHub compatible con Branch protection en repositorios privados.
