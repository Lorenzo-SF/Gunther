#!/usr/bin/env bash
#
# Lectura de las cosas que NO son la tabla de AC.
#
# La tabla de AC la lee **solo** `check_ac.sh`, y su estado sale de su modo
# `--machine`. Aqui no se parsea ninguna fila de AC a proposito: dos
# lectores de la misma tabla divergen, y uno acaba contando AC que el otro
# no ve. Lo que hay en este fichero son las tablas nuevas y las fuentes de
# verdad de la cola.
#
# ## De donde sale la cola de trabajo
#
# Tres fuentes, tres cosas distintas:
#
# 1. **Que fase toca** (`nota_orden_fases` + `nota_fases_cerradas`): el plan
#    de desarrollo dice el orden, y el registro de fases dice cuales estan
#    cerradas. El primero que no esta cerrada es el que toca.
#
# 2. **Que WP hay** (`nota_wps_del_plan`): el plan de desarrollo, seccion 4.
#
# 3. **Que AC cierra cada WP** (`nota_filas_wp`): la nota de fase. El plan
#    NO lo dice, y la nota no lo duplica: la nota dice que AC cierra cada
#    WP, el plan dice que hace cada WP. Son cosas distintas.
#
# ## Los dos espacios de nombres, y por que no se parecen
#
# En el repositorio hay dos cosas distintas con nombres parecidos, y el
# modelo las confunde. Ahora cada una tiene una forma que no se puede
# confundir con la otra:
#
#   * **WP** (paquete de trabajo, en el plan y en la nota): `Fnn-nn`,
#     con dos digitos (`F3-04`). Es una unidad de trabajo: un commit.
#   * **AC** (criterio de aceptacion, en la nota): `Fnn-ACn`, con el
#     infijo `AC` (`F3-AC4`). Es una condicion que hay que comprobar: un
#     test.
#
# Antes, el WP del plan era `F3-01` y el AC de la nota `F3-1`: la misma
# forma con un digito de diferencia. Un modelo que las mezclaba cerraba el
# AC equivocado y declaraba un WP terminado sin haberlo hecho. **Un
# identificador que se parece a otro es un error esperando a pasar.**
#
# Los WP del plan **no se renombran**: el SPEC §19.2 los cita (`F1-01`,
# `F4-03`, `F4-04`) y el SPEC es la ley. Los AC de las notas si: son
# ids locales de la nota, y ahi es donde se separan.
#
# ## Por que la tabla de WP tiene tres celdas y la de AC cuatro
#
# El numero de celdas **no coincide nunca**, asi que es un discriminante
# fiable. Y ahora que los identificadores tienen formas distintas, el
# formato del identificador es un discriminante *todavia mas* fuerte: una
# fila de tres celdas cuyo identificador no es de WP es un error, y se
# dice, en vez de saltarsela.
#
#     | WP | Dependencias | AC que cierra |     <- tres celdas
#     | F3-01 | — | F3-AC1, F3-AC2 |
#
#     | # | AC | Test que lo verifica | En |    <- cuatro celdas
#     | F3-AC1 | ... | `test/...exs` · "nombre" | F3 |
#
# Las cabeceras y las separadoras quedan fuera por el formato del
# identificador: solo cuentan las filas cuyo primer campo es `F<numero>-`.

# Quita los espacios de los dos extremos de una cadena.
nota_trim() {
  printf '%s' "$1" | sed 's/^ *//; s/ *$//'
}

# El cuerpo de una fila de tabla: sin el pipe inicial ni el final.
nota_celdas() {
  local linea="$1" cuerpo
  cuerpo="${linea#|}"
  cuerpo="${cuerpo%|}"
  printf '%s' "$cuerpo"
}

# Cuantas celdas tiene una fila de tabla.
nota_num_celdas() {
  local cuerpo="$1" n=1 resto="$1"
  while case "$resto" in *"|"*) true ;; *) false ;; esac; do
    resto="${resto#*|}"
    n=$((n + 1))
  done
  printf '%s' "$n"
}

# Un identificador de AC: `F<numero>-AC<numero>`, con sufijo opcional de
# letra (`F1-AC7a`, `F1-AC8b`). **No** acepta un identificador de WP.
nota_es_id() {
  [[ "$1" =~ ^F[0-9]+-AC[0-9]+[a-z]?$ ]]
}

