# frozen_string_literal: true

require 'bitcoin'
# require 'byebug'
require 'httparty'

module Wallet
  # Transaction handler
  # rubocop:disable Naming/MethodParameterName
  class TransactionHandler
    FEE_API_URL = 'https://mempool.space/signet/api/v1/fees/recommended'
    DEFAULT_FEE_RATE = 10.0
    MIN_FEE_RATE = 3.0 # Safe rate to avoid "min relay fee not met" error

    # @param [Bitcoin::Key] key
    def initialize(key)
      @key = key
      @mempool = Mempool.new(@key&.to_p2wpkh.to_s)

      # Use only confirmed UTXOs
      @utxos = @mempool.utxo.select { |u| u['status']['confirmed'] }
    end

    def fee_rate
      @fee_rate ||= recommended_fee_rate
    end

    # Transfer coins
    #
    # @see https://github.com/chaintope/bitcoinrb/wiki/Transaction
    #
    # Calculates recommended fee, signs and sends transaction
    #
    # @param [String] to_address
    # @param [Float] amount_btc
    def transfer(to_address, amount_btc)
      amount_sats = (amount_btc * 100_000_000).to_i
      unsigned_tx = build_unsigned_tx(to_address, amount_sats)
      change = @mempool.balance(@utxos) - amount_sats - estimate_tx_fee(unsigned_tx)

      raise 'Insufficient funds' if change.negative?

      signed_tx = build_and_sign_tx(to_address, amount_sats, change)
      @mempool.broadcast(signed_tx.to_hex)
    end

    private

    # Build unsigned transaction
    #
    # @param [String] to_address
    # @param [Integer] amount_sats
    # @return [Bitcoin::Tx]
    def build_unsigned_tx(to_address, amount_sats)
      tx = Bitcoin::Tx.new
      tx.version = 2

      @utxos.each { |utxo| tx.in << input(utxo) }

      tx.out << output(amount_sats, to_address)
      tx.out << output(@mempool.balance(@utxos) - amount_sats, @key.to_p2wpkh)
      tx
    end

    # Build signed transaction
    #
    # @param [String] to_address
    # @param [Integer] amount_sats
    # @param [Integer] change
    # @return [Bitcoin::Tx]
    def build_and_sign_tx(to_address, amount_sats, change)
      tx = Bitcoin::Tx.new
      tx.version = 2

      @utxos.each { |utxo| tx.in << input(utxo) }

      tx.out << output(amount_sats, to_address)
      tx.out << output(change, @key.to_p2wpkh) if change.positive?

      sign_tx(tx)
      tx
    end

    # Sign transaction
    #
    # @param [Bitcoin::Tx] tx
    def sign_tx(tx)
      script_pubkey = Bitcoin::Script.parse_from_addr(@key.to_p2wpkh)

      @utxos.each_with_index do |utxo, i|
        sighash = tx.sighash_for_input(i, script_pubkey, amount: utxo['value'], sig_version: :witness_v0)
        sig = @key.sign(sighash) + [Bitcoin::SIGHASH_TYPE[:all]].pack('C')

        tx.in[i].script_witness = Bitcoin::ScriptWitness.new([sig, @key.pubkey.htb])
      end
    end

    # Generate transaction output
    #
    # @param [Integer] value
    # @param [String] address
    def output(value, address)
      Bitcoin::TxOut.new(value:, script_pubkey: Bitcoin::Script.parse_from_addr(address))
    end

    # @param [Hash] utxo
    def input(utxo)
      Bitcoin::TxIn.new(out_point: Bitcoin::OutPoint.new(utxo['txid'].rhex, utxo['vout']))
    end

    # @param [Bitcoin::Tx] tx
    def estimate_tx_fee(tx)
      dummy_key = @key.pubkey.htb
      dummy_sig = Array.new(72, 0).pack('C*') # Usual signature size is 70 to 72 bytes

      # Adding dummy witnesses
      tx.in.each_with_index do |_, i|
        tx.in[i].script_witness = Bitcoin::ScriptWitness.new([dummy_sig, dummy_key])
      end

      # 4 vbytes per weight unit
      vbytes = (tx.weight / 4.0).ceil
      (vbytes * fee_rate).ceil
    end

    # Receive recommended fee rate for 'fastestFee'
    #
    # @see https://mempool.space/graphs/mining/block-fee-rates
    #
    # Sometimes minimal fee is too low for signet, then use minimal rate
    #
    # return [Float]
    def recommended_fee_rate
      response = HTTParty.get(FEE_API_URL, timeout: 3)
      if response.success?
        [(response['fastestFee'] || DEFAULT_FEE_RATE).to_f, MIN_FEE_RATE].max
      else
        warn "Failed to fetch recommended fee rate: HTTP #{response.code}, using default"
        DEFAULT_FEE_RATE
      end
    rescue HTTParty::Error => e
      warn "Recommended fee rate fetch error: #{e.message}, using default"
      DEFAULT_FEE_RATE
    end
  end
  # rubocop:enable Naming/MethodParameterName
end
