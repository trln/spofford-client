module Spofford
  module Client
    def self.version 
      unless Spofford::Client.const_defined? :VERSION
        @version ||= File.read(File.join(__dir__, '..', '..', '..', 'VERSION'))
      end
    end
    VERSION = version.freeze
  end
end