# Un identificador de WP: `F<numero>-<numero>`, con **dos** digitos
# (`F3-04`). Los dos digitos son lo que lo separa del AC: un AC lleva el
# infijo `AC`. **No** acepta un identificador de AC.
nota_es_id_wp() {
  [[ "$1" =~ ^F[0-9]+-[0-9][0-9]$ ]]
}

# Un valor de la columna "En" de la tabla de AC: el nombre de una fase
# (`F3`, `**F3**`), o las dos marcas que dicen que el AC no se cumple aqui
# (`BLOQUEADA`, `PENDIENTE`).
#
# Sirve para **rechazar** las filas que no son de AC: una fila de WP tiene
# en esa posicion una lista de AC (`F3-AC1, F3-AC2`), que no es un valor de
# "En". Un checker que se come una fila sin decir nada es un checker con
# OK falso.
nota_es_valor_en() {
  local v="$1"
  case "$v" in
    BLOQUEADA|PENDIENTE) return 0 ;;
  esac
  [[ "$v" =~ ^\**F[0-9]+\**$ ]]
}

# Valida que **toda** fila `| F<numero>-` de la nota sea reconocible: o
# una fila de AC (cuatro celdas, con un valor valido en "En") o una fila de
# WP (tres celdas).
#
# Devuelve 1 y explica cual es la fila mala. Un checker que se come una
# fila sin decir nada es un checker con OK falso: contaria menos AC de los
# que hay, y la fase "se cerraria" sin haberlos comprobado.
nota_validar_filas() {
  local fichero="$1"
  local linea cuerpo n en_valor id

  [ -f "$fichero" ] || return 0

  while IFS= read -r linea || [ -n "$linea" ]; do
    case "$linea" in
      "| F"[0-9]"-"*) ;;
      *) continue ;;
    esac

    cuerpo="$(nota_celdas "$linea")"
    n="$(nota_num_celdas "$cuerpo")"

    id="$(printf '%s' "$cuerpo" | awk -F'|' '{gsub(/^ +| +$/, "", $1); print $1}')"

    case "$n" in
      3)
        # Fila de WP: el identificador tiene que ser de WP (`F3-04`).
        # Una fila de tres celdas con un identificador de AC es un error:
        # es una tabla mal escrita, y saltarsela en silencio contaria AC
        # que no existen.
        if ! nota_es_id_wp "$id"; then
          echo "Fila de WP con un identificador que no es de WP en $fichero: \"$id\"" >&2
          echo "  (un WP se escribe F<numero>-<numero>, un AC F<numero>-AC<numero>)" >&2
          echo "  $linea" >&2
          return 1
        fi
        continue
        ;;
      4) ;;
      *)
        echo "Fila no reconocida en $fichero: $n celdas (se esperaban 3 para un WP o 4 para un AC):" >&2
        echo "  $linea" >&2
        return 1
        ;;
    esac

    # Fila de AC: el identificador tiene que ser de AC (`F3-AC1`), nunca de
    # WP. Un AC con nombre de WP no se comprueba: y un AC que no se
    # comprueba es una fase que se cierra sin haberla comprobado.
    if ! nota_es_id "$id"; then
      echo "Fila de AC con un identificador que no es de AC en $fichero: \"$id\"" >&2
      echo "  (un AC se escribe F<numero>-AC<numero>, un WP F<numero>-<numero>)" >&2
      echo "  $linea" >&2
      return 1
    fi

    en_valor="$(printf '%s' "$cuerpo" | awk -F'|' '{gsub(/^ +| +$/, "", $4); print $4}')"
    if ! nota_es_valor_en "$en_valor"; then
      echo "Fila de AC con un valor no valido en la columna \"En\" en $fichero: \"$en_valor\"" >&2
      echo "  $linea" >&2
      return 1
    fi
  done < "$fichero"

  return 0
}

