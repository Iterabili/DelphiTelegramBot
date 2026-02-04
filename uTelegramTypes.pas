unit uTelegramTypes;

interface

uses
  Generics.Collections, JSON;

type
  TTelegramUser = class
  private
    FId: string;
    FIsBot: Boolean;
    FFirstName: string;
    FLastName: string;
    FUsername: String;
  public
    property Id: string read FId;
    property IsBot: Boolean read FIsBot;
    property FirstName: string read FFirstName;
    property LastName: string read FLastName;
    property Username: string read FUsername;

    constructor Create(const AUser: TJSONObject);
  end;

  TTelegramKeyboardButton = class abstract
  protected
    FJSON: TJSONObject;
  public
    constructor Create; overload;
    constructor Create(const AText: string); overload;
    destructor Destroy; override;

    function ToString: string; override;

    property JSON: TJSONObject read FJSON;
  end;

  TTelegramInlineKeyboardButton = class(TTelegramKeyboardButton)
  public
    constructor Create(const AText, ACallBackData: string); overload;

    function SetText(const AText: string): TTelegramInlineKeyboardButton;
    function SetCallback(const ACallbackData: string): TTelegramInlineKeyboardButton;
    function SetUrl(const AUrl: string): TTelegramInlineKeyboardButton;
    function Clone: TTelegramInlineKeyboardButton;
  end;

  TTelegramReplyKeyboardButton = class(TTelegramKeyboardButton)
  public
    function SetText(const AText: string): TTelegramReplyKeyboardButton;
    function RequestContact: TTelegramReplyKeyboardButton;
    function Clone: TTelegramReplyKeyboardButton;
  end;

  TTelegramInlineKeyboardButtonsArray = array of TTelegramInlineKeyboardButton;
  TTelegramReplyKeyboardButtonsArray = array of TTelegramReplyKeyboardButton;

  TTelegramKeyboardMarkup = class abstract
  protected
    FKeyboard: TJSONArray;
    FButtons: TObjectList<TTelegramKeyboardButton>;
    function InternalAddRow: TJSONArray;
    procedure InternalAddButton(const AButton: TTelegramKeyboardButton; const ARow: Integer);
  public
    constructor Create;
    destructor Destroy; override;

    function ToString: string; override; abstract;
  end;

  TTelegramReplyKeyboardRemove = class(TTelegramKeyboardMarkup)
  public
    function ToString: string; override;
  end;

  TTelegramInlineKeyboardMarkup = class(TTelegramKeyboardMarkup)
  public
    constructor Create(const ARows
      : Array of TTelegramInlineKeyboardButtonsArray); overload;

    procedure AddRow(const AButtons: TTelegramInlineKeyboardButtonsArray);
    procedure AddButton(const AButton: TTelegramInlineKeyboardButton;
      const ARow: integer = -1); overload;
    function AddButton(const AText, AData: string; const ARow: Integer = -1): TTelegramInlineKeyboardButton; overload;
    function AddUrlButton(const AText, AUrl: string; const ARow: Integer = -1): TTelegramInlineKeyboardButton;

    function ToString: string; override;
  end;

  TTelegramReplyKeyboardMarkup = class(TTelegramKeyboardMarkup)
  private
    FPersistent: Boolean;
  public
    constructor Create(const ARows: Array of TTelegramReplyKeyboardButtonsArray); overload;

    procedure AddRow(const AButtons: TTelegramReplyKeyboardButtonsArray);
    procedure AddButton(const AButton: TTelegramReplyKeyboardButton; const ARow: integer = -1); overload;
    procedure AddButton(const AText: string; const ARow: integer = -1); overload;

    property Persistent: Boolean read FPersistent write FPersistent;

    function ToString: string; override;
  end;

  TTelegramContact = class
  public
    Name: string;
    Phone: string;
    UserId: string;

    constructor Create(const AContact: TJSONObject);
    destructor Destroy; override;
  end;

  TTelegramChat = class
  public
    Id: string;
    ChatType: string;
    Name: string;

    constructor Create(const AChat: TJSONObject);
  end;

  TTelegramMessage = class
  private
    FMessageId: integer;
    FFrom: TTelegramUser;
    FText: String;
    FChat: string;
    FPhotoId: string;
    FDocumentId: string;
    FContact: TTelegramContact;
    FReplyTo: TTelegramMessage;
    FForwardFrom: TTelegramUser;
    FTime: Int64;
  public
    constructor Create(const AMessage: TJSONObject);
    destructor Destroy; override;

    property MessageId: integer read FMessageId write FMessageId;
    property From: TTelegramUser read FFrom;
    property Text: string read FText write FText;
    property Chat: string read FChat write FChat;
    property Contact: TTelegramContact read FContact;
    property Photo: string read FPhotoId;
    property Document: string read FDocumentId;
    property ReplyTo: TTelegramMessage read FReplyTo;
    property ForwardFrom: TTelegramUser read FForwardFrom;
    property Time: Int64 read FTime;
  end;

  TTelegramCallbackQuery = class
  private
    FId: string;
    FFrom: TTelegramUser;
    FAtMessage: TTelegramMessage;
    FData: string;
  public
    constructor Create(const ACallbackQuery: TJSONObject);
    destructor Destroy; override;

    property Id: string read FId;
    property From: TTelegramUser read FFrom;
    property AtMessage: TTelegramMessage read FAtMessage;
    property Data: string read FData;
  end;

  TTelegramMediaType = (tmtPhoto);

  TOnTelegramMessage = reference to function(const AMessage
    : TTelegramMessage): Boolean;
  TOnTelegramCallbackQuery = reference to function(const ACallbackQuery
    : TTelegramCallbackQuery): Boolean;
  TNextStepFunction = reference to function(const AMessage: TTelegramMessage): Boolean;

