import Config

# La dependencia `opentelemetry` es opcional: sin `opentelemetry_exporter`
# instalada, su propio batch processor avisa en cada arranque de que no
# encuentra el modulo del exporter OTLP. El aviso es de la libreria, no de
# Gunther, y ensucia la salida de los tests.
#
# La integracion de Gunther con OpenTelemetry (D-88) se activa cuando el
# operador instala el exporter en su propia aplicacion; Gunther solo emite
# eventos de `:telemetry`, que cualquier exportador puede recoger.
config :opentelemetry,
  traces_exporter: :none
