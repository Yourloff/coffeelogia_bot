require 'sinatra'
require 'telegram/bot'
require 'dotenv'

Dotenv.load

require_relative 'db/database'
require_relative 'userCommands/user_commands'
require_relative 'adminCommands/admin_commands'

include UserCommands
include AdminCommands

Telegram::Bot::Client.run(ENV['TOKEN']) do |bot|
  bot.listen do |message|
    if admin?(message)
      show_commands_menu(bot, message)
      case message.text
      when '/start'
        handle_start_command(bot, message)
        show_commands_menu(bot, message)
      when 'Сгенерировать код'
          handle_admin_generate_code(bot, message)
      when 'Сделать пост'
        handle_admin_post_command(bot, message)
      when 'Проверить код'
        handle_admin_check_code(bot, message)
      when '/enter_code'
        handle_user_enter_code(bot, message)
      else
        bot.api.send_message(chat_id: message.chat.id, text: 'Такой команды я не знаю(')
      end
    else
      case message.text
      when '/start'
        handle_start_command(bot, message)
      when '/enter_code'
        handle_user_enter_code(bot, message)
      when '/help'
        show_commands_list(bot, message)
      else
        bot.api.send_message(chat_id: message.chat.id, text: 'Такой команды я не знаю(')
      end
    end
  end
end