function ActionId(const AAction: string; const AActions: array of string): Integer;

implementation

uses
  SysUtils, uJSONHelper;

function ActionId(const AAction: string; const AActions: array of string): Integer;
var
  i: integer;
begin
  Result := -1;
  for i := 0 to Length(AActions) - 1 do
    if AActions[i] = AAction then
    begin
      Result := i;
      Break;
    end;
end;

{ TTelegramMessage }

constructor TTelegramMessage.Create(const AMessage: TJSONObject);
var
  vUser, vChat, vContact, vDocument: TJSONObject;
  vPhoto: TJSONArray;
  vReplyTo, vForwardFrom: TJSONObject;
begin
  FMessageId := AMessage.ExtractInteger('message_id');
  FTime := AMessage.ExtractInt64('date');
  FText := AMessage.ExtractString('text');
  FContact := nil;
  FReplyTo := nil;
  FFrom := nil;
  FChat := '';

  vUser := AMessage.ExtractObject('from');
  if Assigned(vUser) then
    FFrom := TTelegramUser.Create(vUser);

  vChat := AMessage.ExtractObject('chat');
  if Assigned(vChat) then
    FChat := vChat.ExtractString('id');

  vContact := AMessage.ExtractObject('contact');
  if Assigned(vContact) then
    FContact := TTelegramContact.Create(vContact);

  vPhoto := AMessage.ExtractArray('photo');
  if Assigned(vPhoto) then
  begin
    FPhotoId := TJSONObject(vPhoto.Items[0]).ExtractString('file_id');
    FText := AMessage.ExtractString('caption');
  end;

  vDocument := AMessage.ExtractObject('document');
  if Assigned(vDocument) then
    FDocumentId := vDocument.ExtractString('file_id');

  vReplyTo := AMessage.ExtractObject('reply_to_message');
  if Assigned(vReplyTo) then
    FReplyTo := TTelegramMessage.Create(vReplyTo);

  vForwardFrom := AMessage.ExtractObject('forward_from');
  if Assigned(vForwardFrom) then
    FForwardFrom := TTelegramUser.Create(vForwardFrom);
end;

destructor TTelegramMessage.Destroy;
begin
  FText := '';
  FChat := '';
  FreeAndNil(FFrom);
  FreeAndNil(FForwardFrom);
  FreeAndNil(FContact);
  FreeAndNil(FReplyTo);
  inherited;
end;

{ TTelegramUser }

constructor TTelegramUser.Create(const AUser: TJSONObject);
begin
  FId := AUser.ExtractString('id');
  FIsBot := AUser.ExtractBoolean('is_bot');
  FFirstName := AUser.ExtractString('first_name');
  FLastName := AUser.ExtractString('last_name');
  FUsername := AUser.ExtractString('username');
end;

{ TTelegramCallbackQuery }

constructor TTelegramCallbackQuery.Create(const ACallbackQuery: TJSONObject);
begin
  FId := ACallbackQuery.ExtractString('id');
  FFrom := TTelegramUser.Create(ACallbackQuery.ExtractObject('from'));
  FAtMessage := TTelegramMessage.Create(ACallbackQuery.ExtractObject('message'));
  FData := ACallbackQuery.ExtractString('data');
