unit uTelegramBotEx;

interface

uses
  uTelegramTypes, uTelegramBot, Generics.Collections, Classes;

type
  TCallbackData = class;  // Forward declaration

  TConstructSimpleMenuProcedure = reference to procedure (const ATelegramid: string; const AData: TCallbackData;
    out ACaption: string; out AKeyboard: TTelegramInlineKeyboardMarkup);

  TIntegerProc = reference to function (const AValue: Integer): Boolean;
  TTimeProc = reference to function (const AValue: TDateTime): Boolean;
  TTimeRangeProc = reference to function (const AFromValue, AToValue: TDateTime): Boolean;
  TStringProc = reference to function (const AValue: string): Boolean;
  TContactProc = reference to function (const AValue, AOwner: string): Boolean;
  TMessageProc = reference to function (const AValue: TTelegramMessage): Boolean;
  TTextPhotoProc = reference to function (const AText, APhoto: string): Boolean;
  TPhotoDocProc = reference to function (const APhoto, ADocument: string): Boolean;

  TButtonsRow = array of string;
  TButtons = array of TButtonsRow;

  TTgModalResult = (tmrYes, tmrNo);

  TSimpleButton = class
  public
    Id: Integer;
    Name: string;
    Caption: string;
    URL: string;

    constructor Create(const AId: Integer; const AName, ACaption: string; const AURL: string);
  end;

  TBotCommand = class
  public
    Command: string;
    Description: string;

    constructor Create(const ACommand, ADescription: string);
  end;

  TCallbackData = class
  private
    FParams: TStringList;
    function GetParam(AIndex: Integer): string;
    function GetParamAsInt(AIndex: Integer): Integer;
    function GetCount: Integer;
  public
    constructor Create(const AData: string); overload;
    constructor Create; overload;
    destructor Destroy; override;

    function Add(const AValue: string): TCallbackData; overload;
    function Add(const AValue: Integer): TCallbackData; overload;
    function AddIf(const ACondition: Boolean; const AValue: string): TCallbackData; overload;
    function AddIf(const ACondition: Boolean; const AValue: Integer): TCallbackData; overload;
    function Init(const AData: string): TCallbackData; overload;
    function Init(const AData: Integer): TCallbackData; overload;

    procedure Clear;
    function ToString: string; override;
    function Has(AIndex: Integer): Boolean;
    function GetString(AIndex: Integer; const ADefault: string = ''): string;
    function GetInteger(AIndex: Integer; const ADefault: Integer = 0): Integer;
    function GetBoolean(AIndex: Integer; const ADefault: Boolean = False): Boolean;

    property Count: Integer read GetCount;
    property Params[AIndex: Integer]: string read GetParam; default;
    property AsInt[AIndex: Integer]: Integer read GetParamAsInt;
  end;

  TSimpleMenu = class
    Id: Integer;
    Caption: string;
    BackButton: string;
    Buttons: TObjectList<TList<TSimpleButton>>;
    ConstructProcedure: TConstructSimpleMenuProcedure;

    constructor Create(const AId: Integer; const ACaption, ABackButton: string); overload;
    constructor Create(const AId: Integer; const AConstructProcedure: TConstructSimpleMenuProcedure); overload;
    destructor Destroy; override;

    procedure AddButton(const AButton: TSimpleButton; const ARow: Integer);
  end;

  TTelegramBotEx = class(TTelegramBot)
  private
    FSimpleMenus: TObjectDictionary<string, TSimpleMenu>;
    FNextSteps: TDictionary<string, TNextStepFunction>;
    FOnMessageProcedures: TList<TOnTelegramMessage>;
    FOnCallbackQueryProcedures: TList<TOnTelegramCallbackQuery>;
    function InternalExecuteCalbackAction(const ACallback: TTelegramCallbackQuery): Boolean;
  protected
    FSimpleButtons: TObjectList<TSimpleButton>;
    FButtonsMap: TDictionary<string, TSimpleButton>;
    FActions: TList<string>;
    FActionsMap: TDictionary<string, Integer>;
    FCommands: TObjectList<TBotCommand>;

    function CheckButtonAdd(const AButton, ATelegramId, AData: string): Boolean; virtual; abstract;
    function DoOnMessage(const AMessage: TTelegramMessage): Boolean; override;
    function DoOnCallbackQuery(const ACallbackQuery: TTelegramCallbackQuery): Boolean; override;

    procedure RegisterNextStep(const AChatId: string; const AProcedure: TNextStepFunction; const AObject: TObject = nil);
    procedure RegisterAction(const AName: string);
    procedure RegisterButton(const AName: string; const ACaption: string; const AURL: string = '');
    procedure RegisterCommand(const ACommand, ADescription: string);

    procedure RegisterMenu(const AMenuName, ACaption: string; const AButtons: TButtons; const ABackButton: string = ''); overload;
    procedure RegisterMenu(const AMenuName: string; const AConstructProcedure: TConstructSimpleMenuProcedure); overload;

    procedure SendCommandsToTelegram;

   // Value getters
    procedure GetInteger    (const AMessage: TTelegramMessage; const AFrom, ACaption: string; const AProc: TIntegerProc;
                             const ACancelBtn: string; const AData: string);
    procedure GetTime       (const AMessage: TTelegramMessage; const AFrom, ACaption: string; const AProc: TTimeProc;
                             const ACancelBtn: string; const AData: string);
    procedure GetTimeRange  (const AMessage: TTelegramMessage; const AFrom, ACaption: string; const AProc: TTimeRangeProc;
                             const ACancelBtn: string; const AData: string);
    procedure GetString     (const AMessage: TTelegramMessage; const AFrom, ACaption: string; const AProc: TStringProc;
                             const ACancelBtn: string; const AData: string; const ADeleteMessage: Boolean = False);
    procedure GetUsername   (const AMessage: TTelegramMessage; const AFrom: string; const AProc: TStringProc;
                             const ACancelBtn: string; const AData: string);
    procedure GetContact    (const AMessage: TTelegramMessage; const AFrom, ACaption: string; const AProc: TContactProc;
                             const ACancelBtn: string; const AData: string; const AAllowText: Boolean = False; const AFromSender: Boolean = True);
    procedure GetMessage    (const AMessage: TTelegramMessage; const AFrom, ACaption: string; const AProc: TMessageProc;
                             const ACancelBtn: string; const AData: string);
    procedure GetPhoto      (const AMessage: TTelegramMessage; const AFrom, ACaption: string; const AProc: TStringProc;
                             const ACancelBtn: string; const AData: string);
    procedure GetDocument   (const AMessage: TTelegramMessage; const AFrom, ACaption: string; const AProc: TStringProc;
                             const ACancelBtn: string; const AData: string);
    procedure GetTextOrPhoto(const AMessage: TTelegramMessage; const AFrom, ACaption: string; const AProc: TTextPhotoProc;
                             const ACancelBtn: string; const AData: string);
    procedure GetPhotoOrDocument(const AMessage: TTelegramMessage; const AFrom, ACaption: string; const AProc: TPhotoDocProc;
                             const ACancelBtn: string; const AData: string);
    procedure GetPositiveInteger(const AMessage: TTelegramMessage; const AFrom, ACaption: string; const AProc: TIntegerProc;
                             const ACancelBtn: string; const AData: string);

    procedure SendCalendar(const AMessage: TTelegramMessage; const ACurrentDate, AMinDate: TDateTime; const ATelegramId, ASelectDateAction, AData, AAcceptBtn: string;
      const ACancelBtn: string = ''; const  APhoto: string = '');


    procedure AppendKeyboard(const AKeyboard: TTelegramInlineKeyboardMarkup; const AButton: string; const AData: TCallbackData = nil; const ACaption: string = ''; const ARow: Integer = -1); overload;
    procedure AppendKeyboard(const AKeyboard: TTelegramInlineKeyboardMarkup; const AButton: string; const AData: string; const ACaption: string = ''; const ARow: Integer = -1); overload;
    function AppendMenuKeyboard(const AKeyboard: TTelegramInlineKeyboardMarkup; const AButton, ATelegramId: string; const AData: TCallbackData; const ACaption: string = ''; const ARow: Integer = -1): Boolean; overload;
    function AppendMenuKeyboard(const AKeyboard: TTelegramInlineKeyboardMarkup; const AButton, ATelegramId, AData: string; const ACaption: string = ''; const ARow: Integer = -1): Boolean; overload;
    //todo: add captions
    procedure SendConfirmation(const AMessage: TTelegramMessage; const ATelegramId, AText, AAction, AData: string; const APhoto: string = ''; const ADocument: string = '');

    procedure DoInitialize; virtual;

    procedure ExecuteAction(const AName: string; const AParams: TCallbackData; const ACallBack: TTelegramCallbackQuery); virtual; abstract;

    function ProceedNextStep(const AMsg: TTelegramMessage): Boolean;
  public
    constructor Create(const AToken: string); override;
    destructor Destroy; override;

    procedure Initialize;

    procedure RegisterDoOnMessage(const AFunction: TOnTelegramMessage);
    procedure RegisterDoOnCallbackQuery(const AFunction: TOnTelegramCallbackQuery);

    procedure DeleteNextStep(const ATelegramId: string);
    procedure ClearNextSteps;

    procedure SendMenu(const AMessage: TTelegramMessage; const AMenuName: string; const ARecipient: string = '';
      const AExtraData: TCallbackData = nil; const ACaption: string = ''; const APhoto: string = ''); overload;
    procedure SendMenu(const AMessage: TTelegramMessage; const AMenuName: string; const ARecipient: string;
      const AExtraData: string; const ACaption: string = ''; const APhoto: string = ''); overload;
  end;

