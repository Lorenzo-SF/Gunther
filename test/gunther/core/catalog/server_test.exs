defmodule Gunther.Catalog.ServerTest do
  use ExUnit.Case, async: false

  alias Gunther.Catalog
  alias Gunther.Catalog.Server
  alias Gunther.Config
  alias Gunther.Error

  defp unique(prefix), do: :"#{prefix}_#{System.unique_integer([:positive])}"

  defp config(extra) do
    Map.merge(
      %{
        "gunther" => %{"instance_id" => "main"},
        "models" => [%{"alias" => "qwen", "provider" => "llamacpp", "model_id" => "x"}]
      },
      extra
    )
  end

  defp start_servers(extra) do
    config_server = unique(:config)
    catalog_server = unique(:catalog)
    cache_server = unique(:cache)

    {:ok, _} = Config.Server.start_link(name: config_server, config: config(extra))

    {:ok, _} =
      Gunther.Cache.Decisions.start_link(name: cache_server, cache_name: unique(:cache_ets))

    {:ok, _} =
      Server.start_link(
        name: catalog_server,
        config_server: config_server,
        cache_server: cache_server
      )

    {config_server, catalog_server, cache_server}
  end

  describe "reload/1" do
    test "reconstruye el catalogo desde la configuracion activa" do
      {_config_server, catalog_server, _cache_server} = start_servers(%{})

      assert :ok = Server.reload(catalog_server)

      catalog = Server.get(catalog_server)
      assert catalog != nil
      assert Catalog.list(catalog) == [:qwen]
    end

    test "sin configuracion activa devuelve un error, no una excepcion" do
      catalog_server = unique(:catalog)
      {:ok, _} = Server.start_link(name: catalog_server, config_server: :no_existe)

      assert {:error, %Error{code: :config_error}} = Server.reload(catalog_server)
    end

    test "el catalogo anterior se conserva si la recarga falla" do
      {_config_server, catalog_server, _cache_server} = start_servers(%{})

      Server.reload(catalog_server)
      before = Server.get(catalog_server)

      assert {:error, %Error{code: :config_error}} =
               Server.reload(catalog_server, :no_existe)

      assert Server.get(catalog_server) == before
    end

    test "reload/1 vacia la cache de decisiones" do
      {_config_server, catalog_server, cache_server} = start_servers(%{})

      Gunther.Cache.Decisions.put(cache_server, "clave", [:a])
      assert {:ok, [:a]} = Gunther.Cache.Decisions.get(cache_server, "clave")

      Server.reload(catalog_server)

      assert :error = Gunther.Cache.Decisions.get(cache_server, "clave")
    end
  end

  describe "hash/1" do
    test "devuelve el hash del catalogo activo" do
      {_config_server, catalog_server, _cache_server} = start_servers(%{})

      Server.reload(catalog_server)

      assert is_binary(Server.hash(catalog_server))
    end

    test "sin catalogo devuelve una cadena vacia" do
      catalog_server = unique(:catalog)
      {:ok, _} = Server.start_link(name: catalog_server)

      assert Server.hash(catalog_server) == ""
    end

    test "el hash cambia si cambian las reglas" do
      {_config_server, catalog_server, _cache_server} = start_servers(%{})
      Server.reload(catalog_server)
      before = Server.hash(catalog_server)

      other_config = unique(:otro_config)

      {:ok, _} =
        Config.Server.start_link(
          name: other_config,
          config:
            config(%{
              "rules" => [
                %{"name" => "v", "action" => "veto", "target" => %{"locality" => "cloud"}}
              ]
            })
        )

      Server.reload(catalog_server, other_config)

      refute Server.hash(catalog_server) == before
    end
  end
end