end;

destructor TTelegramCallbackQuery.Destroy;
begin
  FId := '';
  FreeAndNil(FFrom);
  FreeAndNil(FAtMessage);
  FData := '';
end;

{ TTelegramInlineKeyboardButton }

function TTelegramInlineKeyboardButton.Clone: TTelegramInlineKeyboardButton;
begin
  Result := TTelegramInlineKeyboardButton.Create;
  FreeAndNil(Result.FJSON);
  Result.FJSON := TJSONObject(FJSON.Clone);
end;

constructor TTelegramInlineKeyboardButton.Create(const AText,
  ACallBackData: string);
begin
  inherited Create;
  FJSON.StoreString('text', AText);
  FJSON.StoreString('callback_data', ACallbackData);
end;

function TTelegramInlineKeyboardButton.SetCallback(
  const ACallbackData: string): TTelegramInlineKeyboardButton;
begin
  FJSON.StoreString('callback_data', ACallbackData);
  Result := Self;
end;

function TTelegramInlineKeyboardButton.SetUrl(const AUrl: string): TTelegramInlineKeyboardButton;
begin
  if AUrl <> '' then
    FJSON.StoreString('url', AUrl);
  Result := Self;
end;

function TTelegramInlineKeyboardButton.SetText(const AText: string): TTelegramInlineKeyboardButton;
begin
  FJSON.StoreString('text', AText);
  Result := Self;
end;

{ TTelegramReplyKeyboardButton }

function TTelegramReplyKeyboardButton.Clone: TTelegramReplyKeyboardButton;
begin
  Result := TTelegramReplyKeyboardButton.Create;
  FreeAndNil(Result.FJSON);
  Result.FJSON := TJSONObject(FJSON.Clone);
end;

function TTelegramReplyKeyboardButton.RequestContact: TTelegramReplyKeyboardButton;
begin
  FJSON.StoreBoolean('request_contact', True);
  Result := Self;
end;

function TTelegramReplyKeyboardButton.SetText(const AText: string): TTelegramReplyKeyboardButton;
begin
  FJSON.StoreString('text', AText);
  Result := Self;
end;

{ TTelegramKeyboardMarkup }

constructor TTelegramKeyboardMarkup.Create;
begin
  FKeyboard := TJSONArray.Create;
  FButtons := TObjectList<TTelegramKeyboardButton>.Create(True);
end;

destructor TTelegramKeyboardMarkup.Destroy;
begin
  FreeAndNil(FKeyboard);
  FreeAndNil(FButtons);
  inherited;
end;

procedure TTelegramKeyboardMarkup.InternalAddButton(const AButton: TTelegramKeyboardButton;
  const ARow: Integer);
var
  vRow: TJSONArray;
  vJSONButton: TJSONObject;
begin
  if (ARow < 0) or (ARow >= FKeyboard.Count) then
    vRow := InternalAddRow
  else
    vRow := TJSONArray(FKeyboard.Items[ARow]);
  vJSONButton := TJSONObject(AButton.JSON.Clone);
  vRow.Add(vJSONButton);
  FButtons.Add(AButton);
end;

function TTelegramKeyboardMarkup.InternalAddRow: TJSONArray;
begin
  Result := TJSONArray.Create;
  FKeyboard.Add(Result);
end;

{ TTelegramInlineKeyboardMarkup }

procedure TTelegramInlineKeyboardMarkup.AddButton(const AButton
  : TTelegramInlineKeyboardButton; const ARow: integer);
begin
  InternalAddButton(AButton, ARow);
end;

function TTelegramInlineKeyboardMarkup.AddButton(const AText, AData: string;
  const ARow: Integer = -1): TTelegramInlineKeyboardButton;
begin
  Result := TTelegramInlineKeyboardButton.Create(AText, AData);
  InternalAddButton(Result, ARow);
end;

procedure TTelegramInlineKeyboardMarkup.AddRow(const AButtons
  : TTelegramInlineKeyboardButtonsArray);
var
  vButton: TTelegramInlineKeyboardButton;
  vJSONButton: TJSONObject;
  vRow: TJSONArray;
begin
  vRow := InternalAddRow;
  for vButton in AButtons do
  begin
    vJSONButton := TJSONObject(vButton.JSON.Clone);
    vRow.Add(vJSONButton);
    FButtons.Add(vButton);
  end;
