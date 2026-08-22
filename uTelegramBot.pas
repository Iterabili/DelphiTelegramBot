unit uTelegramBot;

interface

uses
  System.Classes, System.SysUtils, System.Generics.Collections,
  uTelegramTypes, Net.URLClient, Net.HttpClient, JSON, Types, uTelegramSendQueue;

type
  TTelegramBot = class;
  TTelegramUpdateType = (tutNone, tutMessage, tutCallbackQuery);

  // TIntArray = array of Integer;
  // TIntDoubleArray = array of TIntArray;

  TTelegramBot = class
  private
    FBotToken: string;
    FLastUpdate: UInt64;

    FHTTPClient: THTTPClient;
    FBotUrl: string;
    FLog: TFileStream;

    procedure ProceedMessage(const AUpdate: TJSONObject);
    procedure ProceedCallbackQuery(const AUpdate: TJSONObject);

    function GetUpdate: TJSONObject;
    function GetUpdateType(const AUpdate: TJSONObject): TTelegramUpdateType;
    function PostMethod(const AMethodName: String; const AParams: TStringList;
      const AReplyMarkup: TTelegramKeyboardMarkup = nil): string;
    procedure PostMethodAsync(const AMethodName: String; const AParams: TStringList; const AKind: TTelegramQueueKind;
      const AReplyMarkup: TTelegramKeyboardMarkup = nil; const AOnSent: TProc<string> = nil);

    procedure SetBotToken(const Value: string);
  protected
    FStartTime: Int64; // unix
    function GetMe: string;
    function DoOnMessage(const AMessage: TTelegramMessage): Boolean; virtual;
    function DoOnCallbackQuery(const ACallbackQuery: TTelegramCallbackQuery): Boolean; virtual;
  public
    constructor Create(const AToken: string); virtual;
    destructor Destroy; override;

    procedure Poll; virtual;
    procedure ProcessUpdate(const AUpdate: TJSONObject);
    procedure StartPolling; virtual;
    procedure SetWebhook(const AUrl: string; const ASecretToken: string = ''; const ACertPath: string = '');
    procedure DeleteWebhook;

    procedure AnswerCallbackQuery(const ACallbackId: String; const AMessage: string = '');
    procedure SetMyCommands(const ACommands: TStringList);
    procedure SetMyDescription(const ADescription: string; const ALanguageCode: string = '');
    procedure SetMyShortDescription(const AShortDescription: string; const ALanguageCode: string = '');

    function GetChat(const AChat: string): TTelegramChat;
    function SendPhoto(const AChatId, APhotoId: string; const AText: string = '';
      const AReplyMarkup: TTelegramKeyboardMarkup = nil; const ASpoiler: Boolean = False;
      const AOnSent: TProc<string> = nil; const AKind: TTelegramQueueKind = tqkSend): string; overload;
    // Отправить фото напрямую из потока (без временного файла на диске). Забирает владение AStream.
    function SendPhoto(const AChatId: string; const AStream: TStream; const AFileName: string;
      const AText: string = ''; const AReplyMarkup: TTelegramKeyboardMarkup = nil;
      const ASpoiler: Boolean = False): string; overload;
    procedure SendDocument(const AChatId, ADocumentId: string; const AText: string = '';
      const AReplyMarkup: TTelegramKeyboardMarkup = nil);
    procedure SendFile(const AChatId, AFilename: string; const AText: string = '');
    procedure GetFile(const AFileId: string; const AOnSent: TProc<string>);

    procedure SendMediaGroup(const AChatId: string; const AMedia: TList<string>; const AType: TTelegramMediaType;
      const AText: string = '');

    procedure CopyMessage(const ATargetChat: string; const AMessage: TTelegramMessage); overload;

    function SendMessage(const AChatId, AText: string; const AReplyMarkup: TTelegramKeyboardMarkup = nil;
      const AOnSent: TProc<string> = nil; const AKind: TTelegramQueueKind = tqkSend): string;
    function EditMessageText(const AMessage: TTelegramMessage; const AText: string;
      const AReplyMarkup: TTelegramInlineKeyboardMarkup = nil; const AOnSent: TProc<string> = nil): string;
    function EditMessageCaption(const AMessage: TTelegramMessage; const ACaption: string;
      const AReplyMarkup: TTelegramInlineKeyboardMarkup = nil): string;
    function ForwardMessage(const AMessage: TTelegramMessage; const ATelegramId: string): string;
    function CopyMessage(const ATargetChat, AFromChat: string; const AMessageId: Integer;
      const AOnSent: TProc<string> = nil; const AKind: TTelegramQueueKind = tqkSend): string; overload;

    procedure SendMessageResulted(const AChatId, AText: string; const AReplyMarkup: TTelegramKeyboardMarkup;
      const AOnSent: TProc<TTelegramMessage>);
    function SendPhotoResulted(const AChatId, APhotoId: string): string;
    procedure EditMessageTextResulted(const AMessage: TTelegramMessage; const AText: string;
      const AReplyMarkup: TTelegramInlineKeyboardMarkup; const AOnSent: TProc<TTelegramMessage>);

    procedure EditMessageMedia(const AMessage: TTelegramMessage; const AMedia: string; const ACaption: string = '';
      const AReplyMarkup: TTelegramInlineKeyboardMarkup = nil);
    procedure EditMessageReplyMarkup(const AMessage: TTelegramMessage;
      const AReplyMarkup: TTelegramInlineKeyboardMarkup);

    procedure DeleteMessage(const AMessage: TTelegramMessage);
    procedure DeleteKeyboard(const AMessage: TTelegramMessage);

    function Url: string;

    property BotToken: string read FBotToken write SetBotToken;
  end;

