# frozen_string_literal: true

require_relative '../../lib/wallet/mempool'

ADDRESS = 'tb1q3rgsupumstc2wr0avgpfjf3un62j90g3d3466k'

RSpec.describe Wallet::Mempool do
  let(:instance) { described_class.new(ADDRESS) }
  let(:response_body) do
    [
      { 'txid' => 'foo', 'vout' => 42, 'value' => 9001 },
      { 'txid' => 'bar', 'vout' => 43, 'value' => 9002 }
    ]
  end

  before do
    allow(HTTParty).to receive(:get).and_return(instance_double(HTTParty::Response, { body: response_body.to_json }))
  end

  describe '#initialize' do
    it 'stores address' do
      expect(instance.address).to eq(ADDRESS)
    end
  end

  describe '#utxo' do
    it 'returns transaction list from mempool', :aggregate_failures do
      expect(instance.utxo).to eq(response_body)
      expect(HTTParty).to have_received(:get)
    end
  end

  describe '#balance' do
    it 'returns sum of UTXO values' do
      expect(instance.balance).to eq(18_003)
    end
  end
end
