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
      [
        { text: 'Сделать пост' }
      ]
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
              status_bonus = existing_code[:bonus?] ? 'БОНУСНЫЙ код' : 'Код не бонусный'
              bot.api.send_message(chat_id: message.chat.id, text: status_bonus)
            end
            break
          end
        end
      end
      response.wait
    end
  end

  def handle_admin_post_command(bot, message)
    # Проверяем, что отправитель является администратором
    return unless admin?(message)

    # Создаем инлайн-клавиатуру с кнопками "Сделать пост" и "Отмена"
    buttons = [
      [
        Telegram::Bot::Types::InlineKeyboardButton.new(text: 'Сделать пост', callback_data: 'make_post'),
        Telegram::Bot::Types::InlineKeyboardButton.new(text: 'Отмена', callback_data: 'cancel_post')
      ]
    ]
    keyboard = Telegram::Bot::Types::InlineKeyboardMarkup.new(inline_keyboard: buttons)

    # Отправляем сообщение с клавиатурой "Сделать пост" и "Отмена"
    bot.api.send_message(chat_id: message.chat.id, text: 'Нажмите кнопку "Сделать пост" для отправки сообщения всем пользователям.', reply_markup: keyboard)

    # Ожидаем ответ админа
    bot.listen do |incoming_message|
      if incoming_message.is_a?(Telegram::Bot::Types::CallbackQuery)
        case incoming_message.data
        when 'make_post'
          # Админ нажал кнопку "Сделать пост"
          bot.api.send_message(chat_id: message.chat.id, text: 'Введите сообщение для отправки всем пользователям:')
          # Ожидаем ответ админа с сообщением
          bot.listen do |post_message|
            if post_message.is_a?(Telegram::Bot::Types::Message)
              # Админ ввел сообщение, разослать его всем пользователям
              send_message_to_all_users(bot, post_message.text)
              bot.api.send_message(chat_id: message.chat.id, text: 'Сообщение отправлено всем пользователям.')
              break
            end
          end
        when 'cancel_post'
          # Админ нажал кнопку "Отмена"
          bot.api.send_message(chat_id: message.chat.id, text: 'Отправка сообщения всем пользователям отменена.')
          break
        end
      end
    end
    show_commands_menu(bot, message)
  end

  private

  def generate_code
    # Можно настроить формат и длину кода по своему усмотрению
    letters = ('А'..'Я').to_a
    numbers = (0..9).to_a
    "#{letters.sample(2).join}#{numbers.sample(3).join}"
  end

def send_message_to_all_users(bot, message)
  all_users = DB[:users].all

  all_users.each do |user|
    bot.api.send_message(chat_id: user[:telegram_id], text: message)
  end
end
end