implementation

uses
  Variants, NetEncoding, Net.Mime, DateUtils, uJSONHelper;

const
  cTelegramBotUrl = 'https://api.telegram.org/bot';

  { TTelegramBot }

procedure TTelegramBot.AnswerCallbackQuery(const ACallbackId: String; const AMessage: string);
var
  vParams: TStringList;
begin
  vParams := TStringList.Create;
  try
    vParams.Append('callback_query_id=' + ACallbackId);
    if AMessage <> '' then
    begin
      vParams.Append('text=' + AMessage);
      vParams.Append('show_alert=true');
    end;

    PostMethodAsync('answerCallbackQuery', vParams, tqkControl, nil);
  finally
    FreeAndNil(vParams);
  end;
end;

procedure TTelegramBot.SetMyCommands(const ACommands: TStringList);
var
  vParams: TStringList;
  vCommandsJSON: TJSONArray;
  vCommandObj: TJSONObject;
  I: Integer;
begin
  vParams := TStringList.Create;
  vCommandsJSON := TJSONArray.Create;
  try
    for I := 0 to ACommands.Count - 1 do
    begin
      vCommandObj := TJSONObject.Create;
      vCommandObj.StoreString('command', ACommands.Names[I]);
      vCommandObj.StoreString('description', ACommands.Values[ACommands.Names[I]]);
      vCommandsJSON.Add(vCommandObj);
    end;
    vParams.Append('commands=' + vCommandsJSON.ToJSON);
    PostMethodAsync('setMyCommands', vParams, tqkControl, nil);
  finally
    FreeAndNil(vCommandsJSON);
    FreeAndNil(vParams);
  end;
end;

procedure TTelegramBot.SetMyDescription(const ADescription, ALanguageCode: string);
var
  vParams: TStringList;
begin
  vParams := TStringList.Create;
  try
    vParams.Append('description=' + ADescription);
    if ALanguageCode <> '' then
      vParams.Append('language_code=' + ALanguageCode);
    PostMethodAsync('setMyDescription', vParams, tqkControl, nil);
  finally
    FreeAndNil(vParams);
  end;
end;

procedure TTelegramBot.SetMyShortDescription(const AShortDescription, ALanguageCode: string);
var
  vParams: TStringList;
begin
  vParams := TStringList.Create;
  try
    vParams.Append('short_description=' + AShortDescription);
    if ALanguageCode <> '' then
      vParams.Append('language_code=' + ALanguageCode);
    PostMethodAsync('setMyShortDescription', vParams, tqkControl, nil);
  finally
    FreeAndNil(vParams);
  end;
end;

function TTelegramBot.CopyMessage(const ATargetChat, AFromChat: string; const AMessageId: Integer;
  const AOnSent: TProc<string>; const AKind: TTelegramQueueKind): string;
var
  vParams: TStringList;
begin
  Result := '';
  vParams := TStringList.Create;
  try
    vParams.Append('chat_id=' + ATargetChat);
    vParams.Append('from_chat_id=' + AFromChat);
    vParams.Append('message_id=' + IntToStr(AMessageId));

    PostMethodAsync('copyMessage', vParams, AKind, nil, AOnSent);
  finally
    FreeAndNil(vParams);
  end;
