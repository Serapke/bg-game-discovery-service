# This file should ensure the existence of records required to run the application in every environment (production,
# development, test). The code here should be idempotent so that it can be executed at any point in every environment.
# The data can then be loaded with the bin/rails db:seed command (or created alongside the database with db:setup).

board_games_data = [
  { name: 'Catan', min_players: 3, max_players: 4, min_playing_time: 60, max_playing_time: 90, rating: 7.2 },
  { name: 'Ticket to Ride', min_players: 2, max_players: 5, min_playing_time: 30, max_playing_time: 60, rating: 7.4 },
  { name: 'Wingspan', min_players: 1, max_players: 5, min_playing_time: 40, max_playing_time: 70, rating: 8.1 },
  { name: 'Azul', min_players: 2, max_players: 4, min_playing_time: 30, max_playing_time: 45, rating: 7.8 }
]

board_games_data.each do |game_data|
  BoardGame.find_or_create_by!(name: game_data[:name]) do |game|
    game.assign_attributes(game_data)
  end
end

# Create extensions
catan = BoardGame.find_by(name: 'Catan')
ticket_to_ride = BoardGame.find_by(name: 'Ticket to Ride')
wingspan = BoardGame.find_by(name: 'Wingspan')

extensions_data = [
  { name: 'Catan: Seafarers', board_game: catan, min_players: 3, max_players: 4, min_playing_time: 60, max_playing_time: 90, rating: 7.1 },
  { name: 'Catan: Cities & Knights', board_game: catan, min_players: 3, max_players: 4, min_playing_time: 90, max_playing_time: 120, rating: 7.5 },
  { name: 'Ticket to Ride: Europe', board_game: ticket_to_ride, min_players: 2, max_players: 5, min_playing_time: 30, max_playing_time: 60, rating: 7.6 },
  { name: 'Wingspan: European Expansion', board_game: wingspan, min_players: 1, max_players: 5, min_playing_time: 40, max_playing_time: 70, rating: 8.2 }
]

extensions_data.each do |extension_data|
  Extension.find_or_create_by!(name: extension_data[:name]) do |extension|
    extension.assign_attributes(extension_data)
  end
end
