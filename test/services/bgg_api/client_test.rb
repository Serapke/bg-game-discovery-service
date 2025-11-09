# frozen_string_literal: true

require "test_helper"
require "webmock/minitest"

module BggApi
  class ClientTest < ActiveSupport::TestCase
    setup do
      @client = BggApi::Client.new
      @base_url = BggApi::BASE_URL.chomp("/")
      @original_token = BggApi::API_TOKEN
    end

    teardown do
      # Reset the token constant if it was changed
      BggApi.send(:remove_const, :API_TOKEN) if BggApi.const_defined?(:API_TOKEN)
      BggApi.const_set(:API_TOKEN, @original_token)
    end

    test "search returns parsed results for valid query" do
      xml_response = <<~XML
        <?xml version="1.0" encoding="utf-8"?>
        <items total="141" termsofuse="https://boardgamegeek.com/xmlapi/termsofuse">
            <item type="boardgame" id="134277">
                <name type="alternate" value="The 7 Wonders of Catan (fan expansion for Catan)"/>
                <yearpublished value="2012" />
            </item>
            <item type="boardgame" id="110308">
                <name type="primary" value="7 Wonders: Catan"/>
                <yearpublished value="2011" />
            </item>
        </items>
      XML

      stub_request(:get, "#{@base_url}/search")
        .with(query: { query: "Catan", type: "boardgame,boardgameexpansion", exact: 0 })
        .to_return(status: 200, body: xml_response)

      result = @client.search("Catan")

      assert_equal 141, result[:total]
      assert_equal 1, result[:items].length  # Only primary names are returned

      item = result[:items].first
      assert_equal "110308", item[:id]
      assert_equal "boardgame", item[:type]
      assert_equal "7 Wonders: Catan", item[:name]
      assert_equal "2011", item[:year_published]
      assert_nil item[:name_type]  # name_type field is not included
    end

    test "search with exact option sends exact parameter" do
      xml_response = <<~XML
        <?xml version="1.0" encoding="utf-8"?>
        <items total="1" termsofuse="https://boardgamegeek.com/xmlapi/termsofuse">
            <item type="boardgame" id="13">
                <name type="primary" value="Catan"/>
                <yearpublished value="1995" />
            </item>
        </items>
      XML

      stub_request(:get, "#{@base_url}/search")
        .with(query: { query: "Catan", type: "boardgame,boardgameexpansion", exact: 1 })
        .to_return(status: 200, body: xml_response)

      result = @client.search("Catan", exact: true)

      assert_equal 1, result[:total]
      assert_equal 1, result[:items].length
    end

    test "search with custom type option" do
      xml_response = <<~XML
        <?xml version="1.0" encoding="utf-8"?>
        <items total="5" termsofuse="https://boardgamegeek.com/xmlapi/termsofuse">
            <item type="boardgameexpansion" id="12345">
                <name type="primary" value="Catan Expansion"/>
                <yearpublished value="2000" />
            </item>
        </items>
      XML

      stub_request(:get, "#{@base_url}/search")
        .with(query: { query: "Catan", type: "boardgameexpansion", exact: 0 })
        .to_return(status: 200, body: xml_response)

      result = @client.search("Catan", type: "boardgameexpansion")

      assert_equal 5, result[:total]
      assert_equal "boardgameexpansion", result[:items].first[:type]
    end

    test "search handles empty results" do
      xml_response = <<~XML
        <?xml version="1.0" encoding="utf-8"?>
        <items total="0" termsofuse="https://boardgamegeek.com/xmlapi/termsofuse">
        </items>
      XML

      stub_request(:get, "#{@base_url}/search")
        .with(query: { query: "NonexistentGame123456789", type: "boardgame,boardgameexpansion", exact: 0 })
        .to_return(status: 200, body: xml_response)

      result = @client.search("NonexistentGame123456789")

      assert_equal 0, result[:total]
      assert_empty result[:items]
    end

    test "search handles items without year published" do
      xml_response = <<~XML
        <?xml version="1.0" encoding="utf-8"?>
        <items total="1" termsofuse="https://boardgamegeek.com/xmlapi/termsofuse">
            <item type="boardgame" id="99999">
                <name type="primary" value="Game Without Year"/>
            </item>
        </items>
      XML

      stub_request(:get, "#{@base_url}/search")
        .with(query: { query: "test", type: "boardgame,boardgameexpansion", exact: 0 })
        .to_return(status: 200, body: xml_response)

      result = @client.search("test")

      assert_equal 1, result[:items].length
      item = result[:items].first
      assert_equal "99999", item[:id]
      assert_equal "Game Without Year", item[:name]
      assert_nil item[:year_published]
    end

    test "search raises ArgumentError for nil query" do
      error = assert_raises(ArgumentError) do
        @client.search(nil)
      end

      assert_equal "query cannot be blank", error.message
    end

    test "search raises ArgumentError for empty query" do
      error = assert_raises(ArgumentError) do
        @client.search("  ")
      end

      assert_equal "query cannot be blank", error.message
    end

    test "search raises TimeoutError when request times out" do
      stub_request(:get, "#{@base_url}/search")
        .with(query: { query: "Catan", type: "boardgame,boardgameexpansion", exact: 0 })
        .to_timeout

      error = assert_raises(BggApi::Client::TimeoutError) do
        @client.search("Catan")
      end

      assert_match(/Request to BGG API timed out/, error.message)
    end

    test "search raises ApiError for network errors" do
      stub_request(:get, "#{@base_url}/search")
        .with(query: { query: "Catan", type: "boardgame,boardgameexpansion", exact: 0 })
        .to_return(status: 500, body: "Internal Server Error")

      error = assert_raises(BggApi::Client::ApiError) do
        @client.search("Catan")
      end

      assert_match(/BGG API request failed/, error.message)
    end

    test "search raises ParseError for invalid XML" do
      stub_request(:get, "#{@base_url}/search")
        .with(query: { query: "Catan", type: "boardgame,boardgameexpansion", exact: 0 })
        .to_return(status: 200, body: "This is not valid XML")

      error = assert_raises(BggApi::Client::ParseError) do
        @client.search("Catan")
      end

      assert_match(/Failed to parse BGG API response/, error.message)
    end

    test "search raises ParseError for unexpected XML structure" do
      xml_response = <<~XML
        <?xml version="1.0" encoding="utf-8"?>
        <unexpected_root>
          <something>data</something>
        </unexpected_root>
      XML

      stub_request(:get, "#{@base_url}/search")
        .with(query: { query: "Catan", type: "boardgame,boardgameexpansion", exact: 0 })
        .to_return(status: 200, body: xml_response)

      error = assert_raises(BggApi::Client::ParseError) do
        @client.search("Catan")
      end

      assert_equal "Invalid XML response structure", error.message
    end

    test "search handles special characters in query" do
      xml_response = <<~XML
        <?xml version="1.0" encoding="utf-8"?>
        <items total="1" termsofuse="https://boardgamegeek.com/xmlapi/termsofuse">
            <item type="boardgame" id="12345">
                <name type="primary" value="Game &amp; Dragons"/>
                <yearpublished value="2020" />
            </item>
        </items>
      XML

      stub_request(:get, "#{@base_url}/search")
        .with(query: { query: "Game & Dragons", type: "boardgame,boardgameexpansion", exact: 0 })
        .to_return(status: 200, body: xml_response)

      result = @client.search("Game & Dragons")

      assert_equal 1, result[:total]
      assert_equal "Game & Dragons", result[:items].first[:name]
    end
  end
end