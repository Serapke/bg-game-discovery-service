# frozen_string_literal: true

require "test_helper"
require "minitest/mock"

module BggApi
  class SearchImporterTest < ActiveSupport::TestCase
    setup do
      @client = Minitest::Mock.new
      @importer = BggApi::SearchImporter.new(client: @client)
    end

    test "import_from_search imports first 20 games immediately" do
      search_results = {
        total: 25,
        items: (1..25).map { |i| { id: i.to_s, type: "boardgame", name: "Game #{i}" } }
      }

      @client.expect(:search, search_results, ["Catan"])

      importer_mock = Minitest::Mock.new
      importer_mock.expect(:import_by_ids, {
        imported: (1..20).map { |i| { bgg_id: i, board_game_id: i, name: "Game #{i}", year_published: 2000 } },
        updated: [],
        skipped: [],
        failed: [],
        related_ids: []
      }) do |ids, force_update:|
        ids == (1..20).to_a && force_update == false
      end

      BggApi::GameImporter.stub :new, importer_mock do
        # Create fake BoardGame records for the IDs
        fake_games = (1..20).map { |i| BoardGame.new(id: i, name: "Game #{i}") }

        BoardGame.stub :find, ->(id) { fake_games.find { |g| g.id == id } } do
          # Stub perform_later to verify it's called with remaining IDs
          job_called = false
          remaining_ids = nil

          BggGameImportJob.stub :perform_later, ->(ids) { job_called = true; remaining_ids = ids } do
            result = @importer.import_from_search("Catan")

            assert_equal 25, result[:total_found]
            assert_equal 20, result[:imported_immediately].length
            assert_equal 5, result[:enqueued_count]
            assert_equal [21, 22, 23, 24, 25], result[:enqueued_ids]

            assert job_called, "Expected BggGameImportJob.perform_later to be called"
            assert_equal [21, 22, 23, 24, 25], remaining_ids
          end
        end
      end

      @client.verify
      importer_mock.verify
    end

    test "import_from_search with no results" do
      search_results = { total: 0, items: [] }

      @client.expect(:search, search_results, ["NonexistentGame"])

      result = @importer.import_from_search("NonexistentGame")

      assert_equal 0, result[:total_found]
      assert_equal 0, result[:imported_immediately].length
      assert_equal 0, result[:enqueued_count]
      assert_equal [], result[:enqueued_ids]

      @client.verify
    end

    test "import_from_search enqueues related games" do
      search_results = {
        total: 2,
        items: [
          { id: "13", type: "boardgame", name: "Catan" },
          { id: "2807", type: "boardgame", name: "Pandemic" }
        ]
      }

      @client.expect(:search, search_results, ["Catan"])

      importer_mock = Minitest::Mock.new
      importer_mock.expect(:import_by_ids, {
        imported: [
          { bgg_id: 13, board_game_id: 1, name: "Catan", year_published: 1995 },
          { bgg_id: 2807, board_game_id: 2, name: "Pandemic", year_published: 2008 }
        ],
        updated: [],
        skipped: [],
        failed: [],
        related_ids: [12345, 67890]  # Related games (e.g., expansions)
      }) do |ids, force_update:|
        ids == [13, 2807] && force_update == false
      end

      BggApi::GameImporter.stub :new, importer_mock do
        # Create fake BoardGame records
        fake_games = [
          BoardGame.new(id: 1, name: "Catan"),
          BoardGame.new(id: 2, name: "Pandemic")
        ]

        BoardGame.stub :find, ->(id) { fake_games.find { |g| g.id == id } } do
          job_called = false
          enqueued_ids = nil

          BggGameImportJob.stub :perform_later, ->(ids) { job_called = true; enqueued_ids = ids } do
            result = @importer.import_from_search("Catan")

            assert_equal 2, result[:total_found]
            assert_equal 2, result[:imported_immediately].length
            assert_equal 2, result[:enqueued_count]
            assert_equal [12345, 67890], result[:enqueued_ids]

            assert job_called, "Expected BggGameImportJob.perform_later to be called"
            assert_equal [12345, 67890], enqueued_ids
          end
        end
      end

      @client.verify
      importer_mock.verify
    end

    test "import_from_search combines remaining and related IDs" do
      search_results = {
        total: 25,
        items: (1..25).map { |i| { id: i.to_s, type: "boardgame", name: "Game #{i}" } }
      }

      @client.expect(:search, search_results, ["Popular"])

      importer_mock = Minitest::Mock.new
      importer_mock.expect(:import_by_ids, {
        imported: (1..20).map { |i| { bgg_id: i, board_game_id: i, name: "Game #{i}", year_published: 2000 } },
        updated: [],
        skipped: [],
        failed: [],
        related_ids: [100, 200, 300]  # Related games from first 20
      }) do |ids, force_update:|
        ids == (1..20).to_a && force_update == false
      end

      BggApi::GameImporter.stub :new, importer_mock do
        # Create fake BoardGame records
        fake_games = (1..20).map { |i| BoardGame.new(id: i, name: "Game #{i}") }

        BoardGame.stub :find, ->(id) { fake_games.find { |g| g.id == id } } do
          job_called = false
          enqueued_ids = nil

          BggGameImportJob.stub :perform_later, ->(ids) { job_called = true; enqueued_ids = ids } do
            result = @importer.import_from_search("Popular")

            assert_equal 25, result[:total_found]
            assert_equal 20, result[:imported_immediately].length
            # Should enqueue: 5 remaining from search + 3 related
            assert_equal 8, result[:enqueued_count]
            assert_equal [21, 22, 23, 24, 25, 100, 200, 300], result[:enqueued_ids]

            assert job_called, "Expected BggGameImportJob.perform_later to be called"
            # Should be unique and combined
            assert_equal [21, 22, 23, 24, 25, 100, 200, 300], enqueued_ids.sort
          end
        end
      end

      @client.verify
      importer_mock.verify
    end

    test "import_from_search handles API errors" do
      def @client.search(_query)
        raise BggApi::Client::TimeoutError, "Timeout"
      end

      error = assert_raises(BggApi::SearchImporter::ImportError) do
        @importer.import_from_search("Catan")
      end

      assert_match(/Failed to import games from BGG search/, error.message)
    end
  end
end