end;

procedure TTelegramBot.CopyMessage(const ATargetChat: string; const AMessage: TTelegramMessage);
var
  vOnSent: TProc<string>;
begin
  vOnSent :=
    procedure(AResponse: string)
    var
      vAnswer, vResult: TJSONObject;
    begin
      vAnswer := TJSONObject.LoadFromText(AResponse);
      try
        if not Assigned(vAnswer) then
          Exit;
        vResult := vAnswer.ExtractObject('result');
        if not Assigned(vResult) then
          Exit;
        AMessage.MessageId := vResult.ExtractInteger('message_id');
        AMessage.Chat := ATargetChat;
      finally
        FreeAndNil(vAnswer);
      end;
    end;
  CopyMessage(ATargetChat, AMessage.Chat, AMessage.MessageId, vOnSent);
end;

constructor TTelegramBot.Create(const AToken: string);
//var
//  vLogName: string;
begin
  BotToken := AToken;
  FLastUpdate := 0;
  FStartTime := DateTimeToUnix(Now, False);

  FHTTPClient := THTTPClient.Create;
  FHTTPClient.SecureProtocols := [THTTPSecureProtocol.TLS1, THTTPSecureProtocol.TLS11, THTTPSecureProtocol.TLS12,
    THTTPSecureProtocol.TLS13];
  FHTTPClient.HandleRedirects := True;

//  try
//    vLogName := GetMe;
//  except
//    vLogName := 'bot_log.txt';
//  end;
//
//  if vLogName = '' then
//    vLogName := 'bot_log.txt';
//
//  if FileExists(vLogName) then
//    FLog := TFileStream.Create(vLogName, fmOpenReadWrite or fmShareDenyNone)
//  else
//    FLog := TFileStream.Create(vLogName, fmCreate or fmOpenWrite or fmShareDenyNone);

//  FLog.Position := FLog.Size;
end;

procedure TTelegramBot.DeleteKeyboard(const AMessage: TTelegramMessage);
var
  vKeyboard: TTelegramInlineKeyboardMarkup;
begin
  vKeyboard := TTelegramInlineKeyboardMarkup.Create;
  try
    EditMessageReplyMarkup(AMessage, vKeyboard);
  finally
    FreeAndNil(vKeyboard);
  end;
end;

procedure TTelegramBot.DeleteMessage(const AMessage: TTelegramMessage);
var
  vParams: TStringList;
begin
  vParams := TStringList.Create;
  try
    vParams.Append('chat_id=' + AMessage.Chat);
    vParams.Append('message_id=' + IntToStr(AMessage.MessageId));
    PostMethodAsync('deleteMessage', vParams, tqkControl);
  finally
    FreeAndNil(vParams);
  end;
end;

destructor TTelegramBot.Destroy;
begin
  FreeAndNil(FHTTPClient);
  FreeAndNil(FLog);

  inherited Destroy;
end;

function TTelegramBot.EditMessageText(const AMessage: TTelegramMessage; const AText: string;
  const AReplyMarkup: TTelegramInlineKeyboardMarkup; const AOnSent: TProc<string>): string;
var
  vParams: TStringList;
begin
  Result := '';
  if not Assigned(AMessage) then
    Exit;
  vParams := TStringList.Create;
  try
    vParams.Append('chat_id=' + AMessage.Chat);
    vParams.Append('message_id=' + IntToStr(AMessage.MessageId));
    vParams.Append('text=' + AText);
    AMessage.Text := AText;

    PostMethodAsync('editMessageText', vParams, tqkControl, AReplyMarkup, AOnSent);
  finally
    FreeAndNil(vParams);
  end;
end;

procedure TTelegramBot.EditMessageTextResulted(const AMessage: TTelegramMessage; const AText: string;
  const AReplyMarkup: TTelegramInlineKeyboardMarkup; const AOnSent: TProc<TTelegramMessage>);
