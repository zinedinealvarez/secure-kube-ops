# Flujo de ramas

El repositorio de SecureKubeOps utiliza un flujo de ramas simple con dos ramas:

- `pre`: rama de trabajo y validación. En esta rama se trabaja directamente y se permite hacer push.
- `main`: rama de producción. Esta rama está protegida mediante una Branch protection rule.

## Flujo de trabajo

El flujo operativo funciona así:

1. Los cambios se hacen directamente en `pre`.
2. Se hace push a `pre`.
3. Se abre una Pull Request desde `pre` hacia `main`.
4. `main` solo se actualiza mediante Pull Request.
5. El merge a `main` se realiza cuando pasan los checks obligatorios de GitHub Actions.

No se utilizan ramas `develop`, `feature/*` ni una tercera rama principal.

## Protección de `main`

La rama `main` está protegida mediante una Branch protection rule.

La regla está configurada con:

- Pull Request obligatoria antes del merge.
- `Required approvals`: `0`.
- Status checks obligatorios antes del merge.
- Rama actualizada antes del merge.
- Método de merge: `Squash`.
- Bloqueo de force push.
- Borrado de rama desactivado.

Checks obligatorios configurados:

```text
DevSecOps checks
Validate source branch
```

## Validación del bloqueo de push directo

El bloqueo de push directo a `main` se validó correctamente. Al intentar hacer push directo a la rama protegida, GitHub devolvió el siguiente error:

```text
GH006: Protected branch update failed for refs/heads/main.
Changes must be made through a pull request.
2 of 2 required status checks are expected.
```

Este resultado confirma que `main` queda protegida y que los cambios entran mediante Pull Request desde `pre`.

## Nota sobre disponibilidad de Branch protection

Para que la protección de ramas se aplicase en el entorno del TFG, el repositorio funcionó en modo público o con un plan de GitHub compatible con Branch protection en repositorios privados.