function CreateDelimitedList(const ADelimitedText: string; const ADelimiter: Char = ';'): TStrings;
function NormalizeTimeString(const AText: string): string;

implementation

uses
  SysUtils, Math, DateUtils, StrUtils;

function CreateDelimitedList(const ADelimitedText: string; const ADelimiter: Char = ';'): TStrings;
begin
  Result := TStringList.Create;
  Result.StrictDelimiter := True; // need before DelimitedText := ADelimitedText
  Result.Delimiter := ADelimiter;
  Result.DelimitedText := ADelimitedText;
  Result.QuoteChar := #0;
end;

function NormalizeTimeString(const AText: string): string;
var
  vHours, vMinutes: Integer;
  vTimeStr: string;
begin
  vTimeStr := ReplaceStr(AText, ':', ''); // Убираем символ ':', если он есть
  case Length(vTimeStr) of
    0 .. 2:
      begin
        vHours := StrToIntDef(vTimeStr, 0);
        vMinutes := 0;
      end;
    3:
      begin
        vHours := StrToIntDef(Copy(vTimeStr, 1, 1), 0);
        vMinutes := StrToIntDef(Copy(vTimeStr, 2, 2), 0);
      end;
    4:
      begin
        vHours := StrToIntDef(Copy(vTimeStr, 1, 2), 0);
        vMinutes := StrToIntDef(Copy(vTimeStr, 3, 2), 0);
      end;
  else
    begin
      vHours := 0;
      vMinutes := 0;
    end;
  end;
  if vHours > 24 then
    vHours := 0;
  if vMinutes > 59 then
    vMinutes := 0;
  Result := Format('%d:%.2d', [vHours, vMinutes]);
end;

