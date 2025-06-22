# frozen_string_literal: true

require 'bitcoin'
# require 'byebug'
require 'httparty'

module Wallet
  # Transaction handler
  # rubocop:disable Naming/MethodParameterName
  class TransactionHandler
    FEE_API_URL = 'https://mempool.space/api/v1/fees/recommended'
    DEFAULT_FEE_RATE = 4.0
    MIN_FEE_RATE = 2.0 # Minimal safe rate to avoid "min relay fee not met" error

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
    # @param [String] to_address
    # @param [Float] amount_btc
    def transfer(to_address, amount_btc)
      amount_sats = (amount_btc * 100_000_000).to_i
      balance = @mempool.balance(@utxos)

      tx = build_unsigned_tx(to_address, amount_sats)
      estimate_fee = estimate_tx_fee(tx)

      raise 'Insufficient funds' if balance < amount_sats + estimate_fee

      change = balance - amount_sats - estimate_fee

      tx = Bitcoin::Tx.new
      tx.version = 2

      # Use all confirmed UTXOs
      @utxos.each do |utxo|
        tx.in << Bitcoin::TxIn.new(out_point: Bitcoin::OutPoint.new(utxo['txid'].rhex, utxo['vout']))
      end

      tx.out << output(amount_sats, to_address)
      tx.out << output(change, @key.to_p2wpkh) if change.positive?

      script_pubkey = Bitcoin::Script.parse_from_addr(@key.to_p2wpkh)

      # Sign transaction
      @utxos.each_with_index do |utxo, i|
        amount = utxo['value']
        sighash = tx.sighash_for_input(i, script_pubkey, amount:, sig_version: :witness_v0)
        sig = @key.sign(sighash) + [Bitcoin::SIGHASH_TYPE[:all]].pack('C')

        tx.in[i].script_witness.stack << sig
        tx.in[i].script_witness.stack << @key.pubkey.htb
      end

      raw_tx = tx.to_hex
      @mempool.broadcast(raw_tx)
    end

    private

    # Build unsigned transaction
    #
    # @param [String] to_address
    # @param [Integer] amount
    # @return [Bitcoin::Tx]
    def build_unsigned_tx(to_address, amount)
      tx = Bitcoin::Tx.new
      tx.version = 2

      @utxos.each do |utxo|
        puts "Using input: #{utxo['txid']}:#{utxo['vout']}"
        tx.in << Bitcoin::TxIn.new(out_point: Bitcoin::OutPoint.new(utxo['txid'], utxo['vout']))
      end

      tx.out << output(amount, to_address)
      tx
    end

    # Generate transaction output
    #
    # @param [Integer] value
    # @param [String] address
    def output(value, address)
      Bitcoin::TxOut.new(value:, script_pubkey: Bitcoin::Script.parse_from_addr(address))
    end

    # @param [Bitcoin::Tx] tx
    def estimate_tx_fee(tx)
      dummy_key = @key.pubkey.htb
      dummy_sig = Array.new(72, 0) # Usual signature size is 70 to 72 bytes

      # Adding dummy witnesses
      tx.in.each_with_index do |_, i|
        tx.in[i].script_witness = Bitcoin::ScriptWitness.new([dummy_sig.pack('C*'), dummy_key])
      end

      # 4 vbytes per weight unit
      vbytes = (tx.weight / 4.0).ceil
      (vbytes * fee_rate).ceil
    end

    # Receive recommended fee rate for 'hourFee'
    #
    # @see https://mempool.space/graphs/mining/block-fee-rates
    #
    # Sometimes minimal fee is too low for signet, then use minimal rate
    #
    # return [Float]
    def recommended_fee_rate
      response = HTTParty.get('https://mempool.space/api/v1/fees/recommended', timeout: 3)
      if response.success?
        [(response['hourFee'] || DEFAULT_FEE_RATE).to_f, MIN_FEE_RATE].max
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
