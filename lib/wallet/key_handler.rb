# frozen_string_literal: true

require 'bitcoin'
require 'fileutils'

module Wallet
  # Key handler for wallet
  #
  # Generates, saves, and loads key. Also shows key address.
  class KeyHandler
    attr_reader :key_file

    # @param [String] key_dir
    def initialize(key_dir)
      FileUtils.mkdir_p(key_dir)
      @key_file = "#{key_dir}/key.txt"
      @key = nil
    end

    # Generate key and save it to file in key dir
    #
    # @return [Bitcoin::Key]
    def generate_key
      key = Bitcoin::Key.generate
      File.write(key_file, key.to_wif)
      key
    end

    # Load key from file or generate if the file does not exist
    #
    # @return [Bitcoin::Key]
    def load_key
      if File.exist?(key_file)
        Bitcoin::Key.from_wif(File.read(key_file).strip)
      else
        generate_key
      end
    end

    # Get address for generated key
    #
    # @return [String]
    def address
      key.to_addr
    end

    # Get key
    #
    # @return [Bitcoin::Key]
    def key
      return @key unless @key.nil?

      @key = load_key
    end
  end
end