begin
  if not Assigned(AMessage) then
  begin
    if Assigned(AOnSent) then
      AOnSent(nil);
    Exit;
  end;
  EditMessageText(AMessage, AText, AReplyMarkup,
    procedure(AResponse: string)
    var
      vJSON, vResultObj: TJSONObject;
      vMessage: TTelegramMessage;
    begin
      vMessage := nil;
      vJSON := TJSONObject.LoadFromText(AResponse);
      try
        vResultObj := vJSON.ExtractObject('result');
        if Assigned(vResultObj) then
          vMessage := TTelegramMessage.Create(vResultObj);
      finally
        FreeAndNil(vJSON);
      end;
      if Assigned(AOnSent) then
        AOnSent(vMessage);
    end);
end;

function TTelegramBot.ForwardMessage(const AMessage: TTelegramMessage; const ATelegramId: string): string;
var
  vParams: TStringList;
begin
  if not Assigned(AMessage) then
    Exit;
  vParams := TStringList.Create;
  try
    vParams.Append('chat_id=' + ATelegramId);
    vParams.Append('from_chat_id=' + AMessage.Chat);
    vParams.Append('message_id=' + IntToStr(AMessage.MessageId));

    Result := PostMethod('forwardMessage', vParams);
  finally
    FreeAndNil(vParams);
  end;
end;

function TTelegramBot.EditMessageCaption(const AMessage: TTelegramMessage; const ACaption: string;
  const AReplyMarkup: TTelegramInlineKeyboardMarkup): string;
var
  vParams: TStringList;
begin
  if not Assigned(AMessage) then
    Exit;
  vParams := TStringList.Create;
  try
    vParams.Append('chat_id=' + AMessage.Chat);
    vParams.Append('message_id=' + IntToStr(AMessage.MessageId));
    vParams.Append('caption=' + ACaption);

    Result := PostMethod('editMessageCaption', vParams, AReplyMarkup);
  finally
    FreeAndNil(vParams);
  end;
end;

procedure TTelegramBot.EditMessageMedia(const AMessage: TTelegramMessage; const AMedia: string;
  const ACaption: string = ''; const AReplyMarkup: TTelegramInlineKeyboardMarkup = nil);
var
  vTargetUrl, vChatId, vReplyMarkupText, vMediaText, vFilePath: string;
  vMessageId: Integer;
  vIsFile: Boolean;
  vMediaJSON: TJSONObject;
begin
  if not Assigned(AMessage) then
    Exit;
  vTargetUrl := FBotUrl + '/editMessageMedia';
  vChatId := AMessage.Chat;
  vMessageId := AMessage.MessageId;
  vReplyMarkupText := '';
  if Assigned(AReplyMarkup) then
    vReplyMarkupText := AReplyMarkup.ToString;

  vIsFile := Pos('.', AMedia) > 0;
  vFilePath := AMedia;
  vMediaJSON := TJSONObject.Create;
  try
    vMediaJSON.StoreString('type', 'photo');
    if ACaption <> '' then
      vMediaJSON.StoreString('caption', ACaption);
    if vIsFile then
      vMediaJSON.StoreString('media', 'attach://photo')
    else
      vMediaJSON.StoreString('media', AMedia);
    vMediaText := vMediaJSON.ToJSON;
  finally
    FreeAndNil(vMediaJSON);
  end;

  TTelegramSendQueue.Enqueue(
    procedure
    var
      vMPD: TMultipartFormData;
    begin
      vMPD := TMultipartFormData.Create;
      try
        vMPD.AddField('chat_id', vChatId);
        vMPD.AddField('message_id', IntToStr(vMessageId));
        vMPD.AddField('media', vMediaText);
        if vIsFile then
          vMPD.AddFile('photo', vFilePath);
        if vReplyMarkupText <> '' then
          vMPD.AddField('reply_markup', vReplyMarkupText);
        TTelegramSendQueue.HTTPClient(tqkControl).Post(vTargetUrl, vMPD);
      finally
        FreeAndNil(vMPD);
      end;
    end, tqkControl);
end;

procedure TTelegramBot.EditMessageReplyMarkup(const AMessage: TTelegramMessage;
  const AReplyMarkup: TTelegramInlineKeyboardMarkup);
var
  vParams: TStringList;
begin
  if not Assigned(AMessage) then
    Exit;
  vParams := TStringList.Create;
  try
    vParams.Append('chat_id=' + AMessage.Chat);
    vParams.Append('message_id=' + IntToStr(AMessage.MessageId));

    PostMethodAsync('editMessageReplyMarkup', vParams, tqkControl, AReplyMarkup);
  finally
    FreeAndNil(vParams);
  end;
end;

