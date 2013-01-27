require 'logger'

# stackoverflow.com/questions/917566/ruby-share-logger-instance-among-module-classes

module Logging
  def logger
    Logging.logger
  end

  # Global, memoized, lazy initialized instance of a logger
  def self.logger
    @logger ||= Logger.new(STDOUT)
  end
end
