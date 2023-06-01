defmodule Nomenclatura do
  @moduledoc """
  Tiny library providing functions to easily deal with named processes.
  """

  @default_fqn (case Application.compile_env(:nomenclatura, :otp_app) do
                  nil -> nil
                  name when is_atom(name) -> name |> to_string() |> Macro.camelize()
                end)

  @typedoc "The possible types for the domain"
  @type domain :: nil | binary() | module()

  @doc """
  Builds the fully-qualified name for the non-fqn name given as the second parameter.

  ### Examples

      iex> Nomenclatura.fqn(Foo)
      Foo
      iex> Nomenclatura.fqn(Bar.Baz, Foo)
      Bar.Baz.Foo
      iex> Nomenclatura.fqn(Bar.Baz, :foo_1)
      Bar.Baz.Foo1
  """
  @spec fqn(domain(), module() | binary()) :: module()
  def fqn(domain \\ @default_fqn, name)
  def fqn(domain, name) when is_atom(name), do: fqn(domain, Atom.to_string(name))
  def fqn(domain, "Elixir." <> name), do: fqn(domain, name)
  def fqn(domain, name) when is_binary(name), do: Module.concat([domain, Macro.camelize(name)])

  @doc """
  Builds `{:global, _}` tuple based on the domain name and optional `registry`.

  ### Examples

      iex> Nomenclatura.global(Bar.Baz, Worker42)
      {:global, Bar.Baz.Worker42}
      iex> Nomenclatura.global(Bar.Baz, :worker_42)
      {:global, Bar.Baz.Worker42}
      iex> Nomenclatura.global(Bar.Baz, 42)
      {:global, {Bar.Baz, 42}}
  """
  @spec global(domain(), module() | binary() | term()) :: {:global, module()}
  def global(domain \\ @default_fqn, name)

  def global(domain, name) when is_atom(name) when is_binary(name),
    do: {:global, fqn(domain, name)}

  def global(domain, name), do: {:global, {domain, name}}

  @doc """
  Builds `{:via, _, _}` tuple based on the domain name and optional `registry`.

  ### Examples

      iex> Nomenclatura.via(Bar.Baz, :worker_1)
      {:via, Registry, {Bar.Baz.Registry, :worker_1}}
      iex> Nomenclatura.via(Bar.Baz, "Reg", :worker_2)
      {:via, Registry, {Bar.Baz.Reg, :worker_2}}
      iex> Nomenclatura.via(Bar.Baz, "Reg", MyRegistry, :worker_2)
      {:via, MyRegistry, {Bar.Baz.Reg, :worker_2}}
  """
  @spec via(domain(), domain(), module(), term()) :: {:via, module(), term()}
  def via(domain \\ @default_fqn, registry \\ "Registry", dispatcher \\ Registry, term),
    do: {:via, dispatcher, {fqn(domain, registry), term}}

  @doc """
  Builds `Process.dest` tuple for the remote dispatch.

  ### Examples

      iex> {Bar.Baz.Foo, pid} = Nomenclatura.remote(Bar.Baz, Foo, self())
      ...> pid == self()
      true
  """
  @spec remote(domain(), module() | binary(), node()) :: {atom(), node()}
  def remote(domain \\ @default_fqn, name, node \\ self()),
    do: {fqn(domain, name), node}

  @doc """
  Starts the named `GenServer` or `Supervisor` as a singleton within the cluster.

  ### Examples

      iex> child_spec = {Agent, fn -> %{} end}
      ...> {:ok, pid1} = Nomenclatura.start_link_singleton(Bar.Baz, Foo, child_spec)
      ...> {:ok, pid2} = Nomenclatura.start_link_singleton(Bar.Baz, Foo, child_spec)
      ...> pid1 == pid2
      true
      ...> {:ok, pid3} = Nomenclatura.start_link_singleton(Bar.Baz.Foo, child_spec)
      ...> pid1 == pid3
      true
  """
  @spec start_link_singleton(
          domain(),
          module() | binary(),
          Supervisor.child_spec()
          | {module(), term()}
          | module()
          | (old_erlang_child_spec :: :supervisor.child_spec())
        ) :: Supervisor.on_start()
  def start_link_singleton(domain \\ @default_fqn, name, child_spec) do
    name = global(domain, name)

    [child_spec]
    |> Supervisor.start_link(strategy: :one_for_one, name: name)
    |> case do
      {:error, {:already_started, pid}} -> {:ok, pid}
      other -> other
    end
  end
end