procedure TTelegramBotEx.GetInteger(const AMessage: TTelegramMessage; const AFrom, ACaption: string; const AProc: TIntegerProc; const ACancelBtn: string; const AData: string);
begin
  GetMessage(AMessage, AFrom, ACaption,
    function(const AMessage: TTelegramMessage): Boolean
    var
      vInt: Integer;
    begin
      Result := False;
      if (AMessage.Text = '') or not (TryStrToInt(AMessage.Text, vInt)) then
      begin
        GetInteger(nil, AFrom, ACaption, AProc, ACancelBtn, AData);
        Exit;
      end;
      Result := AProc(vInt);
    end, ACancelBtn, AData);
end;

procedure TTelegramBotEx.GetTime(const AMessage: TTelegramMessage; const AFrom, ACaption: string; const AProc: TTimeProc; const ACancelBtn: string; const AData: string);
begin
  GetMessage(AMessage, AFrom, ACaption,
    function(const AMessage: TTelegramMessage): Boolean
    var
      vTime: TDateTime;
    begin
      Result := False;
      if (AMessage.Text = '') or not (TryStrToTime(AMessage.Text, vTime)) then
      begin
        GetTime(nil, AFrom, ACaption, AProc, ACancelBtn, AData);
        Exit;
      end;
      Result := AProc(vTime);
    end, ACancelBtn, AData);
end;

procedure TTelegramBotEx.GetTimeRange(const AMessage: TTelegramMessage; const AFrom, ACaption: string; const AProc: TTimeRangeProc; const ACancelBtn: string; const AData: string);
begin
  GetMessage(AMessage, AFrom, ACaption,
    function(const AMessage: TTelegramMessage): Boolean
    var
      vTimeRange: TStrings;
      vFromTime, vToTime: TDateTime;
    begin
      Result := False;
      if (AMessage.Text = '') then
      begin
        GetTimeRange(nil, AFrom, ACaption, AProc, ACancelBtn, AData);
        Exit;
      end;
      vTimeRange := CreateDelimitedList(AMessage.Text, '-');
      if vTimeRange.Count <> 2 then
      begin
        GetTimeRange(nil, AFrom, ACaption, AProc, ACancelBtn, AData);
        Exit;
      end;

      if (TryStrToTime(NormalizeTimeString(vTimeRange[0]), vFromTime)) and (TryStrToTime(NormalizeTimeString(vTimeRange[1]), vToTime)) then
        Result := AProc(vFromTime, vToTime)
      else
        GetTimeRange(nil, AFrom, ACaption, AProc, ACancelBtn, AData);
    end, ACancelBtn, AData);
end;

procedure TTelegramBotEx.GetString(const AMessage: TTelegramMessage; const AFrom, ACaption: string; const AProc: TStringProc; const ACancelBtn: string;
                                   const AData: string; const ADeleteMessage: Boolean = False);
begin
  GetMessage(AMessage, AFrom, ACaption,
    function(const AMessage: TTelegramMessage): Boolean
    begin
      Result := False;
      if (AMessage.Text = '') then
        GetString(nil, AFrom, ACaption, AProc, ACancelBtn, AData)
      else
        Result := AProc(AMessage.Text);
      if ADeleteMessage then
        DeleteMessage(AMessage);
    end, ACancelBtn, AData);
end;

procedure TTelegramBotEx.GetUsername(const AMessage: TTelegramMessage; const AFrom: string; const AProc: TStringProc; const ACancelBtn: string; const AData: string);
begin
  GetString(AMessage, AFrom, 'Введите @username', function (const AValue: string): Boolean
  begin
    Result := False;
    if AValue[1] = '@' then
      Result := AProc(Copy(AValue, 2, Length(AValue) - 1))
    else
      GetUsername(nil, AFrom, AProc, ACancelBtn, AData);
  end, ACancelBtn, AData);
end;

procedure TTelegramBotEx.GetContact(const AMessage: TTelegramMessage; const AFrom, ACaption: string; const AProc: TContactProc; const ACancelBtn: string; const AData: string;
  const AAllowText: Boolean = False; const AFromSender: Boolean = True);
var
  vKeyboardReq: TTelegramReplyKeyboardMarkup;
  vKeyboard: TTelegramInlineKeyboardMarkup;
  vMessage: TTelegramMessage;
begin
  if AFromSender then
    vKeyboardReq := TTelegramReplyKeyboardMarkup.Create(
      [[TTelegramReplyKeyboardButton.Create('Отправить контакт').RequestContact]]);

  vKeyboard := TTelegramInlineKeyboardMarkup.Create;
  AppendKeyboard(vKeyboard, ACancelBtn, AData, 'Отмена');

  if Assigned(AMessage) then
    DeleteMessage(AMessage);

  if AFromSender then
  begin
    vMessage := SendMessageResulted(AFrom, ACaption, vKeyboardReq);
    EditMessageReplyMarkup(vMessage, vKeyboard);
    FreeAndNil(vKeyboardReq);
  end
  else
    vMessage := SendMessageResulted(AFrom, ACaption, vKeyboard);

  FreeAndNil(vKeyboard);

  RegisterNextStep(AFrom, function(const AMessage: TTelegramMessage): Boolean
  var
    vPhone: string;
    vPhoneNumber: Int64;
    vEmptyKeyboard: TTelegramReplyKeyboardRemove;
  begin
    Result := False;
    DeleteKeyboard(vMessage);
    FreeAndNil(vMessage);
    if AFromSender then
    begin
      vEmptyKeyboard := TTelegramReplyKeyboardRemove.Create;
      vMessage := SendMessageResulted(AMessage.From.Id, 'clear', vEmptyKeyboard);
      DeleteMessage(vMessage);
      FreeAndNil(vMessage);
      FreeAndNil(vEmptyKeyboard);
    end;

    if Assigned(AMessage.Contact) then
    begin
      vPhone := AMessage.Contact.Phone;
      if (vPhone[1] = '+') then
        vPhone := Copy(vPhone, 2, Length(vPhone) - 1);
      Result := AProc(vPhone, AMessage.Contact.UserId)
    end
    else if AAllowText and (Length(AMessage.Text) > 10) then
    begin
      vPhone := AMessage.Text;
      if (vPhone[1] = '+') then
        vPhone := Copy(vPhone, 2, Length(vPhone) - 1);

      if TryStrToInt64(vPhone, vPhoneNumber) then
        Result := AProc(vPhone, '')
      else
        GetContact(nil, AFrom, ACaption, AProc, ACancelBtn, AData, AAllowText, AFromSender);
    end
    else
      GetContact(nil, AFrom, ACaption, AProc, ACancelBtn, AData, AAllowText, AFromSender);
  end);
