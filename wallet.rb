require 'bitcoin'
require_relative 'lib/wallet/mempool'
require_relative 'lib/wallet/key_handler'
# require 'byebug'

Bitcoin.chain_params = :signet

option = ARGV.shift.to_s.downcase
key_handler = Wallet::KeyHandler.new(File.expand_path(Pathname.new("#{__dir__}/tmp/")))

case option
when 'generate'
  key = key_handler.generate_key
  puts "Generated key with address: #{key.to_addr}"
when 'balance'
  mempool = Wallet::Mempool.new(key_handler.key.to_addr)
  puts "Balance: #{mempool.balance} SAT"
when 'transfer'
  puts 'Not implemented yet'
else
  puts <<~DOC
    Usage:
      generate: generate key
      balance: show balance
      transfer [address] [amount]: transfer [amount] BTC to [address]
  DOC
end
