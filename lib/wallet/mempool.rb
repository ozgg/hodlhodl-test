# frozen_string_literal: true

require 'httparty'

module Wallet
  # Wrapper for Mempool API
  class Mempool
    API_URL = 'https://mempool.space/signet/api'

    attr_reader :address

    # @param [String] address
    def initialize(address)
      @address = address
    end

    # Get balance in Satoshi units
    def balance
      utxo.sum { |u| u['value'] }
    end

    # Get UTXO list
    #
    # @see https://mempool.space/signet/docs/api/rest#get-address-utxo
    #
    # @return [Array]
    def utxo
      url = "#{API_URL}/address/#{address}/utxo"
      response = HTTParty.get(url)
      JSON.parse(response.body)
    end
  end
end
