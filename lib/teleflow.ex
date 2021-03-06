defmodule TeleFlow do
  @moduledoc """
  Instruments Flow opearations.
  """

  @doc """
  This function returns an instrumented flow that will send telemetry events to
  the provided collector at each execution.
  """
  @spec attach(Flow.t(), TeleFlow.Collector.t(), list() | String.t()) :: Flow.t()
  def attach(flow, collector, event_prefix) do
    {:ok, _} = TeleFlow.Dispatcher.attach(collector, event_prefix)
    TeleFlow.instrument(flow, event_prefix)
  end

  def attach(flow, collector) do
    attach(flow, collector, uniq_event_prefix())
  end

  def uniq_event_prefix() do
    :erlang.system_time()
    |> Integer.to_string()
    |> String.to_atom()
    |> List.wrap()
    |> Enum.concat([:telemetry, :flow])
    |> Enum.reverse()
  end

  def instrument(flow = %Flow{}, event_prefix) when is_list(event_prefix) do
    # NOTE: it would be nice now to depend on Flow itself but a Protocol
    # defined by this library. For that we need Flow to export some
    # introspection functions that allow us to retrieve operations and
    # producers with the ability to substitute them.
    flow
    |> walk_and_instrument(event_prefix, 0)
  end

  defp walk_and_instrument(flow = %Flow{}, event_prefix, depth) do
    flow
    |> Map.update(:operations, [], fn ops ->
      Enum.map(ops, &instrument_op(&1, event_prefix, depth))
    end)
    |> Map.update(:producers, [], fn
      {:flows, flows} ->
        {:flows, Enum.map(flows, &walk_and_instrument(&1, event_prefix, depth + 1))}

      other ->
        other
    end)
  end

  defp instrument_op({:mapper, id, funs}, event_prefix, depth) do
    funs =
      funs
      |> Enum.map(fn fun ->
        fn x ->
          instrument_fun(fun, [x], event_prefix, %{
            id: [id, depth]
          })
        end
      end)

    {:mapper, id, funs}
  end

  defp instrument_op({:reduce, acc_fun, reducer_fun}, event_prefix, depth) do
    reducer_fun = fn x, acc ->
      instrument_fun(reducer_fun, [x, acc], event_prefix, %{
        id: [:reduce, depth]
      })
    end

    {:reduce, acc_fun, reducer_fun}
  end

  # TODO: missing operations
  # * {:uniq, fun()}
  # * {:emit_and_reduce, fun(), fun()}
  # * {:on_trigger, fun()}
  defp instrument_op(unsupported_op, _event_prefix, _depth) do
    unsupported_op
  end

  defp instrument_fun(fun, args, event_prefix, start_metadata) do
    :telemetry.span(
      event_prefix,
      start_metadata,
      fn ->
        result = apply(fun, args)

        count =
          cond do
            is_list(result) -> Enum.count(result)
            true -> 1
          end

        {result, Map.merge(%{result_count: count}, start_metadata)}
      end
    )
  end
end