end;

function TTelegramInlineKeyboardMarkup.AddUrlButton(const AText, AUrl: string;
  const ARow: Integer): TTelegramInlineKeyboardButton;
begin
  Result := TTelegramInlineKeyboardButton.Create(AText, '-1');
  Result.SetUrl(AUrl);
  InternalAddButton(Result, ARow);
end;

constructor TTelegramInlineKeyboardMarkup.Create(const ARows
  : array of TTelegramInlineKeyboardButtonsArray);
var
  vRow: TTelegramInlineKeyboardButtonsArray;
begin
  inherited Create;
  for vRow in ARows do
    AddRow(vRow);
end;

function TTelegramInlineKeyboardMarkup.ToString: string;
var
  jObj: TJSONObject;
  vKeyboard: TJSONArray;
begin
  jObj := TJSONObject.Create;
  try
    vKeyboard := TJSONArray(FKeyboard.Clone);
    jObj.AddPair('inline_keyboard', TJSONArray(vKeyboard));
    Result := jObj.ToString;
  finally
    FreeAndNil(jObj);
  end;
end;

{ TTelegramReplyKeyboardMarkup }

procedure TTelegramReplyKeyboardMarkup.AddButton(const AButton: TTelegramReplyKeyboardButton; const ARow: integer);
begin
  InternalAddButton(AButton, ARow);
end;

procedure TTelegramReplyKeyboardMarkup.AddButton(const AText: string;
  const ARow: integer);
var
  vButton: TTelegramReplyKeyboardButton;
begin
  vButton := TTelegramReplyKeyboardButton.Create(AText);
  InternalAddButton(vButton, ARow);
end;

procedure TTelegramReplyKeyboardMarkup.AddRow(const AButtons: TTelegramReplyKeyboardButtonsArray);
var
  vButton: TTelegramReplyKeyboardButton;
  vJSONButton: TJSONObject;
  vRow: TJSONArray;
begin
  vRow := InternalAddRow;
  for vButton in AButtons do
  begin
    vJSONButton := TJSONObject(vButton.JSON.Clone);
    FButtons.Add(vButton);
    vRow.Add(vJSONButton);
  end;
end;

constructor TTelegramReplyKeyboardMarkup.Create(
  const ARows: array of TTelegramReplyKeyboardButtonsArray);
var
  vRow: TTelegramReplyKeyboardButtonsArray;
begin
  inherited Create;
  FPersistent := True;
  for vRow in ARows do
    AddRow(vRow);
end;

function TTelegramReplyKeyboardMarkup.ToString: string;
var
  jObj: TJSONObject;
  vKeyboard: TJSONArray;
begin
  jObj := TJSONObject.Create;
  try
    vKeyboard := TJSONArray(FKeyboard.Clone);
    jObj.AddPair('keyboard', TJSONArray(vKeyboard));
    jObj.StoreBoolean('is_persistent', FPersistent);
    jObj.StoreBoolean('resize_keyboard', True);
    Result := jObj.ToJSON;
  finally
    FreeAndNil(jObj);
  end;
end;

{ TTelegramContact }

constructor TTelegramContact.Create(const AContact: TJSONObject);
begin
  Phone := AContact.ExtractString('phone_number');
  UserId := AContact.ExtractString('user_id');
  Name := AContact.ExtractString('first_name');
end;

destructor TTelegramContact.Destroy;
begin
  Phone := '';
  inherited;
end;

{ TTelegramKeyboardButton }

constructor TTelegramKeyboardButton.Create(const AText: string);
begin
  Create;
  FJSON.StoreString('text', AText);
end;

constructor TTelegramKeyboardButton.Create;
begin
  FJSON := TJSONObject.Create;
end;

destructor TTelegramKeyboardButton.Destroy;
begin
  FreeAndNil(FJSON);
  inherited;
end;

function TTelegramKeyboardButton.ToString: string;
begin
  Result := FJSON.ToJSON;
end;

{ TTelegramReplyKeyboardRemove }

function TTelegramReplyKeyboardRemove.ToString: string;
begin
  Result := '{"remove_keyboard": true}';
end;

{ TTelegramChat }

constructor TTelegramChat.Create(const AChat: TJSONObject);
begin
  Id := AChat.ExtractString('id');
  ChatType := AChat.ExtractString('type');
  Name := AChat.ExtractString('first_name') + ' ' + AChat.ExtractString('last_name');
end;

end.
