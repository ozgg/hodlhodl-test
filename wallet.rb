# frozen_string_literal: true

require 'bitcoin'
require_relative 'lib/wallet/mempool'
require_relative 'lib/wallet/key_handler'
require_relative 'lib/wallet/transaction_handler'

Bitcoin.chain_params = :signet

option = ARGV.shift.to_s.downcase
key_handler = Wallet::KeyHandler.new(File.expand_path(Pathname.new("#{__dir__}/tmp/")))

case option
when 'generate'
  key = key_handler.generate_key
  puts "Generated key with address: #{key.to_addr}"
when 'balance'
  address = key_handler.address
  mempool = Wallet::Mempool.new(address)
  puts "Address: #{address}"
  puts "Balance: #{mempool.balance} SAT (#{mempool.confirmed_balance} confirmed)"
when 'transfer'
  address = key_handler.address
  puts "Address: #{address}"
  to_address = ARGV.shift.to_s
  amount_btc = ARGV.shift.to_f
  if to_address.match?(/\A[a-zA-Z0-9]{42}\z/) && amount_btc.positive?
    puts "Transferring #{amount_btc} BTC to #{to_address}"
    handler = Wallet::TransactionHandler.new(key_handler.key)
    begin
      txid = handler.transfer(to_address, amount_btc)
      puts "Transaction #{txid} sent."
    rescue StandardError => e
      puts "Error: #{e.message}"
    end
  else
    puts "Invalid address (#{to_address.inspect}) or amount (#{amount_btc.inspect})"
  end
else
  puts <<~DOC
    Usage:
      generate: generate new key (rewrites old file)
      balance: show balance
      transfer [address] [amount]: transfer [amount] BTC to [address] (P2WPKH)
  DOC
end
