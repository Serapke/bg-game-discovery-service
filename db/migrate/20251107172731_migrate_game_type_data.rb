class MigrateGameTypeData < ActiveRecord::Migration[8.0]
  def up
    # Create game types
    game_types = ['abstract', 'family', 'party', 'strategy', 'thematic']
    game_types.each do |type|
      execute "INSERT INTO game_types (name, created_at, updated_at) VALUES ('#{type}', NOW(), NOW())"
    end

    # Migrate existing board game game_type to the join table
    game_types.each do |type|
      execute <<-SQL
        INSERT INTO board_games_game_types (board_game_id, game_type_id)
        SELECT bg.id, gt.id
        FROM board_games bg
        CROSS JOIN game_types gt
        WHERE bg.game_type = '#{type}' AND gt.name = '#{type}'
      SQL
    end
  end

  def down
    # Remove all associations
    execute "DELETE FROM board_games_game_types"

    # Remove all game types
    execute "DELETE FROM game_types"
  end
end