end;

procedure TTelegramBotEx.GetMessage(const AMessage: TTelegramMessage; const AFrom, ACaption: string; const AProc: TMessageProc; const ACancelBtn: string; const AData: string);
var
  vKeyboard: TTelegramInlineKeyboardMarkup;
  vMessage: TTelegramMessage;
begin
  vKeyboard := TTelegramInlineKeyboardMarkup.Create;
  AppendKeyboard(vKeyboard, ACancelBtn, AData, 'Отмена');

  if Assigned(AMessage) then
    vMessage := EditMessageTextResulted(AMessage, ACaption, vKeyboard)
  else
    vMessage := SendMessageResulted(AFrom, ACaption, vKeyboard);
  FreeAndNil(vKeyboard);
  RegisterNextStep(AFrom, function(const AMessage: TTelegramMessage): Boolean
  begin
    DeleteKeyboard(vMessage);
    FreeAndNil(vMessage);
    Result := AProc(AMessage);
  end);
end;

procedure TTelegramBotEx.GetPhoto(const AMessage: TTelegramMessage; const AFrom, ACaption: string;
  const AProc: TStringProc; const ACancelBtn, AData: string);
begin
  GetMessage(AMessage, AFrom, ACaption,
    function(const AMessage: TTelegramMessage): Boolean
    begin
      Result := False;
      if (AMessage.Photo = '') then
        GetPhoto(nil, AFrom, ACaption, AProc, ACancelBtn, AData)
      else
        Result := AProc(AMessage.Photo);
    end, ACancelBtn, AData);
end;

procedure TTelegramBotEx.GetDocument(const AMessage: TTelegramMessage; const AFrom, ACaption: string;
  const AProc: TStringProc; const ACancelBtn, AData: string);
begin
  GetMessage(AMessage, AFrom, ACaption,
    function(const AMessage: TTelegramMessage): Boolean
    begin
      Result := False;
      if (AMessage.Document = '') then
        GetDocument(nil, AFrom, ACaption, AProc, ACancelBtn, AData)
      else
        Result := AProc(AMessage.Document);
    end, ACancelBtn, AData);
end;

procedure TTelegramBotEx.GetTextOrPhoto(const AMessage: TTelegramMessage; const AFrom, ACaption: string;
  const AProc: TTextPhotoProc; const ACancelBtn, AData: string);
begin
  GetMessage(AMessage, AFrom, ACaption,
    function(const AMessage: TTelegramMessage): Boolean
    begin
      Result := False;
      if (AMessage.Text = '') and (AMessage.Photo = '') then
        GetTextOrPhoto(nil, AFrom, ACaption, AProc, ACancelBtn, AData)
      else
        Result := AProc(AMessage.Text, AMessage.Photo);
    end, ACancelBtn, AData);
end;

procedure TTelegramBotEx.GetPhotoOrDocument(const AMessage: TTelegramMessage; const AFrom, ACaption: string;
  const AProc: TPhotoDocProc; const ACancelBtn, AData: string);
begin
  GetMessage(AMessage, AFrom, ACaption,
    function(const AMessage: TTelegramMessage): Boolean
    begin
      Result := False;
      if (AMessage.Photo = '') and (AMessage.Document = '') then
        GetPhotoOrDocument(nil, AFrom, ACaption, AProc, ACancelBtn, AData)
      else
        Result := AProc(AMessage.Photo, AMessage.Document);
    end, ACancelBtn, AData);
end;

procedure TTelegramBotEx.GetPositiveInteger(const AMessage: TTelegramMessage; const AFrom, ACaption: string;
  const AProc: TIntegerProc; const ACancelBtn, AData: string);
begin
  GetMessage(AMessage, AFrom, ACaption,
    function(const AMessage: TTelegramMessage): Boolean
    var
      vInt: Integer;
    begin
      Result := False;
      if (AMessage.Text = '') or not (TryStrToInt(AMessage.Text, vInt)) or (vInt <= 0) then
      begin
        GetPositiveInteger(nil, AFrom, ACaption, AProc, ACancelBtn, AData);
        Exit;
      end;
      Result := AProc(vInt);
    end, ACancelBtn, AData);
end;

procedure TTelegramBotEx.Initialize;
begin
  RegisterDoOnMessage(ProceedNextStep);
  DoInitialize;

  RegisterDoOnCallbackQuery(InternalExecuteCalbackAction);

  RegisterButton('confirm', 'Подтвердить');
  RegisterButton('reject', 'Отклонить');
  RegisterButton('calendar_date', 'Выбор дня в календаре');
end;

function TTelegramBotEx.InternalExecuteCalbackAction(const ACallback: TTelegramCallbackQuery): Boolean;
var
  vBId, vAId, I: Integer;
  vButton, vAction: string;
  vInitialCount: Integer;
  vPhoto, vData, vCancelBtn: string;
  vCallbackData: TCallbackData;
