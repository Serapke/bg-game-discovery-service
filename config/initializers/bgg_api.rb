# frozen_string_literal: true

# BoardGameGeek XML API2 configuration
# Documentation: https://boardgamegeek.com/wiki/page/BGG_XML_API2
module BggApi
  BASE_URL = ENV.fetch("BGG_API_BASE_URL", "https://boardgamegeek.com/xmlapi2/").freeze
  TIMEOUT = ENV.fetch("BGG_API_TIMEOUT", 10).to_i
  OPEN_TIMEOUT = ENV.fetch("BGG_API_OPEN_TIMEOUT", 5).to_i
  API_TOKEN = ENV.fetch("BGG_API_TOKEN", nil).freeze
end