unit uTelegramBot;

interface

uses
  System.Classes, System.SysUtils, System.Generics.Collections,
  uTelegramTypes, Net.URLClient, Net.HttpClient, JSON, Types;

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
    procedure PostMethodAsync(const AMethodName: String; const AParams: TStringList;
      const AReplyMarkup: TTelegramKeyboardMarkup = nil);

    procedure SetBotToken(const Value: string);
  protected
    FStartTime: Int64; // unix
    function GetMe: string;
    function DoOnMessage(const AMessage: TTelegramMessage): Boolean; virtual;
    function DoOnCallbackQuery(const ACallbackQuery: TTelegramCallbackQuery): Boolean; virtual;
  public
    constructor Create(const AToken: string); virtual;
    destructor Destroy; override;

    procedure Poll;
    procedure StartPolling; virtual; abstract;

    procedure AnswerCallbackQuery(const ACallbackId: String; const AMessage: string = '');
    procedure SetMyCommands(const ACommands: TStringList);

    function GetChat(const AChat: string): TTelegramChat;
    procedure SendPhoto(const AChatId, APhotoId: string; const AText: string = '';
      const AReplyMarkup: TTelegramKeyboardMarkup = nil; const ASpoiler: Boolean = False);
    procedure SendDocument(const AChatId, ADocumentId: string; const AText: string = '';
      const AReplyMarkup: TTelegramKeyboardMarkup = nil);
    procedure SendFile(const AChatId, AFilename: string; const AText: string = '');
    function GetFile(const AFileId: string): string;

    procedure SendMediaGroup(const AChatId: string; const AMedia: TList<string>; const AType: TTelegramMediaType;
      const AText: string = '');

    procedure CopyMessage(const ATargetChat: string; const AMessage: TTelegramMessage); overload;

    function SendMessage(const AChatId, AText: string; const AReplyMarkup: TTelegramKeyboardMarkup = nil;
      const ASync: Boolean = False): string;
    function EditMessageText(const AMessage: TTelegramMessage; const AText: string;
      const AReplyMarkup: TTelegramInlineKeyboardMarkup = nil): string;
    function EditMessageCaption(const AMessage: TTelegramMessage; const ACaption: string;
      const AReplyMarkup: TTelegramInlineKeyboardMarkup = nil): string;
    function ForwardMessage(const AMessage: TTelegramMessage; const ATelegramId: string): string;
    function CopyMessage(const ATargetChat, AFromChat: string; const AMessageId: Integer): string; overload;

    function SendMessageResulted(const AChatId, AText: string; const AReplyMarkup: TTelegramKeyboardMarkup = nil)
      : TTelegramMessage;
    function EditMessageTextResulted(const AMessage: TTelegramMessage; const AText: string;
      const AReplyMarkup: TTelegramInlineKeyboardMarkup = nil): TTelegramMessage;

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

    PostMethodAsync('answerCallbackQuery', vParams, nil);
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
    PostMethodAsync('setMyCommands', vParams, nil);
  finally
    FreeAndNil(vCommandsJSON);
    FreeAndNil(vParams);
  end;
end;

function TTelegramBot.CopyMessage(const ATargetChat, AFromChat: string; const AMessageId: Integer): string;
var
  vParams: TStringList;
begin
  vParams := TStringList.Create;
  try
    vParams.Append('chat_id=' + ATargetChat);
    vParams.Append('from_chat_id=' + AFromChat);
    vParams.Append('message_id=' + IntToStr(AMessageId));

    PostMethodAsync('copyMessage', vParams);
  finally
    FreeAndNil(vParams);
  end;
end;

procedure TTelegramBot.CopyMessage(const ATargetChat: string; const AMessage: TTelegramMessage);
var
  vAnswer, vResult: TJSONObject;
begin
  try
    vAnswer := TJSONObject.LoadFromText(CopyMessage(ATargetChat, AMessage.Chat, AMessage.MessageId));
    vResult := vAnswer.ExtractObject('result');
    AMessage.MessageId := vResult.ExtractInteger('message_id');
    AMessage.Chat := ATargetChat;
  finally
    FreeAndNil(vAnswer);
  end;
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
    PostMethodAsync('deleteMessage', vParams);
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
  const AReplyMarkup: TTelegramInlineKeyboardMarkup = nil): string;
