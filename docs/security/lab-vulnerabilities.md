# Datos de prueba y valores falsos

Este documento describe los valores de prueba utilizados en la API de referencia incluida en SecureKubeOps, la solución práctica del Trabajo Fin de Grado "Implementación de un ciclo de vida DevSecOps: Automatización de despliegues seguros y observabilidad en Kubernetes".

La finalidad de estos valores es apoyar futuras fases del pipeline DevSecOps, especialmente la detección de secretos o configuraciones sensibles, sin utilizar credenciales reales.

## Principios

- El repositorio no utiliza secretos reales.
- Las credenciales reales, tokens reales, claves privadas reales y contraseñas reales quedan fuera del repositorio.
- Los valores de prueba son claramente falsos.
- Cualquier valor con apariencia sensible queda documentado.
- La API de referencia funciona localmente sin depender de servicios externos reales.

## Valores actuales

El archivo `.env.example` incluye el siguiente valor falso:

```text
LAB_FAKE_API_KEY=lab_fake_key_do_not_use_12345
```

Este valor no concede acceso a ningún servicio, no corresponde a una credencial real y aparece únicamente como dato de laboratorio académico.

## Evolución prevista

En fases posteriores del TFG, este documento podrá ampliarse si se introducen ejemplos controlados para validar herramientas de análisis, detección de secretos o Security Gates.
