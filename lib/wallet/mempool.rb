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
    def balance(list = utxo)
      list.sum { |u| u['value'] }
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

    # Get transaction details by id
    #
    # @see https://mempool.space/signet/docs/api/rest#get-transaction
    #
    # @param [String] id
    # @return [Hash]
    def tx(id)
      url = "#{API_URL}/tx/#{id}"
      response = HTTParty.get(url)
      JSON.parse(response.body)
    end

    # Broadcast raw transaction
    #
    # @see https://mempool.space/signet/docs/api/rest#post-transaction
    #
    # @param [String|nil] hex
    # @return [String]
    def broadcast(hex)
      response = HTTParty.post(
        "#{API_URL}/tx",
        body: hex,
        headers: { 'Content-Type' => 'text/plain' }
      )
      raise "Broadcast error: #{response.body}" unless response.code == 200

      response.body
    end
  end
end
