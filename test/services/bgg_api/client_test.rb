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

    # Tests for get_details method

    test "get_details returns parsed game details for single ID" do
      xml_response = <<~XML
        <?xml version="1.0" encoding="utf-8"?>
        <items termsofuse="https://boardgamegeek.com/xmlapi/termsofuse">
          <item type="boardgame" id="13">
            <thumbnail>https://cf.geekdo-images.com/thumb.jpg</thumbnail>
            <image>https://cf.geekdo-images.com/image.jpg</image>
            <name type="primary" value="Catan"/>
            <name type="alternate" value="Settlers of Catan"/>
            <description>Classic trading and building game</description>
            <yearpublished value="1995"/>
            <minplayers value="3"/>
            <maxplayers value="4"/>
            <playingtime value="120"/>
            <minplaytime value="60"/>
            <maxplaytime value="120"/>
            <minage value="10"/>
            <link type="boardgamecategory" id="1021" value="Economic"/>
            <link type="boardgamecategory" id="1026" value="Negotiation"/>
            <link type="boardgamemechanic" id="2072" value="Dice Rolling"/>
            <link type="boardgamemechanic" id="2081" value="Trading"/>
            <statistics page="1">
              <ratings>
                <usersrated value="50000"/>
                <average value="7.12"/>
                <bayesaverage value="7.09"/>
                <ranks>
                  <rank type="subtype" id="1" name="boardgame" friendlyname="Board Game Rank" value="331" bayesaverage="7.09"/>
                </ranks>
                <stddev value="1.23"/>
                <median value="0"/>
                <owned value="75000"/>
                <trading value="1234"/>
                <wanting value="123"/>
                <wishing value="4567"/>
                <numcomments value="12345"/>
                <numweights value="5000"/>
                <averageweight value="2.35"/>
              </ratings>
            </statistics>
          </item>
        </items>
      XML

      stub_request(:get, "#{@base_url}/thing")
        .with(query: { id: "13", stats: 1 })
        .to_return(status: 200, body: xml_response)

      result = @client.get_details(13)

      assert_equal 1, result.length
      game = result.first

      assert_equal 13, game[:id]
      assert_equal "boardgame", game[:thing_type]
      assert_equal "Catan", game[:name]
      assert_equal 1995, game[:year_published]
      assert_equal 3, game[:min_players]
      assert_equal 4, game[:max_players]
      assert_equal 60, game[:min_playing_time]
      assert_equal 120, game[:max_playing_time]
      assert_equal 120, game[:playing_time]
      assert_equal 7.12, game[:rating]
      assert_equal 2.35, game[:complexity]
      assert_equal 50000, game[:user_ratings_count]
      assert_equal ["Economic", "Negotiation"], game[:categories]
      assert_equal ["Dice Rolling", "Trading"], game[:mechanics]
    end

    test "get_details accepts array of IDs" do
      xml_response = <<~XML
        <?xml version="1.0" encoding="utf-8"?>
        <items termsofuse="https://boardgamegeek.com/xmlapi/termsofuse">
          <item type="boardgame" id="13">
            <name type="primary" value="Catan"/>
            <yearpublished value="1995"/>
            <minplayers value="3"/>
            <maxplayers value="4"/>
            <minplaytime value="60"/>
            <maxplaytime value="120"/>
            <playingtime value="120"/>
            <statistics page="1">
              <ratings>
                <usersrated value="50000"/>
                <average value="7.12"/>
                <averageweight value="2.35"/>
              </ratings>
            </statistics>
          </item>
          <item type="boardgame" id="2807">
            <name type="primary" value="Pandemic"/>
            <yearpublished value="2008"/>
            <minplayers value="2"/>
            <maxplayers value="4"/>
            <minplaytime value="45"/>
            <maxplaytime value="45"/>
            <playingtime value="45"/>
            <statistics page="1">
              <ratings>
                <usersrated value="75000"/>
                <average value="7.60"/>
                <averageweight value="2.40"/>
              </ratings>
            </statistics>
          </item>
        </items>
      XML

      stub_request(:get, "#{@base_url}/thing")
        .with(query: { id: "13,2807", stats: 1 })
        .to_return(status: 200, body: xml_response)

      result = @client.get_details([13, 2807])

      assert_equal 2, result.length
      assert_equal "Catan", result[0][:name]
      assert_equal "Pandemic", result[1][:name]
    end

    test "get_details filters by minimum user ratings" do
      xml_response = <<~XML
        <?xml version="1.0" encoding="utf-8"?>
        <items termsofuse="https://boardgamegeek.com/xmlapi/termsofuse">
          <item type="boardgame" id="13">
            <name type="primary" value="Popular Game"/>
            <yearpublished value="1995"/>
            <minplayers value="2"/>
            <maxplayers value="4"/>
            <minplaytime value="60"/>
            <maxplaytime value="120"/>
            <playingtime value="120"/>
            <statistics page="1">
              <ratings>
                <usersrated value="50000"/>
                <average value="7.5"/>
                <averageweight value="2.5"/>
              </ratings>
            </statistics>
          </item>
          <item type="boardgame" id="99999">
            <name type="primary" value="Unpopular Game"/>
            <yearpublished value="2020"/>
            <minplayers value="2"/>
            <maxplayers value="4"/>
            <minplaytime value="30"/>
            <maxplaytime value="60"/>
            <playingtime value="45"/>
            <statistics page="1">
              <ratings>
                <usersrated value="500"/>
                <average value="6.0"/>
                <averageweight value="2.0"/>
              </ratings>
            </statistics>
          </item>
        </items>
      XML

      stub_request(:get, "#{@base_url}/thing")
        .with(query: { id: "13,99999", stats: 1 })
        .to_return(status: 200, body: xml_response)

      result = @client.get_details([13, 99999], min_user_ratings: 10000)

      assert_equal 1, result.length
      assert_equal "Popular Game", result.first[:name]
      assert_equal 50000, result.first[:user_ratings_count]
    end

    test "get_details handles expansions with parent game links" do
      xml_response = <<~XML
        <?xml version="1.0" encoding="utf-8"?>
        <items termsofuse="https://boardgamegeek.com/xmlapi/termsofuse">
          <item type="boardgameexpansion" id="12345">
            <name type="primary" value="Catan: Seafarers"/>
            <yearpublished value="1997"/>
            <minplayers value="3"/>
            <maxplayers value="4"/>
            <minplaytime value="60"/>
            <maxplaytime value="120"/>
            <playingtime value="90"/>
            <link type="boardgameexpansion" id="13" value="Catan" inbound="true"/>
            <statistics page="1">
              <ratings>
                <usersrated value="25000"/>
                <average value="7.0"/>
                <averageweight value="2.4"/>
              </ratings>
            </statistics>
          </item>
        </items>
      XML

      stub_request(:get, "#{@base_url}/thing")
        .with(query: { id: "12345", stats: 1 })
        .to_return(status: 200, body: xml_response)

      result = @client.get_details(12345)

      assert_equal 1, result.length
      expansion = result.first

      assert_equal 12345, expansion[:id]
      assert_equal "boardgameexpansion", expansion[:thing_type]
      assert_equal "Catan: Seafarers", expansion[:name]
      assert_equal [13], expansion[:links][:expands]
      assert_equal [], expansion[:links][:contains]
      assert_equal [], expansion[:links][:reimplements]
      assert_equal [], expansion[:links][:reimplemented_by]
      assert_equal [], expansion[:links][:integrates_with]
    end

    test "get_details handles compilations with contained game links" do
      xml_response = <<~XML
        <?xml version="1.0" encoding="utf-8"?>
        <items termsofuse="https://boardgamegeek.com/xmlapi/termsofuse">
          <item type="boardgame" id="54321">
            <name type="primary" value="Big Box Collection"/>
            <yearpublished value="2020"/>
            <minplayers value="2"/>
            <maxplayers value="4"/>
            <minplaytime value="30"/>
            <maxplaytime value="90"/>
            <playingtime value="60"/>
            <link type="boardgamecompilation" id="100" value="Game 1" inbound="true"/>
            <link type="boardgamecompilation" id="200" value="Game 2" inbound="true"/>
            <statistics page="1">
              <ratings>
                <usersrated value="15000"/>
                <average value="7.8"/>
                <averageweight value="2.3"/>
              </ratings>
            </statistics>
          </item>
        </items>
      XML

      stub_request(:get, "#{@base_url}/thing")
        .with(query: { id: "54321", stats: 1 })
        .to_return(status: 200, body: xml_response)

      result = @client.get_details(54321)

      assert_equal 1, result.length
      compilation = result.first

      assert_equal 54321, compilation[:id]
      assert_equal "boardgame", compilation[:thing_type]
      assert_equal "Big Box Collection", compilation[:name]
      assert_equal [], compilation[:links][:expands]
      assert_equal [100, 200], compilation[:links][:contains]
      assert_equal [], compilation[:links][:reimplements]
      assert_equal [], compilation[:links][:reimplemented_by]
      assert_equal [], compilation[:links][:integrates_with]
    end

    test "get_details handles reimplementations with reimplemented game links" do
      xml_response = <<~XML
        <?xml version="1.0" encoding="utf-8"?>
        <items termsofuse="https://boardgamegeek.com/xmlapi/termsofuse">
          <item type="boardgame" id="230914">
            <name type="primary" value="Carcassonne Big Box 6"/>
            <yearpublished value="2017"/>
            <minplayers value="2"/>
            <maxplayers value="5"/>
            <minplaytime value="30"/>
            <maxplaytime value="45"/>
            <playingtime value="45"/>
            <link type="boardgameimplementation" id="822" value="Carcassonne" inbound="true"/>
            <statistics page="1">
              <ratings>
                <usersrated value="15000"/>
                <average value="7.5"/>
                <averageweight value="1.9"/>
              </ratings>
            </statistics>
          </item>
        </items>
      XML

      stub_request(:get, "#{@base_url}/thing")
        .with(query: { id: "230914", stats: 1 })
        .to_return(status: 200, body: xml_response)

      result = @client.get_details(230914)

      assert_equal 1, result.length
      reimplementation = result.first

      assert_equal 230914, reimplementation[:id]
      assert_equal "boardgame", reimplementation[:thing_type]
      assert_equal "Carcassonne Big Box 6", reimplementation[:name]
      assert_equal [], reimplementation[:links][:expands]
      assert_equal [], reimplementation[:links][:contains]
      assert_equal [822], reimplementation[:links][:reimplements]
      assert_equal [], reimplementation[:links][:reimplemented_by]
      assert_equal [], reimplementation[:links][:integrates_with]
    end

    test "get_details handles games with reimplemented_by links" do
      xml_response = <<~XML
        <?xml version="1.0" encoding="utf-8"?>
        <items termsofuse="https://boardgamegeek.com/xmlapi/termsofuse">
          <item type="boardgame" id="822">
            <name type="primary" value="Carcassonne"/>
            <yearpublished value="2000"/>
            <minplayers value="2"/>
            <maxplayers value="5"/>
            <minplaytime value="30"/>
            <maxplaytime value="45"/>
            <playingtime value="45"/>
            <link type="boardgameimplementation" id="230914" value="Carcassonne Big Box 6" />
            <link type="boardgameimplementation" id="364405" value="Carcassonne Big Box 7" />
            <statistics page="1">
              <ratings>
                <usersrated value="75000"/>
                <average value="7.4"/>
                <averageweight value="1.9"/>
              </ratings>
            </statistics>
          </item>
        </items>
      XML

      stub_request(:get, "#{@base_url}/thing")
        .with(query: { id: "822", stats: 1 })
        .to_return(status: 200, body: xml_response)

      result = @client.get_details(822)

      assert_equal 1, result.length
      original = result.first

      assert_equal 822, original[:id]
      assert_equal "boardgame", original[:thing_type]
      assert_equal "Carcassonne", original[:name]
      assert_equal [], original[:links][:expands]
      assert_equal [], original[:links][:contains]
      assert_equal [], original[:links][:reimplements]
      assert_equal [230914, 364405], original[:links][:reimplemented_by]
      assert_equal [], original[:links][:integrates_with]
    end

    test "get_details handles games with integration links" do
      xml_response = <<~XML
        <?xml version="1.0" encoding="utf-8"?>
        <items termsofuse="https://boardgamegeek.com/xmlapi/termsofuse">
          <item type="boardgame" id="12345">
            <name type="primary" value="Space Base"/>
            <yearpublished value="2018"/>
            <minplayers value="2"/>
            <maxplayers value="5"/>
            <minplaytime value="60"/>
            <maxplaytime value="60"/>
            <playingtime value="60"/>
            <link type="boardgameintegration" id="67890" value="Space Base: The Emergence of Shy Pluto"/>
            <link type="boardgameintegration" id="111213" value="Space Base: Command Station"/>
            <statistics page="1">
              <ratings>
                <usersrated value="15000"/>
                <average value="7.2"/>
                <averageweight value="2.1"/>
              </ratings>
            </statistics>
          </item>
        </items>
      XML

      stub_request(:get, "#{@base_url}/thing")
        .with(query: { id: "12345", stats: 1 })
        .to_return(status: 200, body: xml_response)

      result = @client.get_details(12345)

      assert_equal 1, result.length
      game = result.first

      assert_equal 12345, game[:id]
      assert_equal "boardgame", game[:thing_type]
      assert_equal "Space Base", game[:name]
      assert_equal [], game[:links][:expands]
      assert_equal [], game[:links][:contains]
      assert_equal [], game[:links][:reimplements]
      assert_equal [], game[:links][:reimplemented_by]
      assert_equal [67890, 111213], game[:links][:integrates_with]
    end

    test "get_details raises ArgumentError for empty IDs" do
      error = assert_raises(ArgumentError) do
        @client.get_details([])
      end

      assert_equal "ids cannot be empty", error.message
    end

    test "get_details raises ArgumentError for more than 20 IDs" do
      ids = (1..21).to_a

      error = assert_raises(ArgumentError) do
        @client.get_details(ids)
      end

      assert_equal "can only fetch up to 20 items at once", error.message
    end

    test "get_details handles timeout errors" do
      stub_request(:get, "#{@base_url}/thing")
        .with(query: { id: "13", stats: 1 })
        .to_timeout

      error = assert_raises(BggApi::Client::TimeoutError) do
        @client.get_details(13)
      end

      assert_match(/Request to BGG API timed out/, error.message)
    end

    test "get_details handles API errors" do
      stub_request(:get, "#{@base_url}/thing")
        .with(query: { id: "13", stats: 1 })
        .to_return(status: 500, body: "Internal Server Error")

      error = assert_raises(BggApi::Client::ApiError) do
        @client.get_details(13)
      end

      assert_match(/BGG API request failed/, error.message)
    end

    test "get_details handles invalid XML" do
      stub_request(:get, "#{@base_url}/thing")
        .with(query: { id: "13", stats: 1 })
        .to_return(status: 200, body: "Not valid XML")

      error = assert_raises(BggApi::Client::ParseError) do
        @client.get_details(13)
      end

      assert_match(/Failed to parse BGG API response/, error.message)
    end

    test "get_details returns empty array when all games filtered out by min ratings" do
      xml_response = <<~XML
        <?xml version="1.0" encoding="utf-8"?>
        <items termsofuse="https://boardgamegeek.com/xmlapi/termsofuse">
          <item type="boardgame" id="99999">
            <name type="primary" value="Unpopular Game"/>
            <yearpublished value="2020"/>
            <minplayers value="2"/>
            <maxplayers value="4"/>
            <minplaytime value="30"/>
            <maxplaytime value="60"/>
            <playingtime value="45"/>
            <statistics page="1">
              <ratings>
                <usersrated value="100"/>
                <average value="6.0"/>
                <averageweight value="2.0"/>
              </ratings>
            </statistics>
          </item>
        </items>
      XML

      stub_request(:get, "#{@base_url}/thing")
        .with(query: { id: "99999", stats: 1 })
        .to_return(status: 200, body: xml_response)

      result = @client.get_details(99999, min_user_ratings: 10000)

      assert_empty result
    end

    test "get_details handles games with missing optional fields" do
      xml_response = <<~XML
        <?xml version="1.0" encoding="utf-8"?>
        <items termsofuse="https://boardgamegeek.com/xmlapi/termsofuse">
          <item type="boardgame" id="12345">
            <name type="primary" value="Minimal Game"/>
            <statistics page="1">
              <ratings>
                <usersrated value="10000"/>
                <average value="5.0"/>
                <averageweight value="1.0"/>
              </ratings>
            </statistics>
          </item>
        </items>
      XML

      stub_request(:get, "#{@base_url}/thing")
        .with(query: { id: "12345", stats: 1 })
        .to_return(status: 200, body: xml_response)

      result = @client.get_details(12345)

      assert_equal 1, result.length
      game = result.first

      assert_equal 12345, game[:id]
      assert_equal "Minimal Game", game[:name]
      assert_nil game[:year_published]
      assert_nil game[:min_players]
      assert_nil game[:max_players]
      assert_equal [], game[:categories]
      assert_equal [], game[:mechanics]
    end

    test "get_details extracts game types from family ranks" do
      xml_response = <<~XML
        <?xml version="1.0" encoding="utf-8"?>
        <items termsofuse="https://boardgamegeek.com/xmlapi/termsofuse">
          <item type="boardgame" id="13">
            <name type="primary" value="Catan"/>
            <yearpublished value="1995"/>
            <minplayers value="3"/>
            <maxplayers value="4"/>
            <minplaytime value="60"/>
            <maxplaytime value="120"/>
            <playingtime value="120"/>
            <statistics page="1">
              <ratings>
                <usersrated value="50000"/>
                <average value="7.12"/>
                <averageweight value="2.35"/>
                <ranks>
                  <rank type="subtype" id="1" name="boardgame" friendlyname="Board Game Rank" value="331" bayesaverage="7.09"/>
                  <rank type="family" id="5497" name="strategygames" friendlyname="Strategy Game Rank" value="123" bayesaverage="7.15"/>
                  <rank type="family" id="5499" name="familygames" friendlyname="Family Game Rank" value="45" bayesaverage="7.20"/>
                </ranks>
              </ratings>
            </statistics>
          </item>
        </items>
      XML

      stub_request(:get, "#{@base_url}/thing")
        .with(query: { id: "13", stats: 1 })
        .to_return(status: 200, body: xml_response)

      result = @client.get_details(13)

      assert_equal 1, result.length
      game = result.first

      assert_equal [{ name: "strategy", rank: 123 }, { name: "family", rank: 45 }], game[:types]
    end

    test "get_details handles all game type mappings" do
      xml_response = <<~XML
        <?xml version="1.0" encoding="utf-8"?>
        <items termsofuse="https://boardgamegeek.com/xmlapi/termsofuse">
          <item type="boardgame" id="99999">
            <name type="primary" value="Multi-Type Game"/>
            <yearpublished value="2020"/>
            <minplayers value="2"/>
            <maxplayers value="6"/>
            <minplaytime value="30"/>
            <maxplaytime value="60"/>
            <playingtime value="45"/>
            <statistics page="1">
              <ratings>
                <usersrated value="10000"/>
                <average value="7.0"/>
                <averageweight value="2.0"/>
                <ranks>
                  <rank type="subtype" id="1" name="boardgame" friendlyname="Board Game Rank" value="500" bayesaverage="6.95"/>
                  <rank type="family" id="5498" name="abstracts" friendlyname="Abstract Game Rank" value="50" bayesaverage="7.00"/>
                  <rank type="family" id="5500" name="partygames" friendlyname="Party Game Rank" value="25" bayesaverage="7.10"/>
                  <rank type="family" id="5501" name="thematic" friendlyname="Thematic Rank" value="75" bayesaverage="6.90"/>
                </ranks>
              </ratings>
            </statistics>
          </item>
        </items>
      XML

      stub_request(:get, "#{@base_url}/thing")
        .with(query: { id: "99999", stats: 1 })
        .to_return(status: 200, body: xml_response)

      result = @client.get_details(99999)

      assert_equal 1, result.length
      game = result.first

      assert_equal [{ name: "abstract", rank: 50 }, { name: "party", rank: 25 }, { name: "thematic", rank: 75 }], game[:types]
    end

    test "get_details returns empty types array when no family ranks present" do
      xml_response = <<~XML
        <?xml version="1.0" encoding="utf-8"?>
        <items termsofuse="https://boardgamegeek.com/xmlapi/termsofuse">
          <item type="boardgame" id="12345">
            <name type="primary" value="Game Without Family Ranks"/>
            <yearpublished value="2020"/>
            <minplayers value="2"/>
            <maxplayers value="4"/>
            <minplaytime value="30"/>
            <maxplaytime value="60"/>
            <playingtime value="45"/>
            <statistics page="1">
              <ratings>
                <usersrated value="10000"/>
                <average value="6.5"/>
                <averageweight value="1.5"/>
                <ranks>
                  <rank type="subtype" id="1" name="boardgame" friendlyname="Board Game Rank" value="1000" bayesaverage="6.50"/>
                </ranks>
              </ratings>
            </statistics>
          </item>
        </items>
      XML

      stub_request(:get, "#{@base_url}/thing")
        .with(query: { id: "12345", stats: 1 })
        .to_return(status: 200, body: xml_response)

      result = @client.get_details(12345)

      assert_equal 1, result.length
      game = result.first

      assert_equal [], game[:types]
    end
  end
end