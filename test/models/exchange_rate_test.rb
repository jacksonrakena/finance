require "test_helper"
require "ostruct"

class ExchangeRateTest < ActiveSupport::TestCase
  include ProviderTestHelper

  setup do
    @provider = mock

    ExchangeRate.stubs(:provider).returns(@provider)
  end

  test "finds rate in DB" do
    existing_rate = exchange_rates(:one)

    @provider.expects(:fetch_exchange_rate).never

    assert_equal existing_rate, ExchangeRate.find_or_fetch_rate(
                                              from: existing_rate.from_currency,
                                              to: existing_rate.to_currency,
                                              date: existing_rate.date
                                            )
  end

  test "fetches rate from provider without cache" do
    ExchangeRate.delete_all

    provider_response = provider_success_response(
      OpenStruct.new(
        from: "USD",
        to: "EUR",
        date: Date.current,
        rate: 1.2
      )
    )

    @provider.expects(:fetch_exchange_rate).returns(provider_response)

    assert_no_difference "ExchangeRate.count" do
      assert_equal 1.2, ExchangeRate.find_or_fetch_rate(from: "USD", to: "EUR", date: Date.current, cache: false).rate
    end
  end

  test "fetches rate from provider with cache" do
    ExchangeRate.delete_all

    provider_response = provider_success_response(
      OpenStruct.new(
        from: "USD",
        to: "EUR",
        date: Date.current,
        rate: 1.2
      )
    )

    @provider.expects(:fetch_exchange_rate).returns(provider_response)

    assert_difference "ExchangeRate.count", 1 do
      assert_equal 1.2, ExchangeRate.find_or_fetch_rate(from: "USD", to: "EUR", date: Date.current, cache: true).rate
    end
  end

  test "fetches lookback rate on provider error" do
    ExchangeRate.delete_all

    # Simulate provider error
    provider_response = provider_error_response(StandardError.new("Test error"))

    @provider.expects(:fetch_exchange_rate).returns(provider_response)

    # Create a lookback rate
    lookback_rate = ExchangeRate.create!(
      from_currency: "USD",
      to_currency: "EUR",
      date: Date.yesterday,
      rate: 1.1
    )

    # Attempt to fetch today's rate, which should return the lookback rate
    assert_equal lookback_rate, ExchangeRate.find_or_fetch_rate(from: "USD", to: "EUR", date: Date.current, cache: true)
  end

  test "returns nil on provider error after attempting lookback" do
    provider_response = provider_error_response(StandardError.new("Test error"))

    @provider.expects(:fetch_exchange_rate).returns(provider_response).times(6)

    assert_nil ExchangeRate.find_or_fetch_rate(from: "USD", to: "EUR", date: Date.current, cache: true)
  end
end
