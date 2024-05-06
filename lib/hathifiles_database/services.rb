# frozen_string_literal: true

require "canister"
require "logger"

module HathifilesDatabase
  Services = Canister.new

  Services.register(:logger) do
    Logger.new($stdout, level: ENV.fetch("HATHIFILES_DATABASE_LOGGER_LEVEL", Logger::WARN).to_i)
  end
end