# Las filas de la tabla de WP de una nota de fase: el WP, de que depende y
# que AC cierra.
#
#     id <TAB> dependencias <TAB> lista de AC
nota_filas_wp() {
  local fichero="$1"
  local linea cuerpo id deps acs

  [ -f "$fichero" ] || return 0

  while IFS= read -r linea || [ -n "$linea" ]; do
    case "$linea" in
      "| F"[0-9]"-"*) ;;
      *) continue ;;
    esac

    cuerpo="$(nota_celdas "$linea")"

    # Tres celdas: la tabla de WP. La de AC tiene cuatro.
    [ "$(nota_num_celdas "$cuerpo")" = "3" ] || continue

    IFS='|' read -r id deps acs <<< "$cuerpo"
    id="$(nota_trim "$id")"
    nota_es_id_wp "$id" || continue

    printf '%s\t%s\t%s\n' \
      "$id" \
      "$(nota_trim "$deps")" \
      "$(nota_trim "$acs")"
  done < "$fichero"
}

# Los WP de una fase y su contenido, tal como los define el plan de
# desarrollo (`docs/01-plan-de-desarrollo.md`, seccion 4).
#
#     id <TAB> contenido <TAB> pruebas minimas
nota_wps_del_plan() {
  local fichero="$1" fase="$2"
  local linea cuerpo id contenido pruebas
  local in_fase=0

  [ -f "$fichero" ] || return 0

  while IFS= read -r linea || [ -n "$linea" ]; do
    case "$linea" in
      "### $fase "*) in_fase=1 ;;
      "### "*) in_fase=0 ;;
    esac
    [ "$in_fase" = "1" ] || continue

    case "$linea" in
      "| $fase-"*) ;;
      *) continue ;;
    esac

    cuerpo="$(nota_celdas "$linea")"
    IFS='|' read -r id contenido pruebas <<< "$cuerpo"
    id="$(nota_trim "$id")"

    # Del plan solo se aceptan filas de WP: una fila con otro identificador
    # no es un WP, y meterla en la cola seria inventar una tarea.
    nota_es_id_wp "$id" || continue

    printf '%s\t%s\t%s\n' \
      "$(nota_trim "$id")" \
      "$(nota_trim "$contenido")" \
      "$(nota_trim "$pruebas")"
  done < "$fichero"
}

# El orden de fases recomendado para una sola persona, tal como lo escribe
# el plan de desarrollo. Una fase por linea.
#
# Sale de la frase "Orden recomendado para una sola persona" del plan. Es
# el orden que el dueño escribio, no uno que este script se inventaria: un
# script que decide el orden de las fases es un script que decide cosas del
# dueno.
nota_orden_fases() {
  local fichero="$1"
  local linea

  [ -f "$fichero" ] || return 0

  while IFS= read -r linea || [ -n "$linea" ]; do
    case "$linea" in
      *"Orden recomendado para una sola persona"*) ;;
      *) continue ;;
    esac

    # La lista esta antes del "Motivo:".
    printf '%s' "${linea%%Motivo:*}" |
      grep -oE 'F[0-9]+' |
      awk '!v[$0]++'
    return 0
  done < "$fichero"
}

# Las fases ya cerradas, segun el registro de fases.
#
# Una fase esta cerrada cuando su fila del registro tiene una FECHA de fin
# en la columna "Fin". La palabra "en curso" no es una fecha: una fase en
# curso no esta cerrada.
nota_fases_cerradas() {
  local fichero="$1"
  local linea cuerpo id inicio fin

  [ -f "$fichero" ] || return 0

  while IFS= read -r linea || [ -n "$linea" ]; do
    case "$linea" in
      "| **F"[0-9]"**"*) ;;
      *) continue ;;
    esac

    # Las celdas: | **F1** | inicio | fin | ...
    cuerpo="$(nota_celdas "$linea")"
    IFS='|' read -r id inicio fin _ <<< "$cuerpo"

    # Una fecha de fin es un dia: AAAA-MM-DD. Las comillas del markdown
    # (`**2026-10-28**`) no cuentan.
    case "$(nota_trim "$fin" | tr -d '*')" in
      [0-9][0-9][0-9][0-9]-[0-9][0-9]-[0-9][0-9]) ;;
      *) continue ;;
    esac

    printf '%s\n' "$(nota_trim "$id" | tr -d '*')"
  done < "$fichero"
}
