require 'sequel'

DB = Sequel.connect('sqlite://db/coffeelogy.db')

DB.create_table?(:users) do
  primary_key :telegram_id, type: Integer
  String :nickname
  String :name
  String :phone
  String :birthday
  TrueClass :admin, default: false
  add_column :all_discount, type: Integer, default: 0
end

DB.create_table?(:daily_codes) do
  primary_key :id
  String :code
  TrueClass :activate?, default: false
  foreign_key :user_telegram_id, :users, type: Integer
  String :created_at
  foreign_key :client_id, :users, type: Integer
  TrueClass :bonus?, default: false
end
