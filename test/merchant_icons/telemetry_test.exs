defmodule MerchantIcons.TelemetryTest do
  # Not async: telemetry handlers are global, so each test attaches its own uniquely named
  # handler and detaches it on exit.
  use ExUnit.Case, async: false

  @event [:merchant_icons, :resolve]

  setup context do
    handler_id = {__MODULE__, context.test}
    test_pid = self()

    :telemetry.attach(handler_id, @event, &__MODULE__.handle_event/4, test_pid)

    on_exit(fn -> :telemetry.detach(handler_id) end)
  end

  # Module-function handler, as recommended by :telemetry (no local-function warning).
  def handle_event(event, measurements, metadata, test_pid) do
    send(test_pid, {:telemetry, event, measurements, metadata})
  end

  test "a known merchant emits :merchant_resolved" do
    assert {:ok, _merchant} = MerchantIcons.resolve("Google ADS2397919998")

    assert_receive {:telemetry, @event, %{count: 1}, %{result: :merchant_resolved}}
    refute_receive {:telemetry, _, _, _}
  end

  test "an unknown merchant emits :merchant_unknown" do
    assert {:ok, :unknown} = MerchantIcons.resolve("PADARIA DO ZE 0042")

    assert_receive {:telemetry, @event, %{count: 1}, %{result: :merchant_unknown}}
    refute_receive {:telemetry, _, _, _}
  end

  test "the description does not appear anywhere in the event" do
    descriptions = ["DL * GOOGLE A0000021232", "PADARIA DO ZE 0042"]

    for description <- descriptions do
      MerchantIcons.resolve(description)

      assert_receive {:telemetry, event, measurements, metadata}

      assert measurements == %{count: 1}
      assert Map.keys(metadata) == [:result]
      assert metadata.result in [:merchant_resolved, :merchant_unknown]

      dumped = inspect({event, measurements, metadata}, limit: :infinity)

      for fragment <- ["0000021232", "PADARIA", "ZE 0042", "DL *"] do
        refute dumped =~ fragment
      end
    end
  end

  test "validation errors do not emit events" do
    MerchantIcons.resolve(nil)
    MerchantIcons.resolve("   ")
    MerchantIcons.resolve(String.duplicate("a", 5_000))

    refute_receive {:telemetry, _, _, _}
  end

  test "resolve/1 works the same without any handler attached", context do
    :telemetry.detach({__MODULE__, context.test})

    assert {:ok, %MerchantIcons.Merchant{id: "google"}} = MerchantIcons.resolve("GOOGLE")
    assert {:ok, :unknown} = MerchantIcons.resolve("PADARIA DO ZE 0042")

    refute_receive {:telemetry, _, _, _}
  end
end
