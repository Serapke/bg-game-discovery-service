# This file should ensure the existence of records required to run the application in every environment (production,
# development, test). The code here should be idempotent so that it can be executed at any point in every environment.
# The data can then be loaded with the bin/rails db:seed command (or created alongside the database with db:setup).

# Note: Board game data is imported from BoardGameGeek (BGG) via the BggApi::GameImporter service.
# Use the search endpoint to import games: GET /api/v1/board_games/search?name=<game_name>

puts "Seeding reference data..."

# Create game types
game_type_names = %w[abstract family party strategy thematic]
game_type_names.each do |type_name|
  GameType.find_or_create_by!(name: type_name)
end
puts "✓ Created #{game_type_names.count} game types"

# Create game categories
game_category_names = ['Ancient', 'Card Game', 'City Building', 'Civilization', 'Economic', 'Negotiation',
                       'Deduction', 'Word Game', 'Territory Building', 'Humor', 'Bluffing', 'Exploration']
game_category_names.each do |category_name|
  GameCategory.find_or_create_by!(name: category_name)
end
puts "✓ Created #{game_category_names.count} game categories"

puts "\nSeeding complete! Import board games from BGG using the /api/v1/board_games/search endpoint."