procedure TTelegramBot.SendDocument(const AChatId, ADocumentId, AText: string;
  const AReplyMarkup: TTelegramKeyboardMarkup);
var
  vParams: TStringList;
begin
  vParams := TStringList.Create;
  try
    vParams.Append('chat_id=' + AChatId);
    vParams.Append('document=' + ADocumentId);
    if Length(AText) > 0 then
      vParams.Append('caption=' + AText);
    PostMethodAsync('sendDocument', vParams, tqkSend, AReplyMarkup);
  finally
    FreeAndNil(vParams);
  end;
end;

procedure TTelegramBot.SendFile(const AChatId, AFilename, AText: string);
var
  vTargetUrl, vChatId, vText, vFileName: string;
begin
  vTargetUrl := FBotUrl + '/sendDocument';
  vChatId := AChatId;
  vText := AText;
  vFileName := AFilename;

  TTelegramSendQueue.Enqueue(
    procedure
    var
      vMPD: TMultipartFormData;
      vFileStream: TFileStream;
    begin
      vMPD := TMultipartFormData.Create;
      try
        vMPD.AddField('chat_id', vChatId);
        if vText <> '' then
          vMPD.AddField('text', vText);
        vFileStream := TFileStream.Create(vFileName, fmOpenRead or fmShareDenyNone);
        vMPD.AddStream('document', vFileStream, True, ExtractFileName(vFileName));
        TTelegramSendQueue.HTTPClient(tqkSend).Post(vTargetUrl, vMPD);
      finally
        FreeAndNil(vMPD);
      end;
    end, tqkSend);
end;

procedure TTelegramBot.SendMediaGroup(const AChatId: string; const AMedia: TList<string>;
  const AType: TTelegramMediaType; const AText: string);
var
  vParams: TStringList;
  vMediaGroup: TJSONArray;
  vMedia: TJSONObject;
  vMediaId: string;
begin
  vParams := TStringList.Create;
  vMediaGroup := TJSONArray.Create;
  try
    vParams.Append('chat_id=' + AChatId);
    for vMediaId in AMedia do
    begin
      vMedia := TJSONObject.Create;
      case AType of
        tmtPhoto:
          vMedia.StoreString('type', 'photo');
      end;
      vMedia.StoreString('media', vMediaId);
      vMediaGroup.Add(vMedia);
    end;
    if (Length(AText) > 0) then
      TJSONObject(vMediaGroup.Items[0]).StoreString('caption', AText);
    vParams.Append('media=' + vMediaGroup.ToJSON);

    PostMethodAsync('sendMediaGroup', vParams, tqkSend, nil);
  finally
    FreeAndNil(vMediaGroup);
    FreeAndNil(vParams);
  end;
end;

function TTelegramBot.SendMessage(const AChatId, AText: string; const AReplyMarkup: TTelegramKeyboardMarkup;
  const AOnSent: TProc<string>; const AKind: TTelegramQueueKind): string;
var
  vParams: TStringList;
begin
  Result := '';
  vParams := TStringList.Create;
  try
    vParams.Append('chat_id=' + AChatId);
    vParams.Append('text=' + AText);
    PostMethodAsync('sendMessage', vParams, AKind, AReplyMarkup, AOnSent);
  finally
    FreeAndNil(vParams);
  end;
end;

procedure TTelegramBot.SendMessageResulted(const AChatId, AText: string; const AReplyMarkup: TTelegramKeyboardMarkup;
  const AOnSent: TProc<TTelegramMessage>);
begin
  SendMessage(AChatId, AText, AReplyMarkup,
    procedure(AResponse: string)
    var
      vJSON, vResultObj: TJSONObject;
      vMessage: TTelegramMessage;
    begin
      vMessage := nil;
      vJSON := TJSONObject.LoadFromText(AResponse);
      try
        vResultObj := vJSON.ExtractObject('result');
        if Assigned(vResultObj) then
          vMessage := TTelegramMessage.Create(vResultObj);
      finally
        FreeAndNil(vJSON);
      end;
      if Assigned(AOnSent) then
        AOnSent(vMessage);
    end);
end;

function TTelegramBot.SendPhotoResulted(const AChatId, APhotoId: string): string;
var
  vJSON: TJSONObject;
  vResult: TJSONObject;
  vPhotos: TJSONArray;
