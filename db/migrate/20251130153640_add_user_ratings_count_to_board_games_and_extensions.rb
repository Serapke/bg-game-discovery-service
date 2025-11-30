class AddUserRatingsCountToBoardGamesAndExtensions < ActiveRecord::Migration[8.0]
  def up
    # PostgreSQL doesn't support AFTER clause, so we add the column and let it appear at the end
    # The column order doesn't affect functionality, only visual representation in schema
    add_column :board_games, :rating_count, :integer
    add_column :extensions, :rating_count, :integer

    # Add check constraints to ensure rating_count is non-negative
    add_check_constraint :board_games, "rating_count >= 0", name: "board_games_rating_count_check"
    add_check_constraint :extensions, "rating_count >= 0", name: "extensions_rating_count_check"

    # Add index for potential filtering/sorting by popularity
    add_index :board_games, :rating_count, name: "idx_board_games_rating_count"
  end

  def down
    remove_index :board_games, name: "idx_board_games_rating_count"
    remove_check_constraint :extensions, name: "extensions_rating_count_check"
    remove_check_constraint :board_games, name: "board_games_rating_count_check"
    remove_column :extensions, :rating_count
    remove_column :board_games, :rating_count
  end
end
