require 'async'

module UserCommands

  # количество за которое начисляется скидка
  DISCOUNT = 5

  def handle_start_command(bot, message)
    # проверить наличия пользователя в БД
    existing_user = DB[:users].first(telegram_id: message.chat.id)

    if existing_user
      bot.api.send_message(chat_id: message.chat.id, text: 'А мы вас помним:3')
      # Регистрация пользователя в базе данных
    else
      phone = message.contact&.phone_number

      if phone.nil?
        Async do
          bot.api.send_message(chat_id: message.chat.id, text: 'Введите номер телефона:')
          response = Async do
            bot.listen do |user_phone|
              if user_phone.is_a?(Telegram::Bot::Types::Message) && user_phone.from.id == message.from.id
                phone = user_phone.text
                break
              end
            end
          end
          response.wait
        end
      end

      birthday = ''
      Async do
        bot.api.send_message(chat_id: message.chat.id, text: 'Дата рождения:')
        response = Async do
          bot.listen do |user_birthday|
            if user_birthday.is_a?(Telegram::Bot::Types::Message) && user_birthday.from.id == message.from.id
              birthday = user_birthday.text
              break
            end
          end
        end
        response.wait
      end

      name = ''
      Async do
        bot.api.send_message(chat_id: message.chat.id, text: 'Как к Вам можем обращаться? (Введите имя)')
        response = Async do
          bot.listen do |user_name|
            if user_name.is_a?(Telegram::Bot::Types::Message) && user_name.from.id == message.from.id
              name = user_name.text
              break
            end
          end
        end
        response.wait
      end

      DB[:users].insert(
        telegram_id: message.chat.id,
        nickname: message.from.username || '',
        name: name,
        phone: phone,
        birthday: birthday
      )

      bot.api.send_message(chat_id: message.chat.id, text: 'Добро пожаловать!')
    end
  end

  def show_commands_list(bot, message)
    commands = [
      '/start - Начать',
      '/help - Показать список команд',
      '/gen - Сгенерировать код',
    # Добавьте остальные команды, если нужно
    ]

    response = "Список команд:\n\n"
    response += commands.join("\n")

    bot.api.send_message(chat_id: message.chat.id, text: response)
  end

  def admin?(message)
    user_id = if message.is_a?(Telegram::Bot::Types::CallbackQuery)
                DB[:users].first(telegram_id: message.from.id)
              elsif message.is_a?(Telegram::Bot::Types::Message)
                DB[:users].first(telegram_id: message.chat.id)
              end

    user_id && user_id[:admin]
  end

  def send_command_list(bot, chat_id)
    commands = [
      { command: '/next', description: 'Перейти к следующему элементу' },
      { command: '/cancel', description: 'Отменить текущую операцию' },
      { command: '/newlocation', description: 'Создать новое местоположение' },
      { command: '/newrule', description: 'Создать новое правило' }
    ]

    buttons = commands.map { |cmd| Telegram::Bot::Types::InlineKeyboardButton.new(text: cmd[:command], callback_data: cmd[:command]) }
    keyboard = Telegram::Bot::Types::InlineKeyboardMarkup.new(inline_keyboard: buttons.each_slice(2).to_a)

    bot.api.send_message(chat_id: chat_id, text: 'Поддерживаемые команды:', reply_markup: keyboard)
  end

  def handle_user_enter_code(bot, message)
    #Async do
      bot.api.send_message(chat_id: message.chat.id, text: 'Введите код:')

      # response = Async do
        bot.listen do |incoming_message|
          if incoming_message.is_a?(Telegram::Bot::Types::Message) && incoming_message.from.id == message.from.id
            entered_code = incoming_message.text.to_s.upcase

            barista_code = DB[:daily_codes].first(code: entered_code)
            if barista_code.nil?
              bot.api.send_message(chat_id: message.chat.id, text: 'Неверно указан код')
            else
              status = barista_code[:activate?] ? 'АКТИВИРОВАН' : 'НЕАКТИВИРОВАН'
              if status == 'НЕАКТИВИРОВАН'
                user = get_user(message)
                if user
                  temp_count = 0

                  unless check_birthday(user[:birthday])
                    updated_discount = user[:all_discount] + 1

                    # обновить счётчик количества приобретённого кофе
                    DB[:users].where(telegram_id: user[:telegram_id]).update(all_discount: updated_discount)

                    # активировать код activate? = true
                    DB[:daily_codes].where(code: barista_code[:code]).update(activate?: true)

                    user = get_user(message)

                    rounded = rounded_count_discount(user[:all_discount])
                    remains = rounded - user[:all_discount]
                    temp_count = DISCOUNT - (rounded - user[:all_discount])
                  end

                  # проверка на день рождение
                  if check_birthday(user[:birthday])
                    # отметить код как бонусный
                    DB[:daily_codes].where(code: barista_code[:code]).update(bonus?: true)

                    bot.api.send_message(chat_id: message.chat.id, text: "✅ Вы активировали код. " \
                    "Приходите еще, как всегда рады Вас видеть ❤ \n\n" \
                    "Поздравляем, Вас с Днём рождения, Вам предоставляется на него скидка 15%\n" \
                    "🤩 #{barista_code[:code]}"
                    )

                    bot.api.send_message(chat_id: barista_code[:user_telegram_id], text: "Сегодня у клиента День рождения #{user[:name]} #{user[:phone]} предоставляется скидка 15%. Код - #{barista_code[:code]}")
                  elsif temp_count == DISCOUNT
                    bot.api.send_message(chat_id: message.chat.id, text: "✅ Вы активировали код. " \
                    "Приходите еще, как всегда рады Вас видеть ❤ \n\n" \
                    "Поздравляем, Вы заказали очередной 5-ый кофе, Вам предоставляется на него скидка 15%\n" \
                    "🤩 #{barista_code[:code]}"
                    )

                    bot.api.send_message(chat_id: barista_code[:user_telegram_id], text: "Клиенту #{user[:name]} #{user[:phone]} предоставляется скидка 15%. Код - #{barista_code[:code]}")
                  else
                    bot.api.send_message(chat_id: message.chat.id, text: "✅ Вы активировали код. " \
                    "Приходите еще, как всегда рады Вас видеть ❤ \n\n" \
                    "#{temp_count} / #{DISCOUNT}. Еще #{remains} кофе до получения скидки в 15%!"
                    )
                  end

                  # добавить клиента, кто активировал код
                  DB[:daily_codes].where(code: barista_code[:code]).update(client_id: user[:telegram_id])
                end
              else
                bot.api.send_message(chat_id: message.chat.id, text: "❌ этот код активирован: #{entered_code}")
              end
            end
            break
          end
        end
        #end
      #response.wait
      #end
  end

  private

  # округлить количество заказанного кофе до числа кратного 5. 12 => 15
  def rounded_count_discount(num)
    return 0 if num == 0

    (num.to_f / DISCOUNT).ceil * DISCOUNT
  end

  # получить пользователя
  def get_user(message)
    DB[:users].first(telegram_id: message.chat.id)
  end

  # проверить дату рождения клиента, для предоставления скидки
  def check_birthday(birthday)
    Time.now.strftime("%d.%m") == Date.parse(birthday).strftime("%d.%m") ? true : false
  end
end