begin
  Result := '';
  try
    vJSON := TJSONObject.LoadFromText(SendPhoto(AChatId, APhotoId));
    vResult := vJSON.ExtractObject('result');
    if not Assigned(vResult) then
      Exit;
    vPhotos := vResult.ExtractArray('photo');
    if not Assigned(vPhotos) or (vPhotos.Count = 0) then
      Exit;
    Result := TJSONObject(vPhotos.Items[vPhotos.Count - 1]).ExtractString('file_id');
  finally
    FreeAndNil(vJSON);
  end;
end;

function TTelegramBot.SendPhoto(const AChatId, APhotoId, AText: string; const AReplyMarkup: TTelegramKeyboardMarkup;
  const ASpoiler: Boolean; const AOnSent: TProc<string>; const AKind: TTelegramQueueKind): string;
var
  vTargetUrl, vChatId, vPhotoId, vText, vReplyMarkupText: string;
  vSpoiler, vIsFile: Boolean;
  vKind: TTelegramQueueKind;
begin
  Result := '';
  vTargetUrl := FBotUrl + '/sendPhoto';
  vChatId := AChatId;
  vPhotoId := APhotoId;
  vText := AText;
  vSpoiler := ASpoiler;
  vIsFile := Pos('.', APhotoId) > 0;
  vReplyMarkupText := '';
  vKind := AKind;
  if Assigned(AReplyMarkup) then
    vReplyMarkupText := AReplyMarkup.ToString;

  TTelegramSendQueue.EnqueueWithCallback<string>(
    function: string
    var
      vMPD: TMultipartFormData;
    begin
      Result := '';
      vMPD := TMultipartFormData.Create;
      try
        vMPD.AddField('chat_id', vChatId);
        vMPD.AddField('has_spoiler', BoolToStr(vSpoiler, True));
        if vText <> '' then
          vMPD.AddField('caption', vText);
        if vIsFile then
          vMPD.AddFile('photo', vPhotoId)
        else
          vMPD.AddField('photo', vPhotoId);
        if vReplyMarkupText <> '' then
          vMPD.AddField('reply_markup', vReplyMarkupText);
        Result := TTelegramSendQueue.HTTPClient(vKind).Post(vTargetUrl, vMPD).ContentAsString;
      finally
        FreeAndNil(vMPD);
      end;
    end,
    AOnSent, AKind);
end;

function TTelegramBot.SendPhoto(const AChatId: string; const AStream: TStream; const AFileName, AText: string;
  const AReplyMarkup: TTelegramKeyboardMarkup; const ASpoiler: Boolean): string;
var
  vTargetUrl, vChatId, vFileName, vText, vReplyMarkupText: string;
  vSpoiler: Boolean;
  vOwnedStream: TStream;
begin
  Result := '';
  vTargetUrl := FBotUrl + '/sendPhoto';
  vChatId := AChatId;
  vFileName := AFileName;
  vText := AText;
  vSpoiler := ASpoiler;
  vOwnedStream := AStream;
  vReplyMarkupText := '';
  if Assigned(AReplyMarkup) then
    vReplyMarkupText := AReplyMarkup.ToString;

  TTelegramSendQueue.Enqueue(
    procedure
    var
      vMPD: TMultipartFormData;
    begin
      vMPD := TMultipartFormData.Create;
      try
        vMPD.AddField('chat_id', vChatId);
        vMPD.AddField('has_spoiler', BoolToStr(vSpoiler, True));
        if vText <> '' then
          vMPD.AddField('caption', vText);
        vMPD.AddStream('photo', vOwnedStream, True, vFileName);
        if vReplyMarkupText <> '' then
          vMPD.AddField('reply_markup', vReplyMarkupText);
        TTelegramSendQueue.HTTPClient(tqkSend).Post(vTargetUrl, vMPD);
      finally
        FreeAndNil(vMPD);
      end;
    end, tqkSend);
end;

procedure TTelegramBot.SetBotToken(const Value: string);
begin
  FBotToken := Value;
  FBotUrl := cTelegramBotUrl + FBotToken;
end;

function TTelegramBot.Url: string;
begin
  Result := 'https://api.telegram.org/file/bot' + FBotToken;
end;

function TTelegramBot.GetChat(const AChat: string): TTelegramChat;
var
  vParams: TStringList;
  vResult, vChat: TJSONObject;
