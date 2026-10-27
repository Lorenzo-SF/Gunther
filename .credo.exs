%{
  # La lista de checks va DENTRO de cada config de `configs:`, no en la raiz.
  # En Credo 1.7 la forma de la raiz se fusiona con la config interna del
  # propio Credo (`deps/credo/.credo.exs`) de modo que los parametros de un
  # check los pisa la config de Credo y los del usuario se pierden. Con los
  # checks dentro de `configs:`, cada config se resuelve por separado y los
  # parametros se respetan.
  configs: [
    %{
      name: "default",
      files: %{
        included: ["lib/", "test/", "mix.exs"],
        excluded: []
      },
      strict: true,
      parse_timeout: 5_000,
      color: true,
      checks: [
        {Credo.Check.Consistency.ExceptionNames, []},
        {Credo.Check.Consistency.LineEndings, []},
        {Credo.Check.Consistency.ParameterPatternMatching, []},
        {Credo.Check.Consistency.SpaceAroundOperators, []},
        {Credo.Check.Consistency.SpaceInParentheses, []},
        {Credo.Check.Consistency.TabsOrSpaces, []},
        {Credo.Check.Consistency.UnusedVariableNames, []},
        {Credo.Check.Design.AliasUsage, [priority: :low, if_nested_deeper_than: 2, if_called_more_often_than: 2]},
        {Credo.Check.Readability.AliasOrder, []},
        {Credo.Check.Readability.BlockPipe, []},
        {Credo.Check.Readability.FunctionNames, []},
        {Credo.Check.Readability.LargeNumbers, []},
        {Credo.Check.Readability.MaxLineLength, [max_length: 120]},
        {Credo.Check.Readability.ModuleAttributeNames, []},
        {Credo.Check.Readability.ModuleDoc, []},
        {Credo.Check.Readability.MultiAlias, []},
        {Credo.Check.Readability.ParenthesesInCondition, []},
        {Credo.Check.Readability.PipeIntoAnonymousFunctions, []},
        {Credo.Check.Readability.PredicateFunctionNames, []},
        {Credo.Check.Readability.PreferImplicitTry, []},
        {Credo.Check.Readability.RedundantBlankLines, []},
        {Credo.Check.Readability.Semicolons, []},
        {Credo.Check.Readability.SinglePipe, []},
        {Credo.Check.Readability.Specs, [files: %{included: ["lib/"], excluded: []}]},
        {Credo.Check.Readability.StrictModuleLayout, []},
        {Credo.Check.Readability.WithSingleClause, []},
                # El validador de configuracion tiene una funcion por seccion del
        # esquema, y cada seccion es una cadena de validaciones: los valores
        # de ABC salen altos por el numero de asignaciones, no por la
        # complejidad del control. El umbral de 40 es el de Credo por
        # defecto, pensado para logica de negocio corriente.
        {Credo.Check.Refactor.ABCSize, [max_size: 200]},
        {Credo.Check.Refactor.Apply, []},
        {Credo.Check.Refactor.CaseTrivialMatches, []},
        {Credo.Check.Refactor.CyclomaticComplexity, [max_complexity: 25]},
        {Credo.Check.Refactor.FilterCount, []},
        {Credo.Check.Refactor.FilterFilter, []},
        {Credo.Check.Refactor.FunctionArity, []},
        {Credo.Check.Refactor.MapJoin, []},
        {Credo.Check.Refactor.MapMap, []},
        {Credo.Check.Refactor.NegatedConditionsInUnless, []},
        {Credo.Check.Refactor.NegatedConditionsWithElse, []},
        {Credo.Check.Refactor.RedundantWithClauseResult, []},
        {Credo.Check.Refactor.RejectReject, []},
        {Credo.Check.Refactor.UnlessWithElse, []},
        {Credo.Check.Refactor.WithClauses, []},
        # `Gunther.Config` tiene un campo por seccion del esquema (34 en
        # total): es la forma del dato, no un defecto de diseno. El umbral
        # de 31 es el de Credo por defecto, pensado para structs de negocio.
        {Credo.Check.Warning.StructFieldAmount, [max_fields: 40]},
        {Credo.Check.Warning.Dbg, []},
        {Credo.Check.Warning.IExPry, []},
        {Credo.Check.Warning.SpecWithStruct, []},
        {Credo.Check.Warning.UnsafeExec, []}
      ]
    }
  ]
}
