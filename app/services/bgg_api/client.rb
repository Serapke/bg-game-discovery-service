# frozen_string_literal: true

require "faraday"
require "rexml/document"

module BggApi
  # Client for interacting with BoardGameGeek XML API2
  # Documentation: https://boardgamegeek.com/wiki/page/BGG_XML_API2
  class Client
    class Error < StandardError; end
    class TimeoutError < Error; end
    class ApiError < Error; end
    class ParseError < Error; end

    # Search for board games on BoardGameGeek
    #
    # @param query [String] the search query
    # @param options [Hash] optional search parameters
    # @option options [String] :type the type of item to search (default: "boardgame")
    # @option options [Boolean] :exact whether to do an exact match (default: false)
    #
    # @return [Hash] parsed search results with :total and :items
    #
    # @example
    #   client = BggApi::Client.new
    #   results = client.search("Catan")
    #   # => {
    #   #   total: 141,
    #   #   items: [
    #   #     {
    #   #       id: "110308",
    #   #       type: "boardgame",
    #   #       name: "7 Wonders: Catan",
    #   #       year_published: "2011"
    #   #     },
    #   #     ...
    #   #   ]
    #   # }
    #   # Note: Only items with primary names are returned
    def search(query, options = {})
      raise ArgumentError, "query cannot be blank" if query.nil? || query.strip.empty?

      params = build_search_params(query, options)
      response = get("search", params)
      parse_search_response(response)
    rescue Faraday::TimeoutError => e
      raise TimeoutError, "Request to BGG API timed out: #{e.message}"
    rescue Faraday::Error => e
      raise ApiError, "BGG API request failed: #{e.message}"
    rescue REXML::ParseException => e
      raise ParseError, "Failed to parse BGG API response: #{e.message}"
    end

    private

    def connection
      @connection ||= Faraday.new(
        url: BggApi::BASE_URL,
        request: {
          timeout: BggApi::TIMEOUT,
          open_timeout: BggApi::OPEN_TIMEOUT
        },
        headers: default_headers
      ) do |f|
        f.response :raise_error
        f.adapter Faraday.default_adapter
      end
    end

    def default_headers
      headers = {}
      headers["Authorization"] = "Bearer #{BggApi::API_TOKEN}" if BggApi::API_TOKEN
      headers
    end

    def get(path, params = {})
      response = connection.get(path, params)
      response.body
    end

    def build_search_params(query, options)
      {
        query: query,
        type: options[:type] || "boardgame,boardgameexpansion",
        exact: options[:exact] ? 1 : 0
      }.compact
    end

    def parse_search_response(xml_string)
      doc = REXML::Document.new(xml_string)
      root = doc.root

      raise ParseError, "Invalid XML response structure" unless root&.name == "items"

      {
        total: root.attributes["total"].to_i,
        items: parse_search_items(root)
      }
    end

    def parse_search_items(root)
      root.elements.map do |item|
        next unless item.name == "item"

        name_element = item.elements["name"]
        year_element = item.elements["yearpublished"]

        # Only include items with primary name type
        name_type = name_element&.attributes&.[]("type")
        next unless name_type == "primary"

        {
          id: item.attributes["id"],
          type: item.attributes["type"],
          name: name_element&.attributes&.[]("value"),
          year_published: year_element&.attributes&.[]("value")
        }.compact
      end.compact
    end
  end
end