begin
  Result := nil;
  vParams := TStringList.Create;
  try
    vParams.Append('chat_id=' + AChat);
    vResult := TJSONObject.LoadFromText(PostMethod('getChat', vParams));
    vChat := vResult.ExtractObject('result');
    if Assigned(vChat) then
      Result := TTelegramChat.Create(vChat);
  finally
    FreeAndNil(vParams);
    FreeAndNil(vResult);
  end;
end;

procedure TTelegramBot.GetFile(const AFileId: string; const AOnSent: TProc<string>);
var
  vParams: TStringList;
begin
  vParams := TStringList.Create;
  try
    vParams.Append('file_id=' + AFileId);
    PostMethodAsync('getFile', vParams, tqkControl, nil,
      procedure(AResponse: string)
      var
        vResult, vRes: TJSONObject;
        vFilePath: string;
      begin
        vFilePath := '';
        vResult := TJSONObject.LoadFromText(AResponse);
        try
          vRes := vResult.ExtractObject('result');
          if Assigned(vRes) then
            vFilePath := vRes.ExtractString('file_path');
        finally
          FreeAndNil(vResult);
        end;
        if Assigned(AOnSent) then
          AOnSent(vFilePath);
      end);
  finally
    FreeAndNil(vParams);
  end;
end;

function TTelegramBot.GetMe: string;
var
  vBot, vResult: TJSONObject;
  vParams: TStringList;
begin
  Result := '';
  vParams := TStringList.Create;
  try
    vResult := TJSONObject.LoadFromText(PostMethod('getMe', vParams));
    if Assigned(vResult) then
    begin
      vBot := vResult.ExtractObject('result');
      Result := vBot.ExtractString('username');
    end;
  finally
    FreeAndNil(vParams);
    FreeAndNil(vResult);
  end;
end;

function TTelegramBot.PostMethod(const AMethodName: String; const AParams: TStringList;
  const AReplyMarkup: TTelegramKeyboardMarkup): string;
var
  vTargetUrl: string;
  vMPD: TMultipartFormData;
  I: Integer;
begin
  vTargetUrl := FBotUrl + '/' + AMethodName;
  try
    vMPD := TMultipartFormData.Create;
    for I := 0 to AParams.Count - 1 do
      vMPD.AddField(AParams.Names[I], AParams.Values[AParams.Names[I]]);
    if Assigned(AReplyMarkup) then
      vMPD.AddField('reply_markup', AReplyMarkup.ToString);
    Result := FHTTPClient.Post(TNetEncoding.Url.Encode(vTargetUrl, [], [TURLEncoding.TEncodeOption.SpacesAsPlus]), vMPD)
      .ContentAsString;
  finally
    FreeAndNil(vMPD);
  end
end;

procedure TTelegramBot.PostMethodAsync(const AMethodName: string; const AParams: TStringList;
  const AKind: TTelegramQueueKind; const AReplyMarkup: TTelegramKeyboardMarkup; const AOnSent: TProc<string>);
var
  vTargetUrl: string;
  vParamsCopy: TStringList;
  vReplyMarkupText: string;
begin
  vTargetUrl := TNetEncoding.Url.Encode(FBotUrl + '/' + AMethodName, [], [TURLEncoding.TEncodeOption.SpacesAsPlus]);
  vParamsCopy := TStringList.Create;
  vParamsCopy.Assign(AParams);
  vReplyMarkupText := '';
  if Assigned(AReplyMarkup) then
    vReplyMarkupText := AReplyMarkup.ToString;

  TTelegramSendQueue.EnqueueWithCallback<string>(
    function: string
    var
      vMPD: TMultipartFormData;
      I: Integer;
    begin
      Result := '';
      vMPD := TMultipartFormData.Create;
      try
        for I := 0 to vParamsCopy.Count - 1 do
          vMPD.AddField(vParamsCopy.Names[I], vParamsCopy.Values[vParamsCopy.Names[I]]);
        if vReplyMarkupText <> '' then
          vMPD.AddField('reply_markup', vReplyMarkupText);
        Result := TTelegramSendQueue.HTTPClient(AKind).Post(vTargetUrl, vMPD).ContentAsString;
      finally
        FreeAndNil(vMPD);
        vParamsCopy.Free;
      end;
    end,
    AOnSent, AKind);
end;