var
  vParams: TStringList;
begin
  if not Assigned(AMessage) then
    Exit;
  vParams := TStringList.Create;
  try
    vParams.Append('chat_id=' + AMessage.Chat);
    vParams.Append('message_id=' + IntToStr(AMessage.MessageId));
    vParams.Append('text=' + AText);
    AMessage.Text := AText;

    Result := PostMethod('editMessageText', vParams, AReplyMarkup);
  finally
    FreeAndNil(vParams);
  end;
end;

function TTelegramBot.EditMessageTextResulted(const AMessage: TTelegramMessage; const AText: string;
  const AReplyMarkup: TTelegramInlineKeyboardMarkup = nil): TTelegramMessage;
var
  vJSON, vResult: TJSONObject;
begin
  Result := nil;
  if not Assigned(AMessage) then
    Exit;
  try
    vJSON := TJSONObject.LoadFromText(EditMessageText(AMessage, AText, AReplyMarkup));
    vResult := vJSON.ExtractObject('result');
    Result := nil;
    if Assigned(vResult) then
      Result := TTelegramMessage.Create(vResult);
  finally
    FreeAndNil(vJSON);
  end;
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
  vTargetUrl: string;
  vMPD: TMultipartFormData;
  vMedia: TJSONObject;
begin
  if not Assigned(AMessage) then
    Exit;
  vTargetUrl := FBotUrl + '/editMessageMedia';
  vMPD := TMultipartFormData.Create;
  try
    vMPD.AddField('chat_id', AMessage.Chat);
    vMPD.AddField('message_id', IntToStr(AMessage.MessageId));
    vMedia := TJSONObject.Create;
    vMedia.StoreString('type', 'photo');
    if ACaption <> '' then
      vMedia.StoreString('caption', ACaption);
    if Assigned(AReplyMarkup) then
      vMPD.AddField('reply_markup', AReplyMarkup.ToString);

    if Pos('.', AMedia) > 0 then
    begin
      vMedia.StoreString('media', 'attach://photo');
      vMPD.AddField('media', vMedia.ToJSON);
      vMPD.AddFile('photo', AMedia);
    end
    else
    begin
      vMedia.StoreString('media', AMedia);
      vMPD.AddField('media', vMedia.ToJSON);
    end;

    FHTTPClient.Post(vTargetUrl, vMPD);
  finally
    FreeAndNil(vMPD);
    vTargetUrl := '';
  end;
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

    PostMethodAsync('editMessageReplyMarkup', vParams, AReplyMarkup);
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
    PostMethodAsync('sendDocument', vParams, AReplyMarkup);
  finally
    FreeAndNil(vParams);
  end;
end;

procedure TTelegramBot.SendFile(const AChatId, AFilename, AText: string);
var
  vTargetUrl: string;
  vMPD: TMultipartFormData;
  LFileStream: TFileStream;
begin
  vTargetUrl := FBotUrl + '/sendDocument';
  vMPD := TMultipartFormData.Create;
  try
    vMPD.AddField('chat_id', AChatId);
    if AText <> '' then
      vMPD.AddField('text', AText);
    LFileStream := TFileStream.Create(AFilename, fmOpenRead or fmShareDenyNone);
    vMPD.AddStream('document', LFileStream, True, ExtractFileName(AFilename));
    FHTTPClient.Post(vTargetUrl, vMPD);
  finally
    FreeAndNil(vMPD);
    vTargetUrl := '';
  end
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

    PostMethodAsync('sendMediaGroup', vParams, nil);
  finally
    FreeAndNil(vMediaGroup);
    FreeAndNil(vParams);
  end;
end;

function TTelegramBot.SendMessage(const AChatId, AText: string; const AReplyMarkup: TTelegramKeyboardMarkup;
  const ASync: Boolean): string;
var
  vParams: TStringList;
