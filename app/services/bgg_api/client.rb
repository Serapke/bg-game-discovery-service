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
    rescue Faraday::TimeoutError, Faraday::ConnectionFailed, Timeout::Error => e
      raise TimeoutError, "Request to BGG API timed out: #{e.message}"
    rescue Faraday::Error => e
      # Check if it's a timeout-related error
      if e.message.include?("execution expired") || e.message.include?("timeout")
        raise TimeoutError, "Request to BGG API timed out: #{e.message}"
      end
      raise ApiError, "BGG API request failed: #{e.message}"
    rescue REXML::ParseException => e
      raise ParseError, "Failed to parse BGG API response: #{e.message}"
    end

    # Get detailed information for board games by their BGG IDs
    #
    # @param ids [Array<Integer>, Integer] BGG ID(s) to fetch details for (max 20 per request)
    # @param options [Hash] optional parameters
    # @option options [Integer] :min_user_ratings minimum number of user ratings required (default: 10000)
    #
    # @return [Array<Hash>] array of game details, filtered by minimum user ratings
    #
    # @example
    #   client = BggApi::Client.new
    #   details = client.get_details([13, 2807])
    #   # => [
    #   #   {
    #   #     id: 13,
    #   #     thing_type: "boardgame",
    #   #     types: ["strategy", "family"],
    #   #     name: "Catan",
    #   #     year_published: 1995,
    #   #     min_players: 3,
    #   #     max_players: 4,
    #   #     min_playing_time: 60,
    #   #     max_playing_time: 120,
    #   #     playing_time: 120,
    #   #     rating: 7.1234,
    #   #     complexity: 2.3456,
    #   #     user_ratings_count: 50000,
    #   #     categories: ["Economic", "Negotiation"],
    #   #     mechanics: ["Dice Rolling", "Trading"]
    #   #   },
    #   #   ...
    #   # ]
    def get_details(ids, options = {})
      ids = Array(ids)
      raise ArgumentError, "ids cannot be empty" if ids.empty?
      raise ArgumentError, "can only fetch up to 20 items at once" if ids.count > 20

      min_ratings = options[:min_user_ratings] || 10_000

      params = { id: ids.join(","), stats: 1 }
      response = get("thing", params)
      parse_thing_response(response, min_ratings)
    rescue Faraday::TimeoutError, Faraday::ConnectionFailed, Timeout::Error => e
      raise TimeoutError, "Request to BGG API timed out: #{e.message}"
    rescue Faraday::Error => e
      if e.message.include?("execution expired") || e.message.include?("timeout")
        raise TimeoutError, "Request to BGG API timed out: #{e.message}"
      end
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

        # Only include items with a primary name type
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

    def parse_thing_response(xml_string, min_ratings)
      doc = REXML::Document.new(xml_string)
      root = doc.root

      raise ParseError, "Invalid XML response structure" unless root&.name == "items"

      root.elements.map do |item|
        next unless item.name == "item"

        # Filter by user ratings count
        user_ratings_count = extract_user_ratings_count(item)
        next if user_ratings_count < min_ratings

        parse_thing_item(item)
      end.compact
    end

    def extract_user_ratings_count(item)
      statistics = item.elements["statistics"]
      return 0 unless statistics

      ratings = statistics.elements["ratings"]
      return 0 unless ratings

      usersrated = ratings.elements["usersrated"]
      return 0 unless usersrated

      usersrated.attributes["value"].to_i
    end

    def parse_thing_item(item)
      {
        id: item.attributes["id"].to_i,
        thing_type: item.attributes["type"],
        types: extract_game_types(item),
        name: extract_primary_name(item),
        year_published: extract_year_published(item),
        min_players: extract_attribute(item, "minplayers"),
        max_players: extract_attribute(item, "maxplayers"),
        min_playing_time: extract_attribute(item, "minplaytime"),
        max_playing_time: extract_attribute(item, "maxplaytime"),
        playing_time: extract_attribute(item, "playingtime"),
        rating: extract_rating(item),
        complexity: extract_complexity(item),
        user_ratings_count: extract_user_ratings_count(item),
        categories: extract_links(item, "boardgamecategory"),
        mechanics: extract_links(item, "boardgamemechanic"),
        parent_game_ids: extract_parent_game_ids(item)
      }.compact
    end

    def extract_primary_name(item)
      item.elements.each("name") do |name|
        return name.attributes["value"] if name.attributes["type"] == "primary"
      end
      nil
    end

    def extract_year_published(item)
      year_element = item.elements["yearpublished"]
      year_element&.attributes&.[]("value")&.to_i
    end

    def extract_attribute(item, attr_name)
      element = item.elements[attr_name]
      return nil unless element

      value = element.attributes["value"]
      value&.to_i
    end

    def extract_rating(item)
      statistics = item.elements["statistics"]
      return nil unless statistics

      ratings = statistics.elements["ratings"]
      return nil unless ratings

      average = ratings.elements["average"]
      return nil unless average

      value = average.attributes["value"]
      value&.to_f&.round(2)
    end

    def extract_complexity(item)
      statistics = item.elements["statistics"]
      return nil unless statistics

      ratings = statistics.elements["ratings"]
      return nil unless ratings

      averageweight = ratings.elements["averageweight"]
      return nil unless averageweight

      value = averageweight.attributes["value"]
      value&.to_f&.round(2)
    end

    def extract_links(item, link_type)
      links = []
      item.elements.each("link") do |link|
        if link.attributes["type"] == link_type
          links << link.attributes["value"]
        end
      end
      links
    end

    def extract_parent_game_ids(item)
      parent_ids = []
      item.elements.each("link") do |link|
        # Look for expansion links with inbound="true"
        if link.attributes["type"] == "boardgameexpansion" && link.attributes["inbound"] == "true"
          parent_ids << link.attributes["id"].to_i
        end
      end
      parent_ids
    end

    def extract_game_types(item)
      statistics = item.elements["statistics"]
      return [] unless statistics

      ratings = statistics.elements["ratings"]
      return [] unless ratings

      ranks = ratings.elements["ranks"]
      return [] unless ranks

      types = []
      ranks.elements.each("rank") do |rank|
        # Look for ranks with type="family" to determine game types
        if rank.attributes["type"] == "family"
          rank_name = rank.attributes["name"]
          rank_value = rank.attributes["value"]

          mapped_type = map_rank_name_to_game_type(rank_name) if rank_name
          if mapped_type
            # Store both the type name and rank value
            # Set rank to nil if value is "Not Ranked" or invalid (to_i returns 0)
            rank_int = rank_value&.match?(/^\d+$/) ? rank_value.to_i : nil
            types << { name: mapped_type, rank: rank_int }
          end
        end
      end

      types.compact
    end

    def map_rank_name_to_game_type(rank_name)
      # Map BGG rank names to game types (abstract, family, party, strategy, thematic)
      mapped_type = case rank_name.downcase
      when /abstracts/
        "abstract"
      when /familygames/
        "family"
      when /partygames/
        "party"
      when /strategygames/
        "strategy"
      when /thematic/
        "thematic"
      else
        nil
      end

      if mapped_type.nil?
        Rails.logger.warn("Unrecognized BGG rank name for game type mapping: #{rank_name}")
      end

      mapped_type
    end
  end
end