# `Trebejo.OS` degrada en silencio cuando el shell escribe en la salida

- **Repositorio afectado**: `Lorenzo-SF/trebejo` (con `Lorenzo-SF/arrea` en
  el origen del efecto)
- **Descubierto**: al escribir el detector de CPU de Gunther (2026-10-28),
  ver `docs/fases/F2.md`
- **Impacto en Gunther**: `Gunther.Detector.Cpu` recibia lecturas **falsas**
  sin ningun aviso
- **Estado**: abierto

## El problema

`Trebejo.OS` ejecuta sus comandos de sistema por un shell (a traves de
`Trebejo.SafeCommand` → `Arrea.Command`). Si ese shell escribe **algo** en la
salida, el valor que Gunther lee queda **contaminado**, y `Trebejo.OS` no lo
dice: degrada en silencio a un valor por defecto.

Medido en un contenedor sin `~/.bashrc` (el caso real: cualquier imagen de
contenedor minima):

```
$ id -u                          # 0 (root)
$ Trebejo.OS.root?()             #=> false
$ uname -m                       # x86_64
$ Trebejo.OS.arch()              #=> :unknown
$ nproc                          # 2
$ Trebejo.OS.cpu_count()         #=> 1
```

El mecanismo, exacto:

1. `Arrea.Command` ejecuta por un shell que **carga el `.bashrc`**.
2. Si el `.bashrc` **no existe**, el shell escribe el error **en el stdout**:
   `/bin/bash: line 1: /root/.bashrc: No such file or directory`.
3. `Trebejo.OS` parsea el stdout **completo**: `"<error>\nx86_64\n"`.
4. El parseo falla y cada función cae a su valor por defecto:
   - `arch/0` → `:unknown` (el `uname` real nunca sale);
   - `cpu_count/0` → `System.schedulers_online()` (los cores del BEAM, no
     los del sistema);
   - `root?/0` → `false`.

Con un `.bashrc` (aunque este vacio) las tres vuelven a dar bien. El valor
por defecto es, de hecho, el correcto: **lo unico que falla es el aviso**.

## Por que importa

1. **El fallo es silencioso por completo.** No hay error, ni aviso, ni
   excepcion: hay un `false` y un `:unknown` que parecen una verdad.
2. **Los tres valores por defecto son plausibles.** `cpu_count: 1` es
   creible (una maquina de un core). `arch: :unknown` esta en la lista de
   valores que el propio modulo declara. `root?: false` es lo que dice una
   maquina normal. Nada delata el fallo.
3. **Afecta a cualquier consumidor, no solo a Gunther.** `Trebejo.OS` es la
   lectura de sistema de todo el ecosistema.
4. **El caso de uso mas probable es el peor**: un contenedor, un runner de
   CI, un entorno de pruebas. Es exactamente donde no hay `.bashrc`.

## Lo que se pide

En `trebejo` (con la parte de `arrea` que corresponda):

1. **No mezclar la salida del shell con la del comando.** La opcion mas
   limpia: que `Arrea.Command` ejecute **sin cargar el `.bashrc`**, o que lo
   cargue con la salida de diagnostico separada. Un comando de medicion no
   necesita el perfil del usuario: `uname -m` y `id -u` no dependen de el.
2. **O, si el shell se mantiene, parsear la ultima linea** y no el stdout
   entero, y **distinguir "no se pudo leer" de "el valor es este"**.
3. **Devolver el fallo, no el valor por defecto.** `Trebejo.OS.arch/0` que
   devuelve `:unknown` deberia poder distinguirse de "esta arquitectura no la
   conozco". Hoy no hay forma, y por eso el consumidor no puede saber si
   `:unknown` es un dato o un fallo.
4. **Un test que lo cubra**, con el `.bashrc` ausente o con el shell
   escribiendo algo en la salida. El fallo se reproduce con un `.bashrc` que
   no existe, que es el caso mas comun.

## Lo que hace Gunther mientras tanto

`Gunther.Detector.Cpu` no publica como dato lo que no se ha podido leer:

- si la lectura no es creible (la arquitectura sale `:unknown` o la memoria
  sale 0), el device va con `usable: false` y `reason: :memory_unknown`, y
  los datos que no se pudieron leer van a `nil`;
- un device con `usable: false` no entra en el reparto, asi que un dato falso
  no llega a ninguna decision;
- la lectura del sistema es **inyectable** (`opts[:os]`), asi que los tests
  del detector no dependen de la maquina en la que corren.

Eso protege a Gunther, pero no arregla `Trebejo.OS`: el valor falso sigue
saliendo de la libreria.
