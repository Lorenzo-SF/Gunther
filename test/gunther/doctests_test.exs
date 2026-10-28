defmodule Gunther.DoctestsTest do
  @moduledoc """
  Los doctests de todo el nucleo (SPEC §5.1, puerta G-11).

  ## Por que un unico fichero

  Un doctest que no se ejecuta es un doctest muerto: parece que hay
  documentacion verificada y no la hay. Este fichero declara **todos** los
  doctests del nucleo, para que ninguno se quede fuera por olvido.

  La lista se comprueba: `scripts/check_phase.sh` verifica que todo modulo
  de `lib/` con un `iex>` aparece aqui. Un doctest nuevo sin declarar aqui
  rompe la comprobacion.
  """

  use ExUnit.Case, async: true

  doctest Gunther.Cache

  doctest Gunther.Cache.Decisions

  doctest Gunther.Cancel

  doctest Gunther.Catalog

  doctest Gunther.Chunker

  doctest Gunther.Classifier

  doctest Gunther.Command

  doctest Gunther.Command.AllowList

  doctest Gunther.Command.Spawner

  doctest Gunther.Config

  doctest Gunther.Config.Loader

  doctest Gunther.Config.Validator

  doctest Gunther.Context

  doctest Gunther.Decision

  doctest Gunther.Decision.Parse

  doctest Gunther.Decision.Prompt

  doctest Gunther.DecisionSpec

  doctest Gunther.DecisionView

  doctest Gunther.Detector

  doctest Gunther.Doctor

  doctest Gunther.Detector.Cpu

  doctest Gunther.Detector.Engine

  doctest Gunther.Detector.Fabricante

  doctest Gunther.Detector.LlamaCpp

  doctest Gunther.Embedder

  doctest Gunther.Engine.Placement

  doctest Gunther.Engine.Placer

  doctest Gunther.Error

  doctest Gunther.Ggml.Type

  doctest Gunther.Gguf

  doctest Gunther.Guardrail

  doctest Gunther.Memory.Server

  doctest Gunther.Placement

  doctest Gunther.Provider

  doctest Gunther.Provider.Mock

  doctest Gunther.QueryRewriter

  doctest Gunther.Registry

  doctest Gunther.Reranker

  doctest Gunther.Resilience

  doctest Gunther.Resilience.Pipeline

  doctest Gunther.Resilience.Supervisor

  doctest Gunther.Resource.Ledger

  doctest Gunther.Resource.Weight

  doctest Gunther.Response

  doctest Gunther.Retriever

  doctest Gunther.Router

  doctest Gunther.Router.Embedding

  doctest Gunther.Router.Llm

  doctest Gunther.Router.Llm.Bulkhead

  doctest Gunther.Router.Requirements

  doctest Gunther.Router.Rules

  doctest Gunther.Selector

  doctest Gunther.Selector.Server

  doctest Gunther.SessionStore

  doctest Gunther.Store

  doctest Gunther.Telemetry.Bridge

  doctest Gunther.Tokenizer
end
