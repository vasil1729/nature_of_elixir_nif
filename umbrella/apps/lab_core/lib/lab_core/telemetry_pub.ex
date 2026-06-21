defmodule Lab.Core.TelemetryPub do
  @moduledoc """
  Attaches to `:telemetry` events from lab_core probes and fans them out to
  Phoenix.PubSub (for LiveView) when available.

  Call `attach/0` in your application's `start/2` callback (lab_web or
  lab_runner). The handler is idempotent — calling `attach/0` multiple times
  is safe.

  Events handled:

    * `[:lab, :sampler, :sample]`       -> broadcast {:sampler, metrics}
    * `[:lab, :latency, :sample]`       -> broadcast {:latency, metrics}
    * `[:lab, :latency, :window]`       -> broadcast {:latency_window, metrics}
    * `[:lab, :system, :sample]`        -> broadcast {:system, metrics}
    * `[:lab, :watchdog, :event]`       -> broadcast {:watchdog, metrics}

  Broadcasts on the `\"lab:metrics\"` PubSub topic. If no PubSub is
  configured, the handler is still attached (for JSONL/Postgres) but
  broadcasts are skipped.
  """

  # Phoenix.PubSub is an optional dependency — available when lab_web is
  # loaded but not required by lab_core itself.
  @compile {:no_warn_undefined, Phoenix.PubSub}

  @handlers [
    {[:lab, :sampler, :sample], :sampler},
    {[:lab, :latency, :sample], :latency},
    {[:lab, :latency, :window], :latency_window},
    {[:lab, :system, :sample], :system},
    {[:lab, :watchdog, :event], :watchdog}
  ]

  @topic "lab:metrics"

  @doc "Attaches all telemetry handlers. Idempotent."
  def attach do
    Enum.each(@handlers, fn {event, label} ->
      handler_id = {__MODULE__, label}

      :telemetry.attach(
        handler_id,
        event,
        &__MODULE__.handle_event/4,
        %{label: label}
      )
    end)

    :ok
  end

  @doc "Detaches all handlers (useful for tests)."
  def detach do
    Enum.each(@handlers, fn {_, label} ->
      :telemetry.detach({__MODULE__, label})
    end)

    :ok
  end

  @doc false
  def handle_event(_event, measurements, metadata, %{label: label}) do
    # Always emit to any attached metrics reporters (telemetry_metrics)
    # — that's handled by Phoenix/Oban telemetry in their own apps.

    # Broadcast to PubSub if a pubsub module is configured.
    case pubsub_module() do
      nil -> :ok
      mod -> Phoenix.PubSub.broadcast(mod, @topic, {label, measurements.metrics, metadata})
    end
  end

  @doc "The PubSub topic all LiveView processes subscribe to."
  def topic, do: @topic

  defp pubsub_module do
    Application.get_env(:lab_core, :pubsub_module) ||
      if Code.ensure_loaded?(Phoenix.PubSub), do: Lab.PubSub, else: nil
  end
end