begin
  Result := True;

  vCallbackData := TCallbackData.Create(ACallback.Data);
  try
    if vCallbackData.Count < 1 then
      Exit(False);

    vBId := vCallbackData.GetInteger(0);
    vButton := FSimpleButtons[vBId].Name;

    if (vButton = 'confirm') or (vButton = 'reject') then
    begin
      vAId := vCallbackData.GetInteger(1);
      vAction := FActions[vAId];
      ExecuteAction(vAction, vCallbackData, ACallback);
    end
    else if vButton = 'calendar_date' then
    begin
      vAId := vCallbackData.GetInteger(1);
      vAction := FActions[vAId];
      vInitialCount := vCallbackData.Count;
      ExecuteAction(vAction, vCallbackData, ACallback);

      vPhoto := '';
      if vCallbackData.Count > vInitialCount then
        vPhoto := vCallbackData.GetString(vInitialCount);

      vCancelBtn := '';
      if vCallbackData.GetInteger(5) <> -1 then
        vCancelBtn := FSimpleButtons[vCallbackData.GetInteger(5)].Name;

      vData := '';
      for I := 6 to vInitialCount - 1 do
      begin
        if vData <> '' then
          vData := vData + ' ';
        vData := vData + vCallbackData.GetString(I);
      end;

      SendCalendar(ACallback.AtMessage, StrToDate(vCallbackData.GetString(2)), StrToDate(vCallbackData.GetString(3)),
        ACallback.From.Id, FActions[vCallbackData.GetInteger(1)], vData,
        FSimpleButtons[vCallbackData.GetInteger(4)].Name, vCancelBtn, vPhoto);
    end
    else
      Result := False;
  finally
    FreeAndNil(vCallbackData);
  end;
end;

function TTelegramBotEx.ProceedNextStep(const AMsg: TTelegramMessage): Boolean;
begin
  Result := FNextSteps.ContainsKey(AMsg.From.Id);
  if Result and FNextSteps[AMsg.From.Id](AMsg) then
      FNextSteps.Remove(AMsg.From.Id);
end;

procedure TTelegramBotEx.AppendKeyboard(const AKeyboard: TTelegramInlineKeyboardMarkup; const AButton: string; const AData: TCallbackData = nil; const ACaption: string = ''; const ARow: Integer = -1);
var
  vButton: TSimpleButton;
  vCaption: string;
  vCallbackData: TCallbackData;
  vOwnsData: Boolean;
begin
  if not FButtonsMap.TryGetValue(AButton, vButton) then
    Exit;

  vCaption := ACaption;
  if vCaption = '' then
    vCaption := vButton.Caption;

  if vButton.URL <> '' then
  begin
    AKeyboard.AddUrlButton(vCaption, vButton.URL, ARow);
    Exit;
  end;

  vOwnsData := not Assigned(AData);
  if vOwnsData then
    vCallbackData := TCallbackData.Create
  else
    vCallbackData := AData;

  try
    if vCallbackData.Count > 0 then
      AKeyboard.AddButton(vCaption, IntToStr(vButton.Id) + ' ' + vCallbackData.ToString, ARow)
    else
      AKeyboard.AddButton(vCaption, IntToStr(vButton.Id), ARow);
  finally
    if vOwnsData then
      FreeAndNil(vCallbackData);
  end;
end;

procedure TTelegramBotEx.AppendKeyboard(const AKeyboard: TTelegramInlineKeyboardMarkup; const AButton: string; const AData: string; const ACaption: string = ''; const ARow: Integer = -1);
var
  vCallbackData: TCallbackData;
begin
  vCallbackData := TCallbackData.Create(AData);
  try
    AppendKeyboard(AKeyboard, AButton, vCallbackData, ACaption, ARow);
  finally
    FreeAndNil(vCallbackData);
  end;
end;

function TTelegramBotEx.AppendMenuKeyboard(const AKeyboard: TTelegramInlineKeyboardMarkup; const AButton, ATelegramId: string; const AData: TCallbackData; const ACaption: string; const ARow: Integer): Boolean;
begin
  Result := CheckButtonAdd(AButton, ATelegramId, AData.ToString);
  if Result then
    AppendKeyboard(AKeyboard, AButton, AData, ACaption, ARow);
end;

function TTelegramBotEx.AppendMenuKeyboard(const AKeyboard: TTelegramInlineKeyboardMarkup; const AButton, ATelegramId, AData, ACaption: string; const ARow: Integer): Boolean;
var
  vCallbackData: TCallbackData;
begin
  Result := CheckButtonAdd(AButton, ATelegramId, AData);
  if Result then
  begin
    if AData <> '' then
    begin
      vCallbackData := TCallbackData.Create;
      try
        vCallbackData.Add(AData);
        AppendKeyboard(AKeyboard, AButton, vCallbackData, ACaption, ARow);
      finally
        FreeAndNil(vCallbackData);
      end;
    end
    else
      AppendKeyboard(AKeyboard, AButton, nil, ACaption, ARow);
  end;
end;

procedure TTelegramBotEx.ClearNextSteps;
begin
  FNextSteps.Clear;
end;

constructor TTelegramBotEx.Create(const AToken: string);
begin
  inherited;
  FSimpleButtons := TObjectList<TSimpleButton>.Create;
  FButtonsMap := TDictionary<string, TSimpleButton>.Create;
  FSimpleMenus := TObjectDictionary<string, TSimpleMenu>.Create([doOwnsValues]);
  FActions := TList<string>.Create;
  FActionsMap := TDictionary<string, Integer>.Create;
  FNextSteps := TDictionary<string, TNextStepFunction>.Create;
  FCommands := TObjectList<TBotCommand>.Create;
  FOnMessageProcedures := TList<TOnTelegramMessage>.Create;
  FOnCallbackQueryProcedures := TList<TOnTelegramCallbackQuery>.Create;
end;

