defmodule SessionServerStore do
  @moduledoc """
  Stores the session in a server.

  ## Options

    * `:idle_timeout` - number of seconds that a session may remain idle before
      it is terminated. Default is `600`.
    * `:timeout` - maximum number of seconds that a session may exist before it
      is terminated. Default is `10800`.

  The supported values are:

    * `:infinity`
    * any non-negative integer

  ## Examples

      plug Plug.Session,
        store: SessionServerStore,
        key: "sid",
        idle_timeout: :infinity,
        timeout: 86400
  """

  use Application

  @behaviour Plug.Session.Store

  @max_tries 100

  @type config :: %{idle_timeout: timeout, timeout: timeout}
  @type session :: map
  @type sid :: String.t | nil

  @typep timestamp :: non_neg_integer

  ## Application Callbacks

  @spec start(Application.start_type, any) :: {:ok, pid} | {:error, any}
  def start(_type, _args), do: Agent.start(&Map.new/0, name: __MODULE__)

  ## Plug.Session.Store Callbacks

  @spec init(keyword(timeout)) :: config
  def init(opts) do
    %{
      idle_timeout: Keyword.get(opts, :idle_timeout, 600),
      timeout: Keyword.get(opts, :timeout, 10800),
    }
  end

  @spec delete(Plug.Conn.t, sid, config) :: :ok
  def delete(_conn, sid, _config) do
    Agent.update(__MODULE__, &Map.delete(&1, sid))
  end

  @spec get(Plug.Conn.t, sid, config) :: {sid, session}
  def get(_conn, sid, %{idle_timeout: idle_timeout, timeout: timeout}) do
    Agent.get_and_update __MODULE__, fn state ->
      case state[sid] do
        {data, created, touched} ->
          if current?(touched, idle_timeout) and current?(created, timeout) do
            {{sid, data}, Map.put(state, sid, {data, created, now()})}
          else
            {{nil, %{}}, Map.delete(state, sid)}
          end
        nil ->
          {{sid, %{}}, state}
      end
    end
  end

  @spec put(Plug.Conn.t, sid, session, config) :: sid
  def put(_conn, nil, data, _config) do
    Agent.get_and_update(__MODULE__, &put_new(&1, data))
  end
  def put(_conn, sid, data, %{idle_timeout: idle_timeout, timeout: timeout}) do
    Agent.get_and_update __MODULE__, fn state ->
      case state[sid] do
        {_data, created, touched} ->
          if current?(touched, idle_timeout) and current?(created, timeout) do
            {sid, Map.put(state, sid, {data, created, now()})}
          else
            state
            |> Map.delete(sid)
            |> put_new(%{})
          end
        nil ->
          put_new(state, data)
      end
    end
  end

  @spec put_new(map, any, non_neg_integer) :: {sid, map}
  defp put_new(state, data, count \\ 0) when count < @max_tries do
    sid = Base.encode64(:crypto.strong_rand_bytes(96))

    case state[sid] do
      {_data, _created, _touched} ->
        put_new(state, data, count + 1)
      nil ->
        {sid, Map.put(state, sid, {data, now(), now()})}
    end
  end

  @spec current?(timestamp, timeout) :: boolean
  defp current?(_timestamp, :infinity), do: true
  defp current?(timestamp, timeout), do: now() < timestamp + timeout

  @spec now() :: timestamp
  defp now, do: :erlang.system_time(:seconds)
end
