# This file should ensure the existence of records required to run the application in every environment (production,
# development, test). The code here should be idempotent so that it can be executed at any point in every environment.
# The data can then be loaded with the bin/rails db:seed command (or created alongside the database with db:setup).

# Create game types
game_type_names = ['abstract', 'family', 'party', 'strategy', 'thematic']
game_types = {}
game_type_names.each do |type_name|
  game_types[type_name] = GameType.find_or_create_by!(name: type_name)
end

# Create game categories
game_category_names = ['Ancient', 'Card Game', 'City Building', 'Civilization', 'Economic', 'Negotiation',
                       'Deduction', 'Word Game', 'Territory Building', 'Humor', 'Bluffing', 'Exploration']
game_categories = {}
game_category_names.each do |category_name|
  game_categories[category_name] = GameCategory.find_or_create_by!(name: category_name)
end

board_games_data = [
  { name: 'Catan', min_players: 3, max_players: 4, min_playing_time: 60, max_playing_time: 90, rating: 7.2, difficulty_score: 2.5,
    game_type_names: ['strategy', 'family'], game_category_names: ['Economic', 'Negotiation'] },
  { name: 'Ticket to Ride', min_players: 2, max_players: 5, min_playing_time: 30, max_playing_time: 60, rating: 7.4, difficulty_score: 1.8,
    game_type_names: ['family'], game_category_names: ['Card Game'] },
  { name: 'Wingspan', min_players: 1, max_players: 5, min_playing_time: 40, max_playing_time: 70, rating: 8.1, difficulty_score: 2.5,
    game_type_names: ['strategy'], game_category_names: ['Card Game'] },
  { name: 'Azul', min_players: 2, max_players: 4, min_playing_time: 30, max_playing_time: 45, rating: 7.8, difficulty_score: 2.0,
    game_type_names: ['abstract', 'family'], game_category_names: ['Ancient'] }
]

board_games_data.each do |game_data|
  type_names = game_data.delete(:game_type_names)
  category_names = game_data.delete(:game_category_names)

  game = BoardGame.find_or_create_by!(name: game_data[:name]) do |g|
    g.assign_attributes(game_data)
  end

  # Associate game types and categories
  game.game_types = type_names.map { |type_name| game_types[type_name] }
  game.game_categories = category_names.map { |category_name| game_categories[category_name] }
  game.save!
end

# Create extensions
catan = BoardGame.find_by(name: 'Catan')
ticket_to_ride = BoardGame.find_by(name: 'Ticket to Ride')
wingspan = BoardGame.find_by(name: 'Wingspan')

extensions_data = [
  { name: 'Catan: Seafarers', board_game: catan, min_players: 3, max_players: 4, min_playing_time: 60, max_playing_time: 90, rating: 7.1, difficulty_score: 2.6 },
  { name: 'Catan: Cities & Knights', board_game: catan, min_players: 3, max_players: 4, min_playing_time: 90, max_playing_time: 120, rating: 7.5, difficulty_score: 3.2 },
  { name: 'Ticket to Ride: Europe', board_game: ticket_to_ride, min_players: 2, max_players: 5, min_playing_time: 30, max_playing_time: 60, rating: 7.6, difficulty_score: 1.9 },
  { name: 'Wingspan: European Expansion', board_game: wingspan, min_players: 1, max_players: 5, min_playing_time: 40, max_playing_time: 70, rating: 8.2, difficulty_score: 2.5 }
]

extensions_data.each do |extension_data|
  Extension.find_or_create_by!(name: extension_data[:name]) do |extension|
    extension.assign_attributes(extension_data)
  end
end
