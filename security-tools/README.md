# Herramientas de seguridad del pipeline

Esta carpeta agrupa configuración propia de herramientas de seguridad usadas por los workflows.

| Archivo | Uso |
| --- | --- |
| `gitleaks.toml` | Configuración de GitLeaks para detección de secretos. |
| `semgrep.yml` | Reglas locales de Semgrep para análisis estático. |

## Dependabot

Dependabot no se mueve a esta carpeta porque GitHub exige que su configuración esté en:

```text
.github/dependabot.yml
```

Por tanto, aunque forma parte del bloque de mantenimiento y seguridad de dependencias, su ubicación viene impuesta por la plataforma.
