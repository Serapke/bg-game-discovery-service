require "test_helper"

module BoardGames
  # noinspection RubyArgCount
  class FetchQueryTest < ActiveSupport::TestCase
    setup do
      @query = BoardGames::FetchQuery.new
      @catan = board_games(:catan)
      @wingspan = board_games(:wingspan)
    end

    test "call without ids returns all board games" do
      result = @query.call(ids: nil)

      assert_equal BoardGame.count, result.count
      assert_includes result, @catan
      assert_includes result, @wingspan
    end

    test "call with ids returns only specified board games" do
      ids = [@catan.id, @wingspan.id]
      result = @query.call(ids: ids)

      assert_equal 2, result.count
      assert_includes result, @catan
      assert_includes result, @wingspan
    end

    test "call with single id returns only that board game" do
      result = @query.call(ids: [@catan.id])

      assert_equal 1, result.count
      assert_includes result, @catan
      refute_includes result, @wingspan
    end

    test "call with empty ids array raises ArgumentError" do
      assert_raises(ArgumentError, "No valid IDs provided") do
        @query.call(ids: [])
      end
    end

    test "fetch_all includes associations" do
      result = @query.fetch_all

      # Verify associations are eagerly loaded
      assert_not ActiveRecord::Associations::Preloader.new(
        records: [result.first],
        associations: [:extensions, :game_types, :game_categories]
      ).empty?
    end

    test "fetch_by_ids includes associations" do
      result = @query.fetch_by_ids([@catan.id])

      # Verify associations are eagerly loaded
      assert_not ActiveRecord::Associations::Preloader.new(
        records: [result.first],
        associations: [:extensions, :game_types, :game_categories]
      ).empty?
    end

    test "can initialize with custom relation" do
      custom_relation = BoardGame.where(name: @catan.name)
      query = BoardGames::FetchQuery.new(custom_relation)

      result = query.call(ids: nil)

      assert_equal 1, result.count
      assert_includes result, @catan
    end
  end
end