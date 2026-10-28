[
  inputs: ["{mix,.formatter}.exs", "{config,lib,test}/**/*.{ex,exs}"],
  line_length: 120,
  locals_without_parens: [
    # Structs del dominio: se construyen sin parentesis en las Pipes
    alias: false,
    import: false
  ]
]
