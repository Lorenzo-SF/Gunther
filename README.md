# Gunther

Librería de Elixir para usar varios modelos de lenguaje configurados como si fueran uno: un enrutador decide a qué modelo va cada petición, con ranking, traza y failover. Los modelos pueden ser de nube, locales (gestionando su arranque y apagado) o de otro PC gestionado de forma remota.

**Estado**: en diseño. La especificación es `SPEC-000-GUNTHER_r7.md`; la documentación, `docs/00-indice.md`. No hay código publicado todavía.

**Qué no hace**: no descarga ni distribuye modelos ni binarios; no soporta Windows; no incluye ningún modelo decisor.

**Licencia**: Apache-2.0 (ver `LICENSE` y `NOTICE`). **Contribuciones**: por *issues* (ver `CONTRIBUTING.md`).
