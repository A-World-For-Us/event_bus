defmodule EventBus.Service.Notification do
  @moduledoc false

  require Logger

  alias EventBus.Manager.Observation, as: ObservationManager
  alias EventBus.Manager.Store, as: StoreManager
  alias EventBus.Manager.Subscription, as: SubscriptionManager
  alias EventBus.Model.Event

  @typep event :: EventBus.event()
  @typep event_shadow :: EventBus.event_shadow()
  @typep subscriber :: EventBus.subscriber()
  @typep subscribers :: EventBus.subscribers()
  @typep topic :: EventBus.topic()

  @doc false
  @spec notify(event()) :: :ok
  def notify(%Event{id: id, topic: topic} = event) do
    subscribers = SubscriptionManager.subscribers(topic)

    if subscribers == [] do
      warn_missing_topic_subscription(topic)
    else
      :ok = StoreManager.create(event)
      :ok = ObservationManager.create({subscribers, {topic, id}})

      notify_subscribers(subscribers, {topic, id})
    end

    :ok
  end

  @spec notify_subscribers(subscribers(), event_shadow()) :: :ok
  defp notify_subscribers(subscribers, event_shadow) do
    Enum.each(subscribers, fn subscriber ->
      notify_subscriber(subscriber, event_shadow)
    end)

    :ok
  end

  @spec notify_subscriber(subscriber(), event_shadow()) :: no_return()
  defp notify_subscriber({subscriber, config}, {topic, id}) do
    subscriber.process({config, topic, id})
  rescue
    error ->
      log_error(subscriber, error)
      ObservationManager.mark_as_skipped({{subscriber, config}, {topic, id}})
  end

  defp notify_subscriber(subscriber, {topic, id}) do
    subscriber.process({topic, id})
  rescue
    error ->
      log_error(subscriber, error)
      ObservationManager.mark_as_skipped({subscriber, {topic, id}})
  end

  @spec registration_status(topic()) :: String.t()
  defp registration_status(topic) do
    if EventBus.topic_exist?(topic), do: "", else: " doesn't exist!"
  end

  @spec warn_missing_topic_subscription(topic()) :: no_return()
  defp warn_missing_topic_subscription(topic) do
    msg =
      "Topic(:#{topic}#{registration_status(topic)}) doesn't have subscribers"

    Logger.warning(msg)
  end

  @spec log_error(module(), any()) :: no_return()
  defp log_error(subscriber, error) do
    msg = "#{subscriber}.process/1 raised an error!\n#{inspect(error)}"
    Logger.info(msg)
  end
end
