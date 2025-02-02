defmodule Rclex.ResourceServer do
  alias Rclex.Nifs
  require Logger
  use GenServer, restart: :transient

  @type context :: any()

  @moduledoc """
      T.B.A
  """
  @spec start_link(any()) :: GenServer.on_start()
  def start_link(_) do
    GenServer.start_link(__MODULE__, {}, name: ResourceServer)
  end

  @doc """
      ResourceServerプロセスの初期化
      状態:
          supervisor_ids :: map()
          keyがnode_identifer、valueがnode情報。現在はnodeプロセスのsupervisorのidを格納している
  """
  @impl GenServer
  def init(_) do
    {:ok, {%{}}}
  end

  @doc """
      ノードをひとつだけ作成
      名前空間の有無を設定可能
      返り値:
          node_identifier :: string()
          作成したノードプロセスのnameを返す
  """
  @spec create_node(context(), charlist(), integer(), (list() -> list())) :: term()
  def create_node(context, node_name, queue_length \\ 1, change_order \\ & &1) do
    create_node_with_namespace(context, node_name, '', queue_length, change_order)
  end

  @spec create_node_with_namespace(
          context(),
          charlist(),
          charlist(),
          integer(),
          (list() -> list())
        ) :: term()
  def create_node_with_namespace(
        context,
        node_name,
        node_namespace,
        queue_length \\ 1,
        change_order \\ & &1
      ) do
    {:ok, [node]} =
      GenServer.call(
        ResourceServer,
        {:create_nodes, {context, node_name, node_namespace, 1, {queue_length, change_order}}}
      )

    {:ok, node}
  end

  @doc """
      複数ノード生成
      create_nodes/4ではcreate_nodes/3に加えて名前空間の指定が可能
      返り値:
          node_identifier_list :: Enumerable.t()
          作成したノードプロセスのnameのリストを返す
  """
  @spec create_nodes(context(), charlist(), integer(), integer(), (list() -> list())) :: term()
  def create_nodes(context, node_name, num_node, queue_length \\ 1, change_order \\ & &1) do
    create_nodes_with_namespace(context, node_name, '', num_node, queue_length, change_order)
  end

  @spec create_nodes_with_namespace(
          context(),
          charlist(),
          charlist(),
          integer(),
          integer(),
          (list() -> list())
        ) :: term()
  def create_nodes_with_namespace(
        context,
        node_name,
        node_namespace,
        num_node,
        queue_length \\ 1,
        change_order \\ & &1
      ) do
    GenServer.call(
      ResourceServer,
      {:create_nodes,
       {context, node_name, node_namespace, num_node, {queue_length, change_order}}}
    )
  end

  @spec create_timer(function(), any, integer(), charlist(), integer(), (list() -> list())) :: any
  def create_timer(
        call_back,
        args,
        time,
        timer_name,
        queue_length \\ 1,
        change_order \\ & &1
      ) do
    create_timer_with_limit(call_back, args, time, timer_name, 0, queue_length, change_order)
  end

  @spec create_timer_with_limit(
          function(),
          any,
          integer(),
          charlist(),
          integer(),
          integer(),
          (list() -> list())
        ) :: any
  def create_timer_with_limit(
        call_back,
        args,
        time,
        timer_name,
        limit,
        queue_length \\ 1,
        change_order \\ & &1
      ) do
    GenServer.call(
      ResourceServer,
      {:create_timer, {call_back, args, time, timer_name, limit, {queue_length, change_order}}}
    )
  end

  @spec stop_timer(charlist()) :: any
  @doc """
      タイマープロセスを削除する
      入力
          timer_identifier :: ()
          削除するタイマープロセスの識別子
          {:global, timer_identifier}がタイマープロセス名になる
  """
  def stop_timer(timer_identifier) do
    GenServer.call(ResourceServer, {:stop_timer, timer_identifier})
  end

  @spec finish_node(charlist()) :: any
  @doc """
      ノードプロセスを削除する
      入力
          node_identifier :: string()
          削除するnodeのプロセス名
  """
  def finish_node(node_identifier) do
    GenServer.call(ResourceServer, {:finish_node, node_identifier})
  end

  @spec finish_nodes([charlist()]) :: list
  def finish_nodes(node_identifier_list) do
    Enum.map(
      node_identifier_list,
      fn node_identifier -> GenServer.call(ResourceServer, {:finish_node, node_identifier}) end
    )
  end

  @impl GenServer
  def handle_call(
        {:create_nodes, {context, node_name, namespace, num_node, executor_settings}},
        _from,
        {resources}
      ) do
    node_identifier_list =
      0..(num_node - 1)
      |> Enum.map(fn node_no ->
        get_identifier(namespace, node_name) ++ Integer.to_charlist(node_no)
      end)

    unless node_identifier_list
           |> Enum.any?(&Map.has_key?(resources, &1)) do
      # 同名のノードがすでに存在しているときはエラーを返す
      {:reply, {:error, node_identifier_list}}
    end

    nodes_list =
      node_identifier_list
      # id -> {node, id}
      |> Enum.map(fn node_identifier ->
        {call_nifs_rcl_node_init(
           Nifs.rcl_get_zero_initialized_node(),
           node_identifier,
           namespace,
           context,
           Nifs.rcl_node_get_default_options()
         ), node_identifier}
      end)
      # {node, id} -> {id, {:ok, pid}}
      |> Enum.map(fn {node, node_identifier} ->
        {node_identifier,
         Supervisor.start_link(
           [{Rclex.Node, {node, node_identifier, executor_settings}}],
           strategy: :one_for_one
         )}
      end)
      # {id, {:ok, pid}} -> {id, pid}
      |> Enum.map(fn {node_identifier, {:ok, pid}} ->
        {node_identifier, %{supervisor_id: pid}}
      end)

    new_resources = for {k, v} <- nodes_list, into: resources, do: {k, v}

    {:reply, {:ok, node_identifier_list}, {new_resources}}
  end

  @impl GenServer
  def handle_call(
        {:create_timer, {call_back, args, time, timer_name, limit, executor_settings}},
        _from,
        {resources}
      ) do
    timer_identifier = "#{timer_name}/Timer"

    if Map.has_key?(resources, {"", timer_identifier}) do
      # 同名のノードがすでに存在しているときはエラーを返す
      {:reply, {:error, timer_name}}
    else
      children = [
        {Rclex.Timer, {call_back, args, time, timer_name, limit, executor_settings}}
      ]

      opts = [strategy: :one_for_one]
      {:ok, pid} = Supervisor.start_link(children, opts)
      new_resources = Map.put_new(resources, timer_identifier, %{supervisor_id: pid})
      {:reply, {:ok, timer_identifier}, {new_resources}}
    end
  end

  @impl GenServer
  def handle_call({:finish_node, node_identifier}, _from, {resources}) do
    GenServer.call({:global, node_identifier}, :finish_node)
    {:ok, node} = Map.fetch(resources, node_identifier)

    {:ok, supervisor_id} = Map.fetch(node, :supervisor_id)

    Supervisor.stop(supervisor_id)

    # node情報削除
    new_resources = Map.delete(resources, node_identifier)
    Logger.debug("finish node: #{node_identifier}")

    {:reply, :ok, {new_resources}}
  end

  @impl GenServer
  def handle_call({:stop_timer, timer_identifier}, _from, {resources}) do
    # :ok = GenServer.call({:global, timer_identifier}, :stop)
    {:ok, timer} = Map.fetch(resources, timer_identifier)

    {:ok, supervisor_id} = Map.fetch(timer, :supervisor_id)

    Supervisor.stop(supervisor_id)

    # timer情報削除
    new_resources = Map.delete(resources, timer_identifier)
    Logger.debug("finish timer: #{timer_identifier}")
    {:reply, :ok, {new_resources}}
  end

  @impl GenServer
  def handle_info({_, _, reason}, state) do
    Logger.debug(reason)
    {:noreply, state}
  end

  @spec get_identifier(charlist(), charlist()) :: charlist()
  defp get_identifier(node_namespace, node_name) do
    if node_namespace != '' do
      "#{node_namespace}/#{node_name}"
    else
      node_name
    end
  end

  @spec call_nifs_rcl_node_init(any(), charlist(), charlist(), context(), any()) :: any()
  defp call_nifs_rcl_node_init(node, node_name, node_namespace, context, node_op) do
    if node_namespace != '' do
      Nifs.rcl_node_init(node, node_name, node_namespace, context, node_op)
    else
      Nifs.rcl_node_init_without_namespace(node, node_name, context, node_op)
    end
  end
end