begin
  vParams := TStringList.Create;
  Result := '';
  try
    vParams.Append('chat_id=' + AChatId);
    vParams.Append('text=' + AText);
    if ASync then
      Result := PostMethod('sendMessage', vParams, AReplyMarkup)
    else
      Result := PostMethod('sendMessage', vParams, AReplyMarkup);
  finally
    FreeAndNil(vParams);
  end;
end;

function TTelegramBot.SendMessageResulted(const AChatId, AText: string; const AReplyMarkup: TTelegramKeyboardMarkup)
  : TTelegramMessage;
var
  vJSON: TJSONObject;
  vResult: TJSONObject;
begin
  try
    Result := nil;
    vJSON := TJSONObject.LoadFromText(SendMessage(AChatId, AText, AReplyMarkup, True));
    vResult := vJSON.ExtractObject('result');
    if Assigned(vResult) then
      Result := TTelegramMessage.Create(vResult);
  finally
    FreeAndNil(vJSON);
  end;
end;

procedure TTelegramBot.SendPhoto(const AChatId, APhotoId, AText: string; const AReplyMarkup: TTelegramKeyboardMarkup;
  const ASpoiler: Boolean);
var
  vTargetUrl: string;
  vMPD: TMultipartFormData;
begin
  vTargetUrl := FBotUrl + '/sendPhoto';
  vMPD := TMultipartFormData.Create;
  try
    vMPD.AddField('chat_id', AChatId);
    vMPD.AddField('has_spoiler', BoolToStr(ASpoiler, True));

    if AText <> '' then
      vMPD.AddField('caption', AText);

    if Pos('.', APhotoId) > 0 then
      vMPD.AddFile('photo', APhotoId)
    else
      vMPD.AddField('photo', APhotoId);

    if Assigned(AReplyMarkup) then
      vMPD.AddField('reply_markup', AReplyMarkup.ToString);

    FHTTPClient.Post(vTargetUrl, vMPD);
  finally
    FreeAndNil(vMPD);
    vTargetUrl := '';
  end;
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

function TTelegramBot.GetFile(const AFileId: string): string;
var
  vParams: TStringList;
  vResult, vRes: TJSONObject;
begin
  Result := '';
  vParams := TStringList.Create;
  try
    vParams.Append('file_id=' + AFileId);
    vResult := TJSONObject.LoadFromText(PostMethod('getFile', vParams));
    vRes := vResult.ExtractObject('result');
    Result := vRes.ExtractString('file_path');
  finally
    FreeAndNil(vParams);
    FreeAndNil(vResult);
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
  const AReplyMarkup: TTelegramKeyboardMarkup);
// var
// vTargetUrl: string;
// vMPD: TMultipartFormData;
// I: Integer;
begin
  PostMethod(AMethodName, AParams, AReplyMarkup);
  // vTargetUrl := FBotUrl + '/' + AMethodName;
  // vMPD := TMultipartFormData.Create;
  // for I := 0 to AParams.Count - 1 do
  // vMPD.AddField(AParams.Names[I], AParams.Values[AParams.Names[I]]);
  // if Assigned(AReplyMarkup) then
  // vMPD.AddField('reply_markup', AReplyMarkup.ToString);
  // TThreadPool.Current.QueueWorkItem(procedure
  // var
  // vResult: string;
  // begin
  // try
  // vResult := FHTTPClient.Post(TNetEncoding.URL.Encode(vTargetUrl, [], [TURLEncoding.TEncodeOption.SpacesAsPlus]), vMPD).ContentAsString;
  // finally
  // FreeAndNil(vMPD);
  // end
  // end);
end;

function TTelegramBot.GetUpdate: TJSONObject;
var
  vParams: TStringList;
  vAnswer: TJSONObject;
  vUpdate: TJSONObject;
  vArray: TJSONArray;
{$IFDEF DEBUG}
  vRes: string;
{$ENDIF}
begin
  Result := nil;
  vParams := TStringList.Create;
  vParams.Add('offset=' + IntToStr(FLastUpdate));
  vParams.Add('limit=1');
  vParams.Add('timeout=5');
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

end.
