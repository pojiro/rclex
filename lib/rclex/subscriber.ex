defmodule Rclex.Subscriber do
  alias Rclex.Nifs
  require Logger
  use GenServer

  @moduledoc """
  T.B.A
  """

  @doc """
    subscriberプロセスの生成
  """
  def start_link({sub, msg_type, process_name}) do
    Logger.debug("#{process_name} subscriber process start")
    GenServer.start_link(__MODULE__, {sub, msg_type}, name: {:global, process_name})
  end

  @impl GenServer
  @doc """
    subscriberプロセスの初期化
    subscriberを状態として持つ。start_subscribingをした際にcontextとcall_backを追加で状態として持つ。
  """
  def init({sub, msg_type}) do
    {:ok, %{subscriber: sub, msgtype: msg_type}}
  end

  def start_subscribing({node_identifier, topic_name, :sub}, context, call_back) do
    sub_identifier = "#{node_identifier}/#{topic_name}/sub"

    GenServer.cast(
      {:global, sub_identifier},
      {:start_subscribing, {context, call_back, node_identifier}}
    )
  end

  def start_subscribing(sub_list, context, call_back) do
    Enum.map(sub_list, fn {node_identifier, topic_name, :sub} ->
      sub_identifier = "#{node_identifier}/#{topic_name}/sub"

      GenServer.cast(
        {:global, sub_identifier},
        {:start_subscribing, {context, call_back, node_identifier, topic_name}}
      )
    end)
  end

  def stop_subscribing({node_identifier, topic_name, :sub}) do
    sub_identifier = "#{node_identifier}/#{topic_name}/sub"
    :ok = GenServer.call({:global, sub_identifier}, :stop_subscribing)
  end

  def stop_subscribing(sub_list) do
    Enum.map(sub_list, fn {node_identifier, topic_name, :sub} ->
      sub_identifier = "#{node_identifier}/#{topic_name}/sub"
      GenServer.call({:global, sub_identifier}, :stop_subscribing)
    end)
  end

  @impl GenServer
  def handle_cast({:start_subscribing, {context, call_back, node_identifier, topic_name}}, state) do
    {:ok, sub} = Map.fetch(state, :subscriber)
    {:ok, msg_type} = Map.fetch(state, :msgtype)

    children = [
      {Rclex.SubLoop, {node_identifier, msg_type, topic_name, sub, context, call_back}}
    ]

    opts = [strategy: :one_for_one]
    {:ok, supervisor_id} = Supervisor.start_link(children, opts)

    {:noreply,
     %{
       subscriber: sub,
       msgtype: msg_type,
       context: context,
       call_back: call_back,
       supervisor_id: supervisor_id
     }}
  end

  @impl GenServer
  @doc """
    コールバックの実行
  """
  def handle_cast({:subscribe, msg}, state) do
    {:ok, call_back} = Map.fetch(state, :call_back)
    call_back.(msg)
    {:noreply, state}
  end

  @impl GenServer
  def handle_cast(:stop, state) do
    {:stop, :normal, state}
  end

  @impl GenServer
  def handle_call(:stop_subscribing, _from, state) do
    {:ok, supervisor_id} = Map.fetch(state, :supervisor_id)
    Supervisor.stop(supervisor_id)
    new_state = Map.delete(state, :supervisor_id)
    {:reply, :ok, new_state}
  end

  @impl GenServer
  def handle_call({:finish, node}, _from, state) do
    {:ok, sub} = Map.fetch(state, :subscriber)
    Nifs.rcl_subscription_fini(sub, node)
    {:reply, {:ok, 'subscriber finished: '}, state}
  end

  @impl GenServer
  def handle_call({:finish_subscriber, node}, _from, state) do
    {:ok, sub} = Map.fetch(state, :subscriber)
    Nifs.rcl_subscription_fini(sub, node)
    {:reply, :ok, state}
  end

  @impl GenServer
  def terminate(:normal, _) do
    Logger.debug("terminate subscriber")
  end
end
