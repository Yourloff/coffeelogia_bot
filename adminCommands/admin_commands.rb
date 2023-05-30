require 'async'

module AdminCommands
  def handle_admin_command(bot, message)
    # Получение всех зарегистрированных пользователей
    users = db.execute('SELECT telegram_id FROM users')
    users.each do |user|
      bot.api.send_message(chat_id: user[0], text: message.text)
    end
  end

  def show_commands_menu(bot, message)
    buttons = [
      [
        { text: 'Сгенерировать код' },
        { text: 'Проверить код' }
      ],
    # Добавьте остальные кнопки команд, если нужно
    ]

    keyboard = Telegram::Bot::Types::ReplyKeyboardMarkup.new(
      keyboard: buttons,
      resize_keyboard: true,
      one_time_keyboard: true
    )
    bot.api.send_message(chat_id: message.chat.id, text: 'Выберите команду:', reply_markup: keyboard)
  end

  def handle_admin_generate_code(bot, message)
    code = generate_code

    existing_code = DB[:daily_codes].first(code: code)

    # Проверка, существует ли код уже в базе данных
    until existing_code.nil?
      code = generate_code
    end

    current_time = Time.now
    formatted_time = current_time.strftime("%d.%m.%Y %H:%M:%S")

    DB[:daily_codes].insert(
      code: code,
      user_telegram_id: message.chat.id,
      created_at: formatted_time
    )
    bot.api.send_message(chat_id: message.chat.id, text: "Сгенерирован код: #{code}")
  end

  def handle_admin_check_code(bot, message)
    Async do
      bot.api.send_message(chat_id: message.chat.id, text: 'Введите код:')

      response = Async do
        bot.listen do |incoming_message|
          if incoming_message.is_a?(Telegram::Bot::Types::Message) && incoming_message.from.id == message.from.id
            entered_code = incoming_message.text.to_s.upcase

            existing_code = DB[:daily_codes].first(code: entered_code)
            if existing_code.nil?
              bot.api.send_message(chat_id: message.chat.id, text: 'Код не найден')
            else
              status = existing_code[:activate?] ? 'АКТИВИРОВАН' : 'НЕАКТИВИРОВАН'
              bot.api.send_message(chat_id: message.chat.id, text: "Код найден, статус: #{status}")
            end
            break
          end
        end
      end
      response.wait
    end
  end

  private

  def generate_code
    # Можно настроить формат и длину кода по своему усмотрению
    letters = ('А'..'Я').to_a
    numbers = (0..9).to_a
    "#{letters.sample(2).join}#{numbers.sample(3).join}"
  end
end