procedure TTelegramBotEx.DeleteNextStep(const ATelegramId: string);
begin
  FNextSteps.Remove(ATelegramId);
end;

destructor TTelegramBotEx.Destroy;
begin
  FreeAndNil(FSimpleButtons);
  FreeAndNil(FSimpleMenus);
  FreeAndNil(FButtonsMap);
  FreeAndNil(FActions);
  FreeAndNil(FActionsMap);
  FreeAndNil(FNextSteps);
  FreeAndNil(FCommands);
  FreeAndNil(FOnMessageProcedures);
  FreeAndNil(FOnCallbackQueryProcedures);
  inherited;
end;

function TTelegramBotEx.DoOnMessage(const AMessage: TTelegramMessage): Boolean;
var
  vDoOnMessage: TOnTelegramMessage;
begin
  Result := False;
  for vDoOnMessage in FOnMessageProcedures do
    if vDoOnMessage(AMessage) then
    begin
      Result := True;
      Break;
    end;
end;

function TTelegramBotEx.DoOnCallbackQuery(const ACallbackQuery: TTelegramCallbackQuery): Boolean;
var
  vDoOnCallbackQuery: TOnTelegramCallbackQuery;
begin
  Result := False;
  for vDoOnCallbackQuery in FOnCallbackQueryProcedures do
    if vDoOnCallbackQuery(ACallbackQuery) then
    begin
      Result := True;
      Break;
    end;
end;

procedure TTelegramBotEx.DoInitialize;
begin

end;

procedure TTelegramBotEx.RegisterAction(const AName: string);
var
  vId: integer;
begin
  vId := FActions.Add(AName);
  FActionsMap.Add(AName, vId);
end;

procedure TTelegramBotEx.RegisterButton(const AName: string; const ACaption: string; const AURL: string);
var
  vButton: TSimpleButton;
begin
  Assert(not FButtonsMap.ContainsKey(AName), 'Button ' + AName + ' is already presented');
  vButton := TSimpleButton.Create(FSimpleButtons.Count, AName, ACaption, AURL);
  FSimpleButtons.Add(vButton);
  FButtonsMap.Add(AName, vButton);
end;

procedure TTelegramBotEx.RegisterCommand(const ACommand, ADescription: string);
var
  vCommand: TBotCommand;
begin
  vCommand := TBotCommand.Create(ACommand, ADescription);
  FCommands.Add(vCommand);
end;

procedure TTelegramBotEx.SendCommandsToTelegram;
var
  vCommands: TStringList;
  vCommand: TBotCommand;
begin
  if FCommands.Count = 0 then
    Exit;

  vCommands := TStringList.Create;
  try
    for vCommand in FCommands do
      vCommands.Add(vCommand.Command + '=' + vCommand.Description);
    SetMyCommands(vCommands);
  finally
    FreeAndNil(vCommands);
  end;
end;

procedure TTelegramBotEx.RegisterMenu(const AMenuName: string;
  const AConstructProcedure: TConstructSimpleMenuProcedure);
begin
  Assert(Assigned(AConstructProcedure), 'Функция создания должна быть!');
  FSimpleMenus.Add(AMenuName, TSimpleMenu.Create(FSimpleMenus.Count, AConstructProcedure));
end;

procedure TTelegramBotEx.RegisterNextStep(const AChatId: string; const AProcedure: TNextStepFunction; const AObject: TObject);
begin
  FNextSteps.AddOrSetValue(AChatId, AProcedure);
end;

procedure TTelegramBotEx.RegisterMenu(const AMenuName: string;
  const ACaption: string; const AButtons: TButtons;
  const ABackButton: string);
var
  vSimpleMenu: TSimpleMenu;
  vSimpleButton: TSimpleButton;
  vRow: TButtonsRow;
  I, J: Integer;
begin
  Assert(not FSimpleMenus.ContainsKey(AMenuName), 'Меню ' + AMenuName + ' уже зарегистрировано');
  vSimpleMenu := TSimpleMenu.Create(FSimpleMenus.Count, ACaption, ABackButton);
  for I := 0 to Length(AButtons) - 1 do
  begin
    vRow := AButtons[I];
    for J := 0 to Length(vRow) - 1 do
    begin
      Assert(FButtonsMap.TryGetValue(vRow[J], vSimpleButton), 'Кнопка ' + vRow[J] + ' для меню не найдена');
      vSimpleMenu.AddButton(vSimpleButton, I);
    end;
  end;
  FSimpleMenus.Add(AMenuName, vSimpleMenu);
end;

procedure TTelegramBotEx.SendCalendar(const AMessage: TTelegramMessage; const ACurrentDate, AMinDate: TDateTime; const ATelegramId, ASelectDateAction, AData, AAcceptBtn: string;
  const ACancelBtn: string = ''; const  APhoto: string = '');
var
  vBeginDate, vEndDate, vIteratorDate, vCurrentDate: TDateTime;
  vCaption: string;
  vKeyboard: TTelegramInlineKeyboardMarkup;
  vBtnId, vAcceptBtnId, vCancleBtnId, vActionId: Integer;
  vMinDate: TDateTime;
  vData: string;
