### TTelegramBot class must have wrapper for callbacks. You can use TTelegramBotEx class instead of creating a new one.
```
vBot := TTelegramBotEx.Create('BOT_TOKEN');
vBot.Initialize;
vBot.RegisterDoOnCallbackQuery(
    function(const ACallbackQuery: TTelegramCallbackQuery): Boolean
    begin
      if ACallbackQuery.Data = 'hello_button' then
        vBot.SendMessage(ACallbackQuery.AtMessage.Chat, 'Hello');
    end);
vBot.RegisterDoOnMessage(
    function(const AMessage: TTelegramMessage): Boolean
    var
      vKeyboard: TTelegramInlineKeyboardMarkup;
    begin
      vKeyboard := TTelegramInlineKeyboardMarkup.Create;
      vKeyboard.AddButton('Press me', 'hello_button');
      vBot.SendMessage(AMessage.Chat, 'Hello', vKeyboard);
    end));
repeat
  vBot.Poll; // Receives one update. To keep receiving updates, you need to overwrite StartPolling, in which your thread will pull updates.
until false;
```