function TTelegramBot.GetUpdate: TJSONObject;
var
  vParams: TStringList;
  vAnswer: TJSONObject;
  vUpdate: TJSONObject;
  vArray: TJSONArray;
{$IFDEF DEBUG}
//  vRes: string;
{$ENDIF}
begin
  Result := nil;
  vParams := TStringList.Create;
  vParams.Add('offset=' + IntToStr(FLastUpdate));
  vParams.Add('limit=1');
  vParams.Add('timeout=1');
  vAnswer := TJSONObject.LoadFromText(PostMethod('getUpdates', vParams));
  try
    if Assigned(vAnswer) then
    begin
      vArray := vAnswer.ExtractArray('result');
      if Assigned(vArray) and (vArray.Count > 0) then
      begin
        vUpdate := TJSONObject(vArray.Items[0]);
        if Assigned(vUpdate) then
        begin
          Result := TJSONObject(vUpdate.Clone);
{$IFDEF DEBUG}
//          vRes := Result.ToString;
//          FLog.Write(vRes[1], Length(vRes)*2);
{$ENDIF}
          FLastUpdate := Result.ExtractInteger('update_id') + 1;
        end;
      end;
    end;
  finally
    FreeAndNil(vParams);
    FreeAndNil(vAnswer);
  end;
end;

function TTelegramBot.GetUpdateType(const AUpdate: TJSONObject): TTelegramUpdateType;
begin
  Result := tutNone;
  if not Assigned(AUpdate) then
    Exit;

  if AUpdate.Contains('message') then
    Exit(tutMessage);
  if AUpdate.Contains('callback_query') then
    Exit(tutCallbackQuery);
end;

function TTelegramBot.DoOnMessage(const AMessage: TTelegramMessage): Boolean;
begin
  Result := False;
end;

function TTelegramBot.DoOnCallbackQuery(const ACallbackQuery: TTelegramCallbackQuery): Boolean;
begin
  Result := False;
end;

procedure TTelegramBot.ProceedMessage(const AUpdate: TJSONObject);
var
  vMessage: TTelegramMessage;
begin
  vMessage := TTelegramMessage.Create(AUpdate.ExtractObject('message'));
  try
    if vMessage.From.Id <> '' then
      DoOnMessage(vMessage);
  finally
    FreeAndNil(vMessage);
  end;
end;

procedure TTelegramBot.ProceedCallbackQuery(const AUpdate: TJSONObject);
var
  vCallbackQuery: TTelegramCallbackQuery;
begin
  vCallbackQuery := TTelegramCallbackQuery.Create(AUpdate.ExtractObject('callback_query'));
  try
    if DoOnCallbackQuery(vCallbackQuery) then
      AnswerCallbackQuery(vCallbackQuery.Id);
  finally
    FreeAndNil(vCallbackQuery);
  end;
end;

procedure TTelegramBot.Poll;
var
  vUpdate: TJSONObject;
begin
  try
    vUpdate := GetUpdate;
    case GetUpdateType(vUpdate) of
      tutMessage:
        ProceedMessage(vUpdate);
      tutCallbackQuery:
        ProceedCallbackQuery(vUpdate);
    end;
  finally
    FreeAndNil(vUpdate);
  end;
end;

procedure TTelegramBot.ProcessUpdate(const AUpdate: TJSONObject);
begin
  case GetUpdateType(AUpdate) of
    tutMessage:
      ProceedMessage(AUpdate);
    tutCallbackQuery:
      ProceedCallbackQuery(AUpdate);
  end;
end;

procedure TTelegramBot.StartPolling;
begin
end;

procedure TTelegramBot.SetWebhook(const AUrl: string; const ASecretToken: string; const ACertPath: string);
var
  vTargetUrl: string;
  vMPD: TMultipartFormData;
begin
  vTargetUrl := FBotUrl + '/setWebhook';
  vMPD := TMultipartFormData.Create;
  try
    vMPD.AddField('url', AUrl);
    if ASecretToken <> '' then
      vMPD.AddField('secret_token', ASecretToken);
    if ACertPath <> '' then
      vMPD.AddFile('certificate', ACertPath, 'application/x-pem-file');
    FHTTPClient.Post(vTargetUrl, vMPD);
  finally
    FreeAndNil(vMPD);
  end;
end;

procedure TTelegramBot.DeleteWebhook;
var
  vParams: TStringList;
begin
  vParams := TStringList.Create;
  try
    PostMethod('deleteWebhook', vParams);
  finally
    FreeAndNil(vParams);
  end;
end;

end.