begin
  vMinDate := AMinDate;
  vCurrentDate := Max(vMinDate, ACurrentDate);
  vCaption := DateToStr(vCurrentDate);
  vBeginDate := StartOfTheWeek(StartOfTheMonth(vCurrentDate));
  vEndDate := EndOfTheWeek(EndOfTheMonth(vCurrentDate));
  vIteratorDate := vBeginDate;
  vBtnId := FButtonsMap.Items['calendar_date'].Id;
  vAcceptBtnId := FButtonsMap.Items[AAcceptBtn].Id;
  vCancleBtnId := -1;
  if ACancelBtn <> '' then
    vCancleBtnId := FButtonsMap.Items[ACancelBtn].Id;
  vActionId := FActionsMap.Items[ASelectDateAction];

  vData := Format('%d %d %s %s %d %d %s', [vBtnId, vActionId, '%s', DateToStr(AMinDate), vAcceptBtnId, vCancleBtnId, AData]);

  vKeyboard := TTelegramInlineKeyboardMarkup.Create;
  vKeyboard.AddButton('<', Format(vData, [DateToStr(IncMonth(vCurrentDate, -1))]), 0);
  vKeyboard.AddButton(FormatDateTime('mmmm yyyy', vCurrentDate), '-1', 0);
  vKeyboard.AddButton('>', Format(vData, [DateToStr(IncMonth(vCurrentDate, +1))]), 0);
  while vIteratorDate < vEndDate do
  begin
    if (MonthOf(vIteratorDate) <> MonthOf(vCurrentDate)) or (vIteratorDate < vMinDate) then
      vKeyboard.AddButton(' ', '-1', WeeksBetween(vIteratorDate, vBeginDate) + 1)
    else
      vKeyboard.AddButton(IntToStr(DayOfTheMonth(vIteratorDate)), Format(vData, [DateToStr(vIteratorDate)]), WeeksBetween(vIteratorDate, vBeginDate) + 1);
    vIteratorDate := vIteratorDate + 1;
  end;
  vData := DateToStr(vCurrentDate);
  if AData <> '' then
    vData := vData + ' ' + AData;

  AppendKeyboard(vKeyboard, AAcceptBtn, vData, DateToStr(vCurrentDate) + ' Подтвердить');
  AppendKeyboard(vKeyboard, ACancelBtn, AData, 'Отмена');

  if APhoto = '' then
  begin
    if Assigned(AMessage) then
      EditMessageText(AMessage, vCaption, vKeyboard)
    else
      SendMessage(ATelegramId, vCaption, vKeyboard);
  end
  else
  begin
    if Assigned(AMessage) then
      EditMessageMedia(AMessage, APhoto, vCaption, vKeyboard)
    else
      SendPhoto(ATelegramId, APhoto, vCaption, vKeyboard);
  end;

  FreeAndNil(vKeyboard);
end;

procedure TTelegramBotEx.SendConfirmation(const AMessage: TTelegramMessage; const ATelegramId, AText, AAction, AData, APhoto, ADocument: string);
var
  vActionId: Integer;
  vKeyboard: TTelegramInlineKeyboardMarkup;
begin
  if Assigned(AMessage) then
    DeleteMessage(AMessage);
  Assert(FActionsMap.TryGetValue(AAction, vActionId), 'Action <'+AAction+'> not found');
  vKeyboard := TTelegramInlineKeyboardMarkup.Create;
  AppendKeyboard(vKeyboard, 'confirm', IntToStr(vActionId) + ' ' + IntToStr(Integer(tmrYes)) + ' ' + AData);
  AppendKeyboard(vKeyboard, 'reject', IntToStr(vActionId) + ' ' + IntToStr(Integer(tmrNo)) + ' ' + AData);

  if APhoto <> '' then
    SendPhoto(ATelegramId, APhoto, AText, vKeyboard)
  else if ADocument <> '' then
    SendDocument(ATelegramId, ADocument, AText, vKeyboard)
  else
    SendMessage(ATelegramId, AText, vKeyboard);
  FreeAndNil(vKeyboard);
end;

procedure TTelegramBotEx.SendMenu(const AMessage: TTelegramMessage;
  const AMenuName, ARecipient: string; const AExtraData: TCallbackData; const ACaption, APhoto: string);
var
  vMenu: TSimpleMenu;
  vKeyboard: TTelegramInlineKeyboardMarkup;
  vRow: TList<TSimpleButton>;
  vButton: TSimpleButton;
  I: Integer;
  vRowAdded: Boolean;
  vCaption: string;
  vRecipient: string;
  vData: TCallbackData;
  vOwnData: Boolean;
begin
  Assert(FSimpleMenus.TryGetValue(AMenuName, vMenu), 'Menu ' + AMenuName + ' not found');

  vRecipient := ARecipient;
  if (vRecipient = '') and Assigned(AMessage) then
    vRecipient := AMessage.Chat;

  vOwnData := not Assigned(AExtraData);
  if vOwnData then
    vData := TCallbackData.Create
  else
    vData := AExtraData;

  vKeyboard := TTelegramInlineKeyboardMarkup.Create;
  try
    if Assigned(vMenu.ConstructProcedure) then
      vMenu.ConstructProcedure(vRecipient, vData, vCaption, vKeyboard)
    else
    begin
      I := 0;
      for vRow in vMenu.Buttons do
      begin
        vRowAdded := False;
        for vButton in vRow do
          vRowAdded := vRowAdded or AppendMenuKeyboard(vKeyboard, vButton.Name, vRecipient, vData, '', I);
        if vRowAdded then
          Inc(I);
      end;
      AppendMenuKeyboard(vKeyboard, vMenu.BackButton, vRecipient, vData, 'Назад');
      vCaption := vMenu.Caption;
      if ACaption <> '' then
        vCaption := ACaption;
    end;
    if Assigned(AMessage)then
    begin
      if (AMessage.Photo <> '') then
      begin
        if APhoto = '' then
        begin
          DeleteMessage(AMessage);
          SendMessage(vRecipient, vCaption, vKeyboard);
        end
        else
          EditMessageMedia(AMessage, APhoto, vCaption, vKeyboard);
      end
      else if APhoto = '' then
        EditMessageText(AMessage, vCaption, vKeyboard)
      else
        EditMessageMedia(AMessage, APhoto, vCaption, vKeyboard);
    end
    else if APhoto = '' then
      SendMessage(vRecipient, vCaption, vKeyboard)
    else
      SendPhoto(vRecipient, APhoto, vCaption, vKeyboard);
  finally
    if vOwnData then
      FreeAndNil(vData);
    FreeAndNil(vKeyboard);
  end;
