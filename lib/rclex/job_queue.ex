defmodule Rclex.JobQueue do
  require Logger
  use GenServer, restart: :transient

  @moduledoc """
    T.B.A
  """

  # queueには長さを設定できる
  # queue_lengthが-1なら外部から呼ばれるまでqueueをため続ける
  # queue_lengthが正ならqueue_lengthと同じ値までqueueをためて、たまったらジョブを実行する
  # 設定しない場合は1になる

  def start_link({target_identifier}) do
    GenServer.start_link(__MODULE__, {target_identifier, 1},
      name: {:global, "#{target_identifier}/JobQueue"}
    )
  end

  def start_link({target_identifier, queue_length}) do
    GenServer.start_link(__MODULE__, {target_identifier, queue_length},
      name: {:global, "#{target_identifier}/JobQueue"}
    )
  end

  @impl GenServer
  def init({target_identifier, queue_length}) do
    {:ok, {target_identifier, queue_length, :queue.new()}}
  end

  @impl GenServer
  def handle_cast({:push, job}, {target_identifier, queue_length, job_queue}) do
    new_job_queue = :queue.in(job, job_queue)

    if :queue.len(new_job_queue) >= queue_length do
      GenServer.cast({:global, "#{target_identifier}/JobExecutor"}, {:execute, new_job_queue})
      {:noreply, {target_identifier, queue_length, :queue.new()}}
    else
      {:noreply, {target_identifier, queue_length, new_job_queue}}
    end
  end
end
