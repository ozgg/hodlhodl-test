# frozen_string_literal: true

require_relative '../../lib/wallet/key_handler'
require 'pathname'
require 'fileutils'

RSpec.describe Wallet::KeyHandler do
  let(:handler) { described_class.new(KEY_DIR) }

  describe '#initialize' do
    it 'sets path to key file' do
      instance = described_class.new(KEY_DIR)
      expect(instance.key_file).to eq(KEY_FILE)
    end
  end

  describe '#generate_key' do
    before do
      FileUtils.rm(KEY_FILE) if File.file?(KEY_FILE)
    end

    it 'writes new key to file' do
      handler.generate_key
      expect(File).to be_file(KEY_FILE)
    end
  end

  describe '#load_key' do
    context 'when key file does not exist' do
      before do
        FileUtils.rm(KEY_FILE) if File.file?(KEY_FILE)
      end

      it 'creates a new file' do
        handler.load_key
        expect(File).to be_file(KEY_FILE)
      end
    end

    it 'returns an instance of Bitcoin::Key' do
      expect(handler.load_key).to be_an_instance_of(Bitcoin::Key)
    end
  end

  describe '#address' do
    it 'returns address string' do
      expect(handler.address).to match(/\A[a-zA-Z0-9]{34}\z/)
    end
  end

  describe '#key' do
    it 'returns an instance of Bitcoin::Key' do
      expect(handler.key).to be_instance_of(Bitcoin::Key)
    end
  end
end
