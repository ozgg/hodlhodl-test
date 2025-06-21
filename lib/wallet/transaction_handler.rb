# frozen_string_literal: true

require 'bitcoin'

module Wallet
  # Transaction handler
  class TransactionHandler
    FEE = 1000 # sats

    # @param [Bitcoin::Key] key
    def initialize(key)
      @key = key
      @mempool = Mempool.new(@key&.to_p2wpkh.to_s)
      @utxos = @mempool.utxo.select { |u| u['status']['confirmed'] }
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

      raise 'Insufficient funds' if balance < amount_sats + FEE

      change = balance - amount_sats - FEE

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

    def output(amount, address)
      Bitcoin::TxOut.new(
        value: amount,
        script_pubkey: Bitcoin::Script.parse_from_addr(address)
      )
    end
  end
end