end;

procedure TTelegramBotEx.SendMenu(const AMessage: TTelegramMessage;
  const AMenuName, ARecipient, AExtraData, ACaption, APhoto: string);
var
  vData: TCallbackData;
begin
  vData := TCallbackData.Create(AExtraData);
  try
    SendMenu(AMessage, AMenuName, ARecipient, vData, ACaption, APhoto);
  finally
    FreeAndNil(vData);
  end;
end;

{ TSimpleButton }

constructor TSimpleButton.Create(const AId: Integer; const AName, ACaption: string; const AURL: string);
begin
  Id := AId;
  Name := AName;
  Caption := ACaption;
  Url := AURL;
end;

{ TBotCommand }

constructor TBotCommand.Create(const ACommand, ADescription: string);
begin
  Command := ACommand;
  Description := ADescription;
end;

{ TCallbackData }

constructor TCallbackData.Create(const AData: string);
begin
  FParams := TStringList.Create;
  FParams.Delimiter := ' ';
  FParams.StrictDelimiter := True;
  FParams.QuoteChar := #0;
  Init(AData);
end;

constructor TCallbackData.Create;
begin
  FParams := TStringList.Create;
  FParams.Delimiter := ' ';
  FParams.StrictDelimiter := True;
  FParams.QuoteChar := #0;
end;

destructor TCallbackData.Destroy;
begin
  FreeAndNil(FParams);
  inherited;
end;

function TCallbackData.Add(const AValue: string): TCallbackData;
var
  vList: TStrings;
  vText: string;
begin
  vList := CreateDelimitedList(AValue, ' ');
  for vText in vList do
    FParams.Add(vText);
  Result := Self;
end;

function TCallbackData.Add(const AValue: Integer): TCallbackData;
begin
  FParams.Add(IntToStr(AValue));
  Result := Self;
end;

function TCallbackData.AddIf(const ACondition: Boolean; const AValue: string): TCallbackData;
begin
  if ACondition then
    FParams.Add(AValue);
  Result := Self;
end;

function TCallbackData.AddIf(const ACondition: Boolean; const AValue: Integer): TCallbackData;
begin
  if ACondition then
    FParams.Add(IntToStr(AValue));
  Result := Self;
end;

procedure TCallbackData.Clear;
begin
  FParams.Clear;
end;

function TCallbackData.ToString: string;
begin
  Result := FParams.DelimitedText;
end;

function TCallbackData.GetParam(AIndex: Integer): string;
begin
  if (AIndex >= 0) and (AIndex < FParams.Count) then
    Result := FParams[AIndex]
  else
    Result := '';
end;

function TCallbackData.GetParamAsInt(AIndex: Integer): Integer;
begin
  Result := GetInteger(AIndex, 0);
end;

function TCallbackData.GetCount: Integer;
begin
  Result := FParams.Count;
end;

function TCallbackData.Has(AIndex: Integer): Boolean;
begin
  Result := (AIndex >= 0) and (AIndex < FParams.Count);
end;

function TCallbackData.Init(const AData: Integer): TCallbackData;
begin
  Result := Self;
  FParams.DelimitedText := IntToStr(AData);
end;

function TCallbackData.Init(const AData: string): TCallbackData;
begin
  Result := Self;
  FParams.DelimitedText := AData;
end;

function TCallbackData.GetString(AIndex: Integer; const ADefault: string): string;
begin
  if Has(AIndex) then
    Result := FParams[AIndex]
  else
    Result := ADefault;
end;

function TCallbackData.GetInteger(AIndex: Integer; const ADefault: Integer): Integer;
begin
  if Has(AIndex) then
    Result := StrToIntDef(FParams[AIndex], ADefault)
  else
    Result := ADefault;
end;

function TCallbackData.GetBoolean(AIndex: Integer; const ADefault: Boolean): Boolean;
var
  vValue: string;
begin
  if Has(AIndex) then
  begin
    vValue := LowerCase(FParams[AIndex]);
    Result := (vValue = 'true') or (vValue = '1') or (vValue = 'yes');
  end
  else
    Result := ADefault;
end;

{ TSimpleMenu }

procedure TSimpleMenu.AddButton(const AButton: TSimpleButton; const ARow: Integer);
var
  vRow: TList<TSimpleButton>;
begin
  if (ARow < 0) or (ARow >= Buttons.Count) then
  begin
    vRow := TList<TSimpleButton>.Create;
    Buttons.Add(vRow);
  end
  else
    vRow := Buttons[ARow];

  vRow.Add(AButton);
end;

constructor TSimpleMenu.Create(const AId: Integer; const ACaption, ABackButton: string);
begin
  Id := AId;
  Caption := ACaption;
  BackButton := ABackButton;
  Buttons := TObjectList<TList<TSimpleButton>>.Create;
end;

constructor TSimpleMenu.Create(const AId: Integer; const AConstructProcedure: TConstructSimpleMenuProcedure);
begin
  Id := AId;
  ConstructProcedure := AConstructProcedure;
end;

destructor TSimpleMenu.Destroy;
begin
  FreeAndNil(Buttons);
  ConstructProcedure := nil;
  Caption := '';
  inherited;
end;

procedure TTelegramBotEx.RegisterDoOnMessage(const AFunction: TOnTelegramMessage);
begin
  FOnMessageProcedures.Add(AFunction);
end;

procedure TTelegramBotEx.RegisterDoOnCallbackQuery(const AFunction: TOnTelegramCallbackQuery);
begin
  FOnCallbackQueryProcedures.Add(AFunction);
end;

end.
