unit uTelegramBotEx;

interface

uses
  uTelegramTypes, uTelegramBot, Generics.Collections, Classes, SysUtils;

type
  TCallbackData = class;  // Forward declaration
  TTelegramBotEx = class;  // Forward declaration
  TFlowContext = class;    // Forward declaration

  EFlowCancelled = class(EAbort);
  TFlowPendingType = (fptNone, fptMessage, fptCallback);
  TFlowProc = reference to procedure(const ACtx: TFlowContext);

  TConstructSimpleMenuProcedure = reference to procedure (const ATelegramId: string; const AData: TCallbackData;
    out ACaption: string; out AKeyboard: TTelegramInlineKeyboardMarkup);

  TButtonsRow = array of string;
  TButtons = array of TButtonsRow;

  TTgModalResult = (tmrYes, tmrNo);

  TTelegramModuleClass = class of TTelegramModule;

  TTelegramModule = class
  private
    FBot: TTelegramBotEx;
  protected
    property Bot: TTelegramBotEx read FBot;
    procedure RegisterButton(const AName, ACaption: string; const AURL: string = ''); overload;
    procedure RegisterButton<T: TCallbackData, constructor>(const AName, ACaption: string; const AHandler: TProc<T>; const AACL: TFunc<T, Boolean> = nil); overload;
    procedure RegisterUrlButton<T: TCallbackData, constructor>(const AName, ACaption, AURL: string; const AACL: TFunc<T, Boolean>);
    procedure RegisterAction(const AName: string); overload;
    procedure RegisterAction<T: TCallbackData, constructor>(const AName: string; const AHandler: TProc<T, TTgModalResult>); overload;
    procedure RegisterCommand(const ACommand, ADescription: string);
    procedure RegisterMenu(const AMenuName, ACaption: string); overload;
    procedure RegisterMenu(const AMenuName, ACaption: string; const AButtons: TButtons; const ABackButton: string = ''); overload;
    procedure RegisterMenu(const AMenuName: string; const AConstructProcedure: TConstructSimpleMenuProcedure; const AButtonCaption: string = ''); overload;
    procedure RegisterMenu<T: TCallbackData, constructor>(const AMenuName, ACaption: string; const AACL: TFunc<T, Boolean>); overload;
  public
    constructor Create(const ABot: TTelegramBotEx); virtual;
    procedure Register; virtual;
    procedure Initialize; virtual;
    function OnMessage(const AMessage: TTelegramMessage): Boolean; virtual;
    function OnCallback(const AAction: string; const AParams: TCallbackData;
      const ACallback: TTelegramCallbackQuery): Boolean; virtual;
    function OnAction(const AName: string; const AParams: TCallbackData;
      const ACallback: TTelegramCallbackQuery): Boolean; virtual;
    function OnCommand(const ACommand: string; const AMessage: TTelegramMessage): Boolean; virtual;
    function CanHandleUser(const ATelegramId: string): Boolean; virtual;
    function CanShowButton(const AButton, ATelegramId, AData: string): Boolean; virtual;
  end;


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
    FCallback: TTelegramCallbackQuery;
    function GetParam(AIndex: Integer): string;
    function GetParamAsInt(AIndex: Integer): Integer;
    function GetCount: Integer;
    function GetCallback: TTelegramCallbackQuery;
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

    procedure Serialize; virtual;
    procedure ParseFields; virtual;
    procedure Parse; virtual;
    procedure ParseForACL(const ATelegramId: string); virtual;
    procedure LoadData(const AData: string);

    property Count: Integer read GetCount;
    property Params[AIndex: Integer]: string read GetParam; default;
    property AsInt[AIndex: Integer]: Integer read GetParamAsInt;
    property Callback: TTelegramCallbackQuery read GetCallback;
  end;

  TTypedButtonHandler = class abstract
  public
    function CreateData: TCallbackData; virtual; abstract;
    procedure Execute(const AData: TCallbackData); virtual; abstract;
    function CheckACL(const AData: TCallbackData): Boolean; virtual; abstract;
    function HasHandler: Boolean; virtual; abstract;
  end;

  TTypedButtonHandler<T: TCallbackData, constructor> = class(TTypedButtonHandler)
  private
    FHandler: TProc<T>;
    FACL: TFunc<T, Boolean>;
  public
    constructor Create(const AHandler: TProc<T>; const AACL: TFunc<T, Boolean>);
    function CreateData: TCallbackData; override;
    procedure Execute(const AData: TCallbackData); override;
    function CheckACL(const AData: TCallbackData): Boolean; override;
    function HasHandler: Boolean; override;
  end;

  TTypedActionHandler = class abstract
  public
    procedure Execute(const AParams: TCallbackData; const ACallback: TTelegramCallbackQuery); virtual; abstract;
  end;

  TTypedActionHandler<T: TCallbackData, constructor> = class(TTypedActionHandler)
  private
    FHandler: TProc<T, TTgModalResult>;
  public
    constructor Create(const AHandler: TProc<T, TTgModalResult>);
    procedure Execute(const AParams: TCallbackData; const ACallback: TTelegramCallbackQuery); override;
  end;

  TFlowContext = class
  private
    FBot: TTelegramBotEx;
    FChatId: string;
    FSchedulerFiber: Pointer;
    FFiberHandle: Pointer;
    FPendingType: TFlowPendingType;
    FPendingMessage: TTelegramMessage;
    FPendingAction: string;
    FPendingDate: TDateTime;
    FAwaiterMessageId: Integer;
    FCancelled: Boolean;
    FCompleted: Boolean;
    FProc: TFlowProc;
    FCancelButton: string;
    FCancelButtonData: TCallbackData;
    function BuildCancelKeyboard(const ACancelButton: string; const ACancelData: TCallbackData): TTelegramInlineKeyboardMarkup;
    function GetEffectiveCancelButton(const AOverride: string): string;
    function GetEffectiveCancelData(const AOverride: TCallbackData): TCallbackData;
    procedure SetCancelButtonData(const AValue: TCallbackData);
    procedure SwitchToScheduler;
  public
    constructor Create(const ABot: TTelegramBotEx; const AChatId: string;
      const ASchedulerFiber: Pointer; const AProc: TFlowProc);
    destructor Destroy; override;
    property ChatId: string read FChatId;
    property CancelButton: string write FCancelButton;
    property CancelButtonData: TCallbackData write SetCancelButtonData;
    function AwaitMessage: TTelegramMessage;
    function AwaitString(const APrompt: string; const ACancelButton: string = ''; ACancelData: TCallbackData = nil): string;
    function AwaitInteger(const APrompt: string; const ACancelButton: string = ''; ACancelData: TCallbackData = nil): Integer;
    function AwaitPositiveInteger(const APrompt: string; const ACancelButton: string = ''; ACancelData: TCallbackData = nil): Integer;
    function AwaitPhoto(const APrompt: string; const ACancelButton: string = ''; ACancelData: TCallbackData = nil): string;
    function AwaitDocument(const APrompt: string; const ACancelButton: string = ''; ACancelData: TCallbackData = nil): string;
    function AwaitTextOrPhoto(const APrompt: string; out AText, APhoto: string; const ACancelButton: string = ''; ACancelData: TCallbackData = nil): Boolean;
    function AwaitContact(const APrompt: string; out APhone, AOwner: string; const ACancelButton: string = ''; ACancelData: TCallbackData = nil): Boolean;
    function AwaitUsername(const APrompt: string; const ACancelButton: string = ''; ACancelData: TCallbackData = nil): string;
    procedure AwaitTimeRange(const APrompt: string; out AFrom, ATo: TDateTime; const ACancelButton: string = ''; ACancelData: TCallbackData = nil);
    function AwaitButton(const APrompt: string; const AActions, ACaptions: array of string; const ACancelButton: string = ''; ACancelData: TCallbackData = nil): string;
    function AwaitDate(const ACurrentDate, AMinDate: TDateTime; const ACancelButton: string = ''; ACancelData: TCallbackData = nil): TDateTime;
    procedure Send(const AText: string);
  end;

  TFlowState = class
  public
    FiberHandle: Pointer;
    Context: TFlowContext;
    destructor Destroy; override;
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
    class var FModuleClasses: TList<TTelegramModuleClass>;
  private
    FSimpleMenus: TObjectDictionary<string, TSimpleMenu>;
    FOnMessageProcedures: TList<TOnTelegramMessage>;
    FOnCallbackQueryProcedures: TList<TOnTelegramCallbackQuery>;
    FModules: TObjectList<TTelegramModule>;
    FTypedHandlers: TObjectDictionary<string, TTypedButtonHandler>;
    FTypedActions: TObjectDictionary<string, TTypedActionHandler>;
    FSchedulerFiber: Pointer;
    FActiveFlows: TObjectDictionary<string, TFlowState>;
    function InternalExecuteCalbackAction(const ACallback: TTelegramCallbackQuery): Boolean;
    function TryResumeFlowWithMessage(const AMessage: TTelegramMessage): Boolean;
    function TryResumeFlowWithCallback(const ACallback: TTelegramCallbackQuery): Boolean;
    procedure SilentTerminateFlow(const AChatId: string; const AState: TFlowState);
    procedure BuildCalendarKeyboard(const ATelegramId: string;
      const ACurrentDate, AMinDate: TDateTime; const ASelectDateAction, AData,
      AAcceptBtn, ACancelBtn: string; out ACaption: string;
      out AKeyboard: TTelegramInlineKeyboardMarkup;
      const ACancelData: TCallbackData = nil);
    function AppendKeyboard(const AKeyboard: TTelegramInlineKeyboardMarkup; const AButton: string; const AData: string; const ACaption: string = ''; const ARow: Integer = -1): Integer; overload;
  protected
    FSimpleButtons: TObjectList<TSimpleButton>;
    FButtonsMap: TDictionary<string, TSimpleButton>;
    FActions: TList<string>;
    FActionsMap: TDictionary<string, Integer>;
    FCommands: TObjectList<TBotCommand>;
    function CheckButtonAdd(const AButton, ATelegramId, AData: string): Boolean; virtual;
    function DoOnMessage(const AMessage: TTelegramMessage): Boolean; override;
    function DoOnCallbackQuery(const ACallbackQuery: TTelegramCallbackQuery): Boolean; override;

    procedure SendCommandsToTelegram;

    procedure DoInitialize; virtual;

    procedure ExecuteAction(const AName: string; const AParams: TCallbackData; const ACallBack: TTelegramCallbackQuery); virtual;

    function HandleModulesMessage(const AMessage: TTelegramMessage): Boolean;
    function HandleModulesCallback(const ACallback: TTelegramCallbackQuery): Boolean;
  public
    constructor Create(const AToken: string); override;
    destructor Destroy; override;

    procedure Initialize;

    class procedure RegisterModule(const AClass: TTelegramModuleClass);
    function FindModule(const AClass: TTelegramModuleClass): TTelegramModule;
    function DispatchCommand(const ACommand: string; const AMessage: TTelegramMessage): Boolean;

    procedure RegisterDoOnMessage(const AFunction: TOnTelegramMessage);
    procedure RegisterDoOnCallbackQuery(const AFunction: TOnTelegramCallbackQuery);

    procedure StartFlow(const AChatId: string; const AProc: TFlowProc);
    procedure CancelFlow(const AChatId: string);
    procedure DoFlowError(const AChatId: string; const AException: Exception); virtual;
    procedure InitSchedulerFiber;
    function SendCalendarResulted(const ATelegramId: string;
      const ACurrentDate, AMinDate: TDateTime; const ACancelButton: string = '';
      const ACancelData: TCallbackData = nil): TTelegramMessage;
    procedure RegisterAction(const AName: string); overload;
    procedure RegisterAction<T: TCallbackData, constructor>(const AName: string; const AHandler: TProc<T, TTgModalResult>); overload;
    procedure RegisterButton(const AName: string; const ACaption: string; const AURL: string = ''); overload;
    procedure RegisterButton<T: TCallbackData, constructor>(const AName, ACaption: string; const AHandler: TProc<T>; const AACL: TFunc<T, Boolean> = nil); overload;
    procedure RegisterUrlButton<T: TCallbackData, constructor>(const AName, ACaption, AURL: string; const AACL: TFunc<T, Boolean>);
    procedure RegisterCommand(const ACommand, ADescription: string);

    procedure RegisterMenu(const AMenuName, ACaption: string); overload;
    procedure RegisterMenu(const AMenuName, ACaption: string; const AButtons: TButtons; const ABackButton: string = ''); overload;
    procedure RegisterMenu(const AMenuName: string; const AConstructProcedure: TConstructSimpleMenuProcedure; const AButtonCaption: string = ''); overload;
    procedure RegisterMenu<T: TCallbackData, constructor>(const AMenuName, ACaption: string; const AACL: TFunc<T, Boolean>); overload;

    procedure SendCalendar(const AMessage: TTelegramMessage; const ACurrentDate, AMinDate: TDateTime; const ATelegramId, ASelectDateAction, AData, AAcceptBtn: string;
      const ACancelBtn: string = ''; const  APhoto: string = '');


    function AppendKeyboard(const AKeyboard: TTelegramInlineKeyboardMarkup; const AButton: string; const AData: TCallbackData = nil; const ACaption: string = ''; const ARow: Integer = -1): Integer; overload;
    function AppendMenuKeyboard(const AKeyboard: TTelegramInlineKeyboardMarkup; const AButton, ATelegramId: string; const AData: TCallbackData; const ACaption: string = ''; const ARow: Integer = -1): Boolean; overload;
    function AppendMenuKeyboard(const AKeyboard: TTelegramInlineKeyboardMarkup; const AButton, ATelegramId, AData: string; const ACaption: string = ''; const ARow: Integer = -1): Boolean; overload;
    //todo: add captions
    procedure SendConfirmation(const AMessage: TTelegramMessage; const ATelegramId, AText, AAction: string; const AData: TCallbackData; const APhoto: string = ''; const ADocument: string = ''); overload;

    procedure SendMenu(const AMessage: TTelegramMessage; const AMenuName: string; const ARecipient: string = '';
      const AExtraData: TCallbackData = nil; const ACaption: string = ''; const APhoto: string = ''); overload;
    procedure SendMenu<T: TCallbackData, constructor>(const AMessage: TTelegramMessage; const AMenuName, ARecipient: string; const AExtraData: T; const ACaption: string = ''; const APhoto: string = ''); overload;

    procedure Replace(const AMessage: TTelegramMessage; const AChatId, AText: string;
      const AReplyMarkup: TTelegramInlineKeyboardMarkup = nil);
  end;

function CreateDelimitedList(const ADelimitedText: string; const ADelimiter: Char = ';'): TStrings;
function NormalizeTimeString(const AText: string): string;

implementation

uses
  Math, DateUtils, StrUtils, Generics.Defaults, Windows;

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

{ FiberProc — entry point for all flow fibers (stdcall, called by Windows) }

procedure FiberProc(lpFiberParameter: Pointer); stdcall;
var
  vCtx: TFlowContext;
begin
  vCtx := TFlowContext(lpFiberParameter);
  try
    vCtx.FProc(vCtx);
  except
    on EFlowCancelled do ;
    on E: Exception do
      vCtx.FBot.DoFlowError(vCtx.FChatId, E);
  end;
  vCtx.FCompleted := True;
  SwitchToFiber(vCtx.FSchedulerFiber);
end;

{ TFlowState }

destructor TFlowState.Destroy;
begin
  if FiberHandle <> nil then
  begin
    DeleteFiber(FiberHandle);
    FiberHandle := nil;
  end;
  FreeAndNil(Context);
  inherited;
end;

{ TFlowContext }

constructor TFlowContext.Create(const ABot: TTelegramBotEx; const AChatId: string;
  const ASchedulerFiber: Pointer; const AProc: TFlowProc);
begin
  inherited Create;
  FBot := ABot;
  FChatId := AChatId;
  FSchedulerFiber := ASchedulerFiber;
  FFiberHandle := nil;
  FPendingType := fptNone;
  FPendingMessage := nil;
  FPendingAction := '';
  FPendingDate := 0;
  FAwaiterMessageId := -1;
  FCancelled := False;
  FCompleted := False;
  FProc := AProc;
  FCancelButton := '';
  FCancelButtonData := nil;
end;

destructor TFlowContext.Destroy;
begin
  FreeAndNil(FCancelButtonData);
  inherited;
end;

procedure TFlowContext.SetCancelButtonData(const AValue: TCallbackData);
begin
  FreeAndNil(FCancelButtonData);
  FCancelButtonData := AValue;
end;

function TFlowContext.BuildCancelKeyboard(const ACancelButton: string; const ACancelData: TCallbackData): TTelegramInlineKeyboardMarkup;
begin
  Result := TTelegramInlineKeyboardMarkup.Create;
  if ACancelButton <> '' then
    FBot.AppendKeyboard(Result, ACancelButton, ACancelData, 'Назад');
end;

function TFlowContext.GetEffectiveCancelButton(const AOverride: string): string;
begin
  if AOverride <> '' then
    Result := AOverride
  else
    Result := FCancelButton;
end;

function TFlowContext.GetEffectiveCancelData(const AOverride: TCallbackData): TCallbackData;
begin
  if Assigned(AOverride) then
    Result := AOverride
  else
    Result := FCancelButtonData;
end;

procedure TFlowContext.SwitchToScheduler;
begin
  SwitchToFiber(FSchedulerFiber);
  if FCancelled then
    raise EFlowCancelled.Create('');
end;

procedure TFlowContext.Send(const AText: string);
begin
  FBot.SendMessage(FChatId, AText);
end;

function TFlowContext.AwaitMessage: TTelegramMessage;
begin
  FPendingType := fptMessage;
  FPendingMessage := nil;
  SwitchToScheduler;
  Result := FPendingMessage;
end;

function TFlowContext.AwaitString(const APrompt: string; const ACancelButton: string = ''; ACancelData: TCallbackData = nil): string;
var
  vKeyboard: TTelegramInlineKeyboardMarkup;
  vMsg: TTelegramMessage;
begin
  vKeyboard := BuildCancelKeyboard(GetEffectiveCancelButton(ACancelButton), GetEffectiveCancelData(ACancelData));
  FreeAndNil(ACancelData);
  vMsg := FBot.SendMessageResulted(FChatId, APrompt, vKeyboard);
  FreeAndNil(vKeyboard);
  try
    while True do
    begin
      FPendingType := fptMessage;
      SwitchToScheduler;
      if FPendingMessage.Text <> '' then
        Break;
    end;
    Result := FPendingMessage.Text;
  finally
    FBot.DeleteKeyboard(vMsg);
    FreeAndNil(vMsg);
  end;
end;

function TFlowContext.AwaitInteger(const APrompt: string; const ACancelButton: string = ''; ACancelData: TCallbackData = nil): Integer;
var
  vKeyboard: TTelegramInlineKeyboardMarkup;
  vMsg: TTelegramMessage;
begin
  vKeyboard := BuildCancelKeyboard(GetEffectiveCancelButton(ACancelButton), GetEffectiveCancelData(ACancelData));
  FreeAndNil(ACancelData);
  vMsg := FBot.SendMessageResulted(FChatId, APrompt, vKeyboard);
  FreeAndNil(vKeyboard);
  try
    while True do
    begin
      FPendingType := fptMessage;
      SwitchToScheduler;
      if TryStrToInt(FPendingMessage.Text, Result) then
        Break;
    end;
  finally
    FBot.DeleteKeyboard(vMsg);
    FreeAndNil(vMsg);
  end;
end;

function TFlowContext.AwaitPositiveInteger(const APrompt: string; const ACancelButton: string = ''; ACancelData: TCallbackData = nil): Integer;
var
  vKeyboard: TTelegramInlineKeyboardMarkup;
  vMsg: TTelegramMessage;
begin
  vKeyboard := BuildCancelKeyboard(GetEffectiveCancelButton(ACancelButton), GetEffectiveCancelData(ACancelData));
  FreeAndNil(ACancelData);
  vMsg := FBot.SendMessageResulted(FChatId, APrompt, vKeyboard);
  FreeAndNil(vKeyboard);
  try
    while True do
    begin
      FPendingType := fptMessage;
      SwitchToScheduler;
      if TryStrToInt(FPendingMessage.Text, Result) and (Result > 0) then
        Break;
    end;
  finally
    FBot.DeleteKeyboard(vMsg);
    FreeAndNil(vMsg);
  end;
end;

function TFlowContext.AwaitPhoto(const APrompt: string; const ACancelButton: string = ''; ACancelData: TCallbackData = nil): string;
var
  vKeyboard: TTelegramInlineKeyboardMarkup;
  vMsg: TTelegramMessage;
begin
  vKeyboard := BuildCancelKeyboard(GetEffectiveCancelButton(ACancelButton), GetEffectiveCancelData(ACancelData));
  FreeAndNil(ACancelData);
  vMsg := FBot.SendMessageResulted(FChatId, APrompt, vKeyboard);
  FreeAndNil(vKeyboard);
  try
    while True do
    begin
      FPendingType := fptMessage;
      SwitchToScheduler;
      if FPendingMessage.Photo <> '' then
        Break;
    end;
    Result := FPendingMessage.Photo;
  finally
    FBot.DeleteKeyboard(vMsg);
    FreeAndNil(vMsg);
  end;
end;

function TFlowContext.AwaitDocument(const APrompt: string; const ACancelButton: string = ''; ACancelData: TCallbackData = nil): string;
var
  vKeyboard: TTelegramInlineKeyboardMarkup;
  vMsg: TTelegramMessage;
begin
  vKeyboard := BuildCancelKeyboard(GetEffectiveCancelButton(ACancelButton), GetEffectiveCancelData(ACancelData));
  FreeAndNil(ACancelData);
  vMsg := FBot.SendMessageResulted(FChatId, APrompt, vKeyboard);
  FreeAndNil(vKeyboard);
  try
    while True do
    begin
      FPendingType := fptMessage;
      SwitchToScheduler;
      if FPendingMessage.Document <> '' then
        Break;
    end;
    Result := FPendingMessage.Document;
  finally
    FBot.DeleteKeyboard(vMsg);
    FreeAndNil(vMsg);
  end;
end;

function TFlowContext.AwaitTextOrPhoto(const APrompt: string; out AText, APhoto: string; const ACancelButton: string = ''; ACancelData: TCallbackData = nil): Boolean;
var
  vKeyboard: TTelegramInlineKeyboardMarkup;
  vMsg: TTelegramMessage;
begin
  vKeyboard := BuildCancelKeyboard(GetEffectiveCancelButton(ACancelButton), GetEffectiveCancelData(ACancelData));
  FreeAndNil(ACancelData);
  vMsg := FBot.SendMessageResulted(FChatId, APrompt, vKeyboard);
  FreeAndNil(vKeyboard);
  try
    while True do
    begin
      FPendingType := fptMessage;
      SwitchToScheduler;
      if (FPendingMessage.Text <> '') or (FPendingMessage.Photo <> '') then
      begin
        AText := FPendingMessage.Text;
        APhoto := FPendingMessage.Photo;
        Result := True;
        Break;
      end;
    end;
  finally
    FBot.DeleteKeyboard(vMsg);
    FreeAndNil(vMsg);
  end;
end;

function TFlowContext.AwaitContact(const APrompt: string; out APhone, AOwner: string; const ACancelButton: string = ''; ACancelData: TCallbackData = nil): Boolean;
var
  vKeyboardReq: TTelegramReplyKeyboardMarkup;
  vKeyboard: TTelegramInlineKeyboardMarkup;
  vMsg: TTelegramMessage;
  vClearMsg: TTelegramMessage;
  vEmptyKeyboard: TTelegramReplyKeyboardRemove;
  vPhone: string;
  vPhoneNumber: Int64;
begin
  vKeyboardReq := TTelegramReplyKeyboardMarkup.Create(
    [[TTelegramReplyKeyboardButton.Create('Отправить контакт').RequestContact]]);
  vKeyboard := BuildCancelKeyboard(GetEffectiveCancelButton(ACancelButton), GetEffectiveCancelData(ACancelData));
  FreeAndNil(ACancelData);
  vMsg := FBot.SendMessageResulted(FChatId, APrompt, vKeyboardReq);
  FBot.EditMessageReplyMarkup(vMsg, vKeyboard);
  FreeAndNil(vKeyboardReq);
  FreeAndNil(vKeyboard);
  try
    while True do
    begin
      FPendingType := fptMessage;
      SwitchToScheduler;
      if Assigned(FPendingMessage.Contact) then
      begin
        vEmptyKeyboard := TTelegramReplyKeyboardRemove.Create;
        vClearMsg := FBot.SendMessageResulted(FChatId, 'clear', vEmptyKeyboard);
        FBot.DeleteMessage(vClearMsg);
        FreeAndNil(vClearMsg);
        FreeAndNil(vEmptyKeyboard);
        vPhone := FPendingMessage.Contact.Phone;
        if (Length(vPhone) > 0) and (vPhone[1] = '+') then
          vPhone := Copy(vPhone, 2, Length(vPhone) - 1);
        APhone := vPhone;
        AOwner := FPendingMessage.Contact.UserId;
        Result := True;
        Break;
      end
      else if Length(FPendingMessage.Text) > 10 then
      begin
        vPhone := FPendingMessage.Text;
        if (Length(vPhone) > 0) and (vPhone[1] = '+') then
          vPhone := Copy(vPhone, 2, Length(vPhone) - 1);
        if TryStrToInt64(vPhone, vPhoneNumber) then
        begin
          APhone := vPhone;
          AOwner := '';
          Result := True;
          Break;
        end;
      end;
    end;
  finally
    FBot.DeleteKeyboard(vMsg);
    FreeAndNil(vMsg);
  end;
end;

function TFlowContext.AwaitUsername(const APrompt: string; const ACancelButton: string = ''; ACancelData: TCallbackData = nil): string;
var
  vKeyboard: TTelegramInlineKeyboardMarkup;
  vMsg: TTelegramMessage;
begin
  vKeyboard := BuildCancelKeyboard(GetEffectiveCancelButton(ACancelButton), GetEffectiveCancelData(ACancelData));
  FreeAndNil(ACancelData);
  vMsg := FBot.SendMessageResulted(FChatId, APrompt, vKeyboard);
  FreeAndNil(vKeyboard);
  try
    while True do
    begin
      FPendingType := fptMessage;
      SwitchToScheduler;
      if (Length(FPendingMessage.Text) > 1) and (FPendingMessage.Text[1] = '@') then
      begin
        Result := Copy(FPendingMessage.Text, 2, Length(FPendingMessage.Text) - 1);
        Break;
      end;
    end;
  finally
    FBot.DeleteKeyboard(vMsg);
    FreeAndNil(vMsg);
  end;
end;

procedure TFlowContext.AwaitTimeRange(const APrompt: string; out AFrom, ATo: TDateTime; const ACancelButton: string = ''; ACancelData: TCallbackData = nil);
var
  vKeyboard: TTelegramInlineKeyboardMarkup;
  vMsg: TTelegramMessage;
  vTimeRange: TStrings;
begin
  vKeyboard := BuildCancelKeyboard(GetEffectiveCancelButton(ACancelButton), GetEffectiveCancelData(ACancelData));
  FreeAndNil(ACancelData);
  vMsg := FBot.SendMessageResulted(FChatId, APrompt, vKeyboard);
  FreeAndNil(vKeyboard);
  try
    while True do
    begin
      FPendingType := fptMessage;
      SwitchToScheduler;
      if FPendingMessage.Text = '' then
        Continue;
      vTimeRange := CreateDelimitedList(FPendingMessage.Text, '-');
      try
        if (vTimeRange.Count = 2) and
           TryStrToTime(NormalizeTimeString(vTimeRange[0]), AFrom) and
           TryStrToTime(NormalizeTimeString(vTimeRange[1]), ATo) then
          Break;
      finally
        FreeAndNil(vTimeRange);
      end;
    end;
  finally
    FBot.DeleteKeyboard(vMsg);
    FreeAndNil(vMsg);
  end;
end;

function TFlowContext.AwaitButton(const APrompt: string;
  const AActions, ACaptions: array of string; const ACancelButton: string = ''; ACancelData: TCallbackData = nil): string;
var
  vKeyboard: TTelegramInlineKeyboardMarkup;
  vMsg: TTelegramMessage;
  vData: TCallbackData;
  vEffectiveCancel: string;
  vSavedCancelButton: string;
  I: Integer;
begin
  vEffectiveCancel := GetEffectiveCancelButton(ACancelButton);
  vKeyboard := TTelegramInlineKeyboardMarkup.Create;
  vData := TCallbackData.Create;
  try
    for I := 0 to Length(AActions) - 1 do
    begin
      vData.Clear;
      FBot.AppendKeyboard(vKeyboard, AActions[I], vData, ACaptions[I]);
    end;
    if vEffectiveCancel <> '' then
      FBot.AppendKeyboard(vKeyboard, vEffectiveCancel, GetEffectiveCancelData(ACancelData), 'Назад');
    FreeAndNil(ACancelData);
  finally
    FreeAndNil(vData);
  end;
  vMsg := FBot.SendMessageResulted(FChatId, APrompt, vKeyboard);
  FreeAndNil(vKeyboard);
  vSavedCancelButton := FCancelButton;
  FCancelButton := vEffectiveCancel;
  try
    FAwaiterMessageId := vMsg.MessageId;
    FPendingType := fptCallback;
    FPendingAction := '';
    SwitchToScheduler;
    Result := FPendingAction;
  finally
    FAwaiterMessageId := -1;
    FCancelButton := vSavedCancelButton;
    FBot.DeleteKeyboard(vMsg);
    FreeAndNil(vMsg);
  end;
end;

function TFlowContext.AwaitDate(const ACurrentDate, AMinDate: TDateTime; const ACancelButton: string = ''; ACancelData: TCallbackData = nil): TDateTime;
var
  vMsg: TTelegramMessage;
  vEffectiveCancel: string;
  vSavedCancelButton: string;
begin
  vEffectiveCancel := GetEffectiveCancelButton(ACancelButton);
  vMsg := FBot.SendCalendarResulted(FChatId, ACurrentDate, AMinDate, vEffectiveCancel, GetEffectiveCancelData(ACancelData));
  FreeAndNil(ACancelData);
  vSavedCancelButton := FCancelButton;
  FCancelButton := vEffectiveCancel;
  try
    FAwaiterMessageId := vMsg.MessageId;
    FPendingType := fptCallback;
    FPendingDate := 0;
    SwitchToScheduler;
    Result := FPendingDate;
  finally
    FAwaiterMessageId := -1;
    FCancelButton := vSavedCancelButton;
    FreeAndNil(vMsg);
  end;
end;

procedure TTelegramBotEx.InitSchedulerFiber;
begin
  if FSchedulerFiber = nil then
    FSchedulerFiber := ConvertThreadToFiber(nil);
end;

procedure TTelegramBotEx.StartFlow(const AChatId: string; const AProc: TFlowProc);
var
  vOldState: TFlowState;
  vState: TFlowState;
  vCompleted: Boolean;
begin
  // Отменяем старый Fiber если есть
  if FActiveFlows.TryGetValue(AChatId, vOldState) then
  begin
    vOldState.Context.FCancelled := True;
    SwitchToFiber(vOldState.FiberHandle);
    FActiveFlows.Remove(AChatId);
  end;

  // Создаём новый Fiber
  vState := TFlowState.Create;
  vState.Context := TFlowContext.Create(Self, AChatId, FSchedulerFiber, AProc);
  vState.FiberHandle := CreateFiber(0, @FiberProc, vState.Context);
  vState.Context.FFiberHandle := vState.FiberHandle;
  FActiveFlows.Add(AChatId, vState);

  // Запускаем — Fiber работает до первого Await и переключается обратно
  SwitchToFiber(vState.FiberHandle);

  // Если Fiber завершился сразу (без Await)
  vCompleted := vState.Context.FCompleted;
  if vCompleted then
    FActiveFlows.Remove(AChatId);
end;

procedure TTelegramBotEx.SilentTerminateFlow(const AChatId: string; const AState: TFlowState);
begin
  AState.Context.FCancelled := True;
  SwitchToFiber(AState.FiberHandle);
  FActiveFlows.Remove(AChatId);
end;

procedure TTelegramBotEx.CancelFlow(const AChatId: string);
var
  vState: TFlowState;
begin
  if not FActiveFlows.TryGetValue(AChatId, vState) then
    Exit;
  SilentTerminateFlow(AChatId, vState);
end;

procedure TTelegramBotEx.DoFlowError(const AChatId: string; const AException: Exception);
begin
  SendMessage(AChatId, 'Произошла ошибка. Попробуйте ещё раз.');
end;

function TTelegramBotEx.TryResumeFlowWithMessage(const AMessage: TTelegramMessage): Boolean;
var
  vState: TFlowState;
  vChatId: string;
  vCompleted: Boolean;
begin
  Result := False;
  if not Assigned(AMessage) then
    Exit;
  if not FActiveFlows.TryGetValue(AMessage.From.Id, vState) then
    Exit;

  // Type mismatch: Flow ждёт кнопку, но пришёл текст → тихо завершаем, текст идёт дальше
  if vState.Context.FPendingType = fptCallback then
  begin
    SilentTerminateFlow(AMessage.From.Id, vState);
    Exit(False);
  end;

  if vState.Context.FPendingType <> fptMessage then
    Exit;

  vState.Context.FPendingMessage := AMessage;
  vState.Context.FPendingType := fptNone;
  Result := True;
  vChatId := AMessage.From.Id;
  SwitchToFiber(vState.FiberHandle);

  vCompleted := vState.Context.FCompleted;
  if vCompleted then
    FActiveFlows.Remove(vChatId);
end;

function TTelegramBotEx.TryResumeFlowWithCallback(const ACallback: TTelegramCallbackQuery): Boolean;
var
  vState: TFlowState;
  vCallbackData: TCallbackData;
  vBId: Integer;
  vButton: string;
  vChatId: string;
  vCompleted: Boolean;
  vDidResume: Boolean;
begin
  Result := False;
  vDidResume := False;
  vChatId := '';
  if not FActiveFlows.TryGetValue(ACallback.From.Id, vState) then
    Exit;

  vCallbackData := TCallbackData.Create(ACallback.Data);
  try
    if vCallbackData.Count < 1 then Exit;
    vBId := vCallbackData.GetInteger(0);
    if (vBId < 0) or (vBId >= FSimpleButtons.Count) then Exit;
    vButton := FSimpleButtons[vBId].Name;

    // Type mismatch: Flow ждёт текст, но пришла кнопка → тихо завершаем, кнопка идёт дальше
    if vState.Context.FPendingType = fptMessage then
    begin
      SilentTerminateFlow(ACallback.From.Id, vState);
      Exit(False);
    end;

    if vState.Context.FPendingType <> fptCallback then Exit;

    // Навигация по календарю — не прерываем Fiber, идёт в обычный роутинг
    if vButton = 'calendar_date' then Exit;

    // Кнопка отмены для fptCallback (AwaitButton / AwaitDate) → тихо завершаем, кнопка идёт дальше
    if (vState.Context.FCancelButton <> '') and (vButton = vState.Context.FCancelButton) then
    begin
      SilentTerminateFlow(ACallback.From.Id, vState);
      Exit(False);
    end;

    // Проверяем message_id — только кнопки с нужного сообщения резюмируют Flow
    if (vState.Context.FAwaiterMessageId <> -1) and
       Assigned(ACallback.AtMessage) and
       (ACallback.AtMessage.MessageId <> vState.Context.FAwaiterMessageId) then
      Exit;

    vState.Context.FPendingAction := vButton;
    if vButton = 'flow_accept_date' then
      vState.Context.FPendingDate := StrToDate(vCallbackData.GetString(1));
    vState.Context.FPendingType := fptNone;
    Result := True;
    vChatId := ACallback.From.Id;
    vDidResume := True;
    SwitchToFiber(vState.FiberHandle);
  finally
    FreeAndNil(vCallbackData);
  end;

  if vDidResume then
  begin
    vCompleted := vState.Context.FCompleted;
    if vCompleted then
      FActiveFlows.Remove(vChatId);
  end;
end;

procedure TTelegramBotEx.Initialize;
var
  vModule: TTelegramModule;
  I: Integer;
begin
  RegisterButton('confirm', 'Подтвердить');
  RegisterButton('reject', 'Отклонить');
  RegisterButton('calendar_date', 'Выбор дня в календаре');
  RegisterButton('flow_accept_date', 'Подтвердить дату');
  RegisterButton('flow_enter_text', 'Ввести вручную');
  RegisterAction('FlowCalendarSelect');

  for I := 0 to FModuleClasses.Count - 1 do
    FModules.Add(FModuleClasses[I].Create(Self));

  for vModule in FModules do
    vModule.Register;

  for vModule in FModules do
    vModule.Initialize;

  RegisterDoOnMessage(TryResumeFlowWithMessage);
  RegisterDoOnMessage(HandleModulesMessage);
  RegisterDoOnCallbackQuery(TryResumeFlowWithCallback);
  RegisterDoOnCallbackQuery(InternalExecuteCalbackAction);
  RegisterDoOnCallbackQuery(HandleModulesCallback);

  DoInitialize;
  SendCommandsToTelegram;
end;

function TTelegramBotEx.InternalExecuteCalbackAction(const ACallback: TTelegramCallbackQuery): Boolean;
var
  vBId, vAId, I: Integer;
  vButton, vAction: string;
  vInitialCount: Integer;
  vPhoto, vData, vCancelBtn: string;
  vCallbackData: TCallbackData;
  vExtraData: TCallbackData;
  vTypedHandler: TTypedButtonHandler;
  vTypedData: TCallbackData;
begin
  Result := True;

  vCallbackData := TCallbackData.Create(ACallback.Data);
  try
    if vCallbackData.Count < 1 then
      Exit(False);

    vBId := vCallbackData.GetInteger(0);
    vButton := FSimpleButtons[vBId].Name;

    if FTypedHandlers.TryGetValue(vButton, vTypedHandler) then
    begin
      vTypedData := vTypedHandler.CreateData;
      try
        vTypedData.LoadData(ACallback.Data);
        vTypedData.FCallback := ACallback;
        vTypedData.Parse;
        vTypedHandler.Execute(vTypedData);
      finally
        FreeAndNil(vTypedData);
      end;
      if vTypedHandler.HasHandler then
        Exit(True);
    end;

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
    else if FSimpleMenus.ContainsKey(vButton) then
    begin
      vExtraData := TCallbackData.Create;
      try
        for I := 1 to vCallbackData.Count - 1 do
          vExtraData.Add(vCallbackData.GetString(I));
        SendMenu(ACallback.AtMessage, vButton, ACallback.From.Id, vExtraData);
      finally
        FreeAndNil(vExtraData);
      end;
    end
    else
      Result := False;
  finally
    FreeAndNil(vCallbackData);
  end;
end;


function TTelegramBotEx.AppendKeyboard(const AKeyboard: TTelegramInlineKeyboardMarkup; const AButton: string; const AData: TCallbackData = nil; const ACaption: string = ''; const ARow: Integer = -1): Integer;
var
  vButton: TSimpleButton;
  vCaption: string;
  vCallbackData: TCallbackData;
  vOwnsData: Boolean;
begin
  Result := -1;
  if not FButtonsMap.TryGetValue(AButton, vButton) then
    Exit;

  vCaption := ACaption;
  if vCaption = '' then
    vCaption := vButton.Caption;

  if vButton.URL <> '' then
  begin
    Result := AKeyboard.AddUrlButton(vCaption, vButton.URL, ARow);
    Exit;
  end;

  vOwnsData := not Assigned(AData);
  if vOwnsData then
    vCallbackData := TCallbackData.Create
  else
    vCallbackData := AData;

  try
    vCallbackData.Serialize;
    if vCallbackData.Count > 0 then
      Result := AKeyboard.AddButton(vCaption, IntToStr(vButton.Id) + ' ' + vCallbackData.ToString, ARow)
    else
      Result := AKeyboard.AddButton(vCaption, IntToStr(vButton.Id), ARow);
  finally
    if vOwnsData then
      FreeAndNil(vCallbackData);
  end;
end;

function TTelegramBotEx.AppendKeyboard(const AKeyboard: TTelegramInlineKeyboardMarkup; const AButton: string; const AData: string; const ACaption: string = ''; const ARow: Integer = -1): Integer;
var
  vCallbackData: TCallbackData;
begin
  vCallbackData := TCallbackData.Create(AData);
  try
    Result := AppendKeyboard(AKeyboard, AButton, vCallbackData, ACaption, ARow);
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

constructor TTelegramBotEx.Create(const AToken: string);
begin
  inherited;
  FSimpleButtons := TObjectList<TSimpleButton>.Create;
  FButtonsMap := TDictionary<string, TSimpleButton>.Create;
  FSimpleMenus := TObjectDictionary<string, TSimpleMenu>.Create([doOwnsValues]);
  FActions := TList<string>.Create;
  FActionsMap := TDictionary<string, Integer>.Create;
  FActiveFlows := TObjectDictionary<string, TFlowState>.Create([doOwnsValues]);
  FTypedHandlers := TObjectDictionary<string, TTypedButtonHandler>.Create([doOwnsValues]);
  FTypedActions := TObjectDictionary<string, TTypedActionHandler>.Create([doOwnsValues]);
  FSchedulerFiber := nil;
  FCommands := TObjectList<TBotCommand>.Create;
  FOnMessageProcedures := TList<TOnTelegramMessage>.Create;
  FOnCallbackQueryProcedures := TList<TOnTelegramCallbackQuery>.Create;
  FModules := TObjectList<TTelegramModule>.Create;
end;

destructor TTelegramBotEx.Destroy;
begin
  FreeAndNil(FActiveFlows);
  FreeAndNil(FTypedHandlers);
  FreeAndNil(FTypedActions);
  FreeAndNil(FModules);
  FreeAndNil(FSimpleButtons);
  FreeAndNil(FSimpleMenus);
  FreeAndNil(FButtonsMap);
  FreeAndNil(FActions);
  FreeAndNil(FActionsMap);
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

function TTelegramBotEx.CheckButtonAdd(const AButton, ATelegramId, AData: string): Boolean;
var
  vModule: TTelegramModule;
  vTypedHandler: TTypedButtonHandler;
  vTypedData: TCallbackData;
  vBtn: TSimpleButton;
  vFullData: string;
begin
  if AButton = '' then
    Exit(False);

  if FTypedHandlers.TryGetValue(AButton, vTypedHandler) then
  begin
    vBtn := FButtonsMap[AButton];
    if AData <> '' then
      vFullData := IntToStr(vBtn.Id) + ' ' + AData
    else
      vFullData := IntToStr(vBtn.Id);
    vTypedData := vTypedHandler.CreateData;
    try
      vTypedData.LoadData(vFullData);
      vTypedData.ParseForACL(ATelegramId);
      Result := vTypedHandler.CheckACL(vTypedData);
    finally
      FreeAndNil(vTypedData);
    end;
    Exit;
  end;

  Result := True;
  for vModule in FModules do
    if not vModule.CanShowButton(AButton, ATelegramId, AData) then
      Exit(False);
end;

procedure TTelegramBotEx.ExecuteAction(const AName: string; const AParams: TCallbackData; const ACallBack: TTelegramCallbackQuery);
var
  vModule: TTelegramModule;
  vTypedAction: TTypedActionHandler;
begin
  if FTypedActions.TryGetValue(AName, vTypedAction) then
  begin
    vTypedAction.Execute(AParams, ACallBack);
    Exit;
  end;
  for vModule in FModules do
    if vModule.OnAction(AName, AParams, ACallBack) then
      Exit;
end;

function TTelegramBotEx.HandleModulesMessage(const AMessage: TTelegramMessage): Boolean;
var
  vModule: TTelegramModule;
begin
  Result := False;
  for vModule in FModules do
  begin
    if not vModule.CanHandleUser(AMessage.From.Id) then
      Continue;
    if vModule.OnMessage(AMessage) then
      Exit(True);
  end;
end;

function TTelegramBotEx.HandleModulesCallback(const ACallback: TTelegramCallbackQuery): Boolean;
var
  vCallbackData: TCallbackData;
  vBId: Integer;
  vAction: string;
  vModule: TTelegramModule;
begin
  Result := False;
  vCallbackData := TCallbackData.Create(ACallback.Data);
  try
    if vCallbackData.Count < 1 then
      Exit;
    vBId := vCallbackData.GetInteger(0);
    if (vBId < 0) or (vBId >= FSimpleButtons.Count) then
      Exit;
    vAction := FSimpleButtons[vBId].Name;
    for vModule in FModules do
    begin
      if not vModule.CanHandleUser(ACallback.From.Id) then
        Continue;
      if vModule.OnCallback(vAction, vCallbackData, ACallback) then
        Exit(True);
    end;
  finally
    FreeAndNil(vCallbackData);
  end;
end;

function TTelegramBotEx.DispatchCommand(const ACommand: string; const AMessage: TTelegramMessage): Boolean;
var
  vModule: TTelegramModule;
begin
  Result := False;
  for vModule in FModules do
    if vModule.OnCommand(ACommand, AMessage) then
      Exit(True);
end;

function TTelegramBotEx.FindModule(const AClass: TTelegramModuleClass): TTelegramModule;
var
  vModule: TTelegramModule;
begin
  Result := nil;
  for vModule in FModules do
    if vModule.ClassType = AClass then
      Exit(vModule);
end;

class procedure TTelegramBotEx.RegisterModule(const AClass: TTelegramModuleClass);
begin
  FModuleClasses.Add(AClass);
end;

procedure TTelegramBotEx.RegisterAction(const AName: string);
var
  vId: integer;
begin
  vId := FActions.Add(AName);
  FActionsMap.Add(AName, vId);
end;

procedure TTelegramBotEx.RegisterAction<T>(const AName: string; const AHandler: TProc<T, TTgModalResult>);
var
  vTypedAction: TTypedActionHandler<T>;
begin
  RegisterAction(AName);
  vTypedAction := TTypedActionHandler<T>.Create(AHandler);
  FTypedActions.Add(AName, vTypedAction);
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

procedure TTelegramBotEx.RegisterButton<T>(const AName, ACaption: string; const AHandler: TProc<T>; const AACL: TFunc<T, Boolean>);
var
  vTypedHandler: TTypedButtonHandler<T>;
begin
  RegisterButton(AName, ACaption);
  vTypedHandler := TTypedButtonHandler<T>.Create(AHandler, AACL);
  FTypedHandlers.Add(AName, vTypedHandler);
end;

procedure TTelegramBotEx.RegisterUrlButton<T>(const AName, ACaption, AURL: string; const AACL: TFunc<T, Boolean>);
var
  vTypedHandler: TTypedButtonHandler<T>;
begin
  RegisterButton(AName, ACaption, AURL);
  vTypedHandler := TTypedButtonHandler<T>.Create(nil, AACL);
  FTypedHandlers.Add(AName, vTypedHandler);
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

procedure TTelegramBotEx.RegisterMenu(const AMenuName, ACaption: string);
begin
  if not FButtonsMap.ContainsKey(AMenuName) then
    RegisterButton(AMenuName, ACaption);
end;

procedure TTelegramBotEx.RegisterMenu<T>(const AMenuName, ACaption: string; const AACL: TFunc<T, Boolean>);
var
  vTypedHandler: TTypedButtonHandler<T>;
begin
  if not FButtonsMap.ContainsKey(AMenuName) then
    RegisterButton(AMenuName, ACaption);
  vTypedHandler := TTypedButtonHandler<T>.Create(nil, AACL);
  FTypedHandlers.Add(AMenuName, vTypedHandler);
end;

procedure TTelegramBotEx.RegisterMenu(const AMenuName: string;
  const AConstructProcedure: TConstructSimpleMenuProcedure; const AButtonCaption: string = '');
begin
  Assert(Assigned(AConstructProcedure), 'Функция создания должна быть!');
  FSimpleMenus.Add(AMenuName, TSimpleMenu.Create(FSimpleMenus.Count, AConstructProcedure));
  if (AButtonCaption <> '') and not FButtonsMap.ContainsKey(AMenuName) then
    RegisterButton(AMenuName, AButtonCaption);
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
  if not FButtonsMap.ContainsKey(AMenuName) then
    RegisterButton(AMenuName, ACaption);
end;

procedure TTelegramBotEx.BuildCalendarKeyboard(const ATelegramId: string;
  const ACurrentDate, AMinDate: TDateTime; const ASelectDateAction, AData,
  AAcceptBtn, ACancelBtn: string; out ACaption: string;
  out AKeyboard: TTelegramInlineKeyboardMarkup;
  const ACancelData: TCallbackData = nil);
var
  vBeginDate, vEndDate, vIteratorDate, vCurrentDate: TDateTime;
  vBtnId, vAcceptBtnId, vCancelBtnId, vActionId: Integer;
  vMinDate: TDateTime;
  vData: string;
begin
  vMinDate := AMinDate;
  vCurrentDate := Max(vMinDate, ACurrentDate);
  ACaption := DateToStr(vCurrentDate);
  vBeginDate := StartOfTheWeek(StartOfTheMonth(vCurrentDate));
  vEndDate := EndOfTheWeek(EndOfTheMonth(vCurrentDate));
  vIteratorDate := vBeginDate;
  vBtnId := FButtonsMap.Items['calendar_date'].Id;
  vAcceptBtnId := FButtonsMap.Items[AAcceptBtn].Id;
  vCancelBtnId := -1;
  if ACancelBtn <> '' then
    vCancelBtnId := FButtonsMap.Items[ACancelBtn].Id;
  vActionId := FActionsMap.Items[ASelectDateAction];

  vData := Format('%d %d %s %s %d %d %s', [vBtnId, vActionId, '%s', DateToStr(AMinDate), vAcceptBtnId, vCancelBtnId, AData]);

  AKeyboard := TTelegramInlineKeyboardMarkup.Create;
  AKeyboard.AddButton('<', Format(vData, [DateToStr(IncMonth(vCurrentDate, -1))]), 0);
  AKeyboard.AddButton(FormatDateTime('mmmm yyyy', vCurrentDate), '-1', 0);
  AKeyboard.AddButton('>', Format(vData, [DateToStr(IncMonth(vCurrentDate, +1))]), 0);
  while vIteratorDate < vEndDate do
  begin
    if (MonthOf(vIteratorDate) <> MonthOf(vCurrentDate)) or (vIteratorDate < vMinDate) then
      AKeyboard.AddButton(' ', '-1', WeeksBetween(vIteratorDate, vBeginDate) + 1)
    else
      AKeyboard.AddButton(IntToStr(DayOfTheMonth(vIteratorDate)), Format(vData, [DateToStr(vIteratorDate)]), WeeksBetween(vIteratorDate, vBeginDate) + 1);
    vIteratorDate := vIteratorDate + 1;
  end;
  vData := DateToStr(vCurrentDate);
  if AData <> '' then
    vData := vData + ' ' + AData;

  AppendKeyboard(AKeyboard, AAcceptBtn, vData, DateToStr(vCurrentDate) + ' Подтвердить');
  if Assigned(ACancelData) then
    AppendKeyboard(AKeyboard, ACancelBtn, ACancelData, 'Назад')
  else
    AppendKeyboard(AKeyboard, ACancelBtn, AData, 'Назад');
end;

procedure TTelegramBotEx.SendCalendar(const AMessage: TTelegramMessage; const ACurrentDate, AMinDate: TDateTime; const ATelegramId, ASelectDateAction, AData, AAcceptBtn: string;
  const ACancelBtn: string = ''; const  APhoto: string = '');
var
  vCaption: string;
  vKeyboard: TTelegramInlineKeyboardMarkup;
begin
  BuildCalendarKeyboard(ATelegramId, ACurrentDate, AMinDate, ASelectDateAction,
    AData, AAcceptBtn, ACancelBtn, vCaption, vKeyboard);
  try
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
  finally
    FreeAndNil(vKeyboard);
  end;
end;

function TTelegramBotEx.SendCalendarResulted(const ATelegramId: string;
  const ACurrentDate, AMinDate: TDateTime; const ACancelButton: string = '';
  const ACancelData: TCallbackData = nil): TTelegramMessage;
var
  vCaption: string;
  vKeyboard: TTelegramInlineKeyboardMarkup;
begin
  BuildCalendarKeyboard(ATelegramId, ACurrentDate, AMinDate, 'FlowCalendarSelect',
    '', 'flow_accept_date', ACancelButton, vCaption, vKeyboard, ACancelData);
  try
    Result := SendMessageResulted(ATelegramId, vCaption, vKeyboard);
  finally
    FreeAndNil(vKeyboard);
  end;
end;

procedure TTelegramBotEx.SendConfirmation(const AMessage: TTelegramMessage; const ATelegramId, AText, AAction: string; const AData: TCallbackData; const APhoto: string = ''; const ADocument: string = '');
var
  vActionId: Integer;
  vKeyboard: TTelegramInlineKeyboardMarkup;
  vDataStr: string;
begin
  try
    if Assigned(AData) then
    begin
      AData.Serialize;
      vDataStr := AData.ToString;
    end;
  finally
    AData.Free;
  end;
  if Assigned(AMessage) then
    DeleteMessage(AMessage);
  Assert(FActionsMap.TryGetValue(AAction, vActionId), 'Action <'+AAction+'> not found');
  vKeyboard := TTelegramInlineKeyboardMarkup.Create;
  AppendKeyboard(vKeyboard, 'confirm', IntToStr(vActionId) + ' ' + IntToStr(Integer(tmrYes)) + ' ' + vDataStr);
  AppendKeyboard(vKeyboard, 'reject', IntToStr(vActionId) + ' ' + IntToStr(Integer(tmrNo)) + ' ' + vDataStr);
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

procedure TTelegramBotEx.SendMenu<T>(const AMessage: TTelegramMessage;
  const AMenuName, ARecipient: string; const AExtraData: T; const ACaption, APhoto: string);
begin
  try
    AExtraData.Serialize;
    SendMenu(AMessage, AMenuName, ARecipient, TCallbackData(AExtraData), ACaption, APhoto);
  finally
    AExtraData.Free;
  end;
end;

procedure TTelegramBotEx.Replace(const AMessage: TTelegramMessage; const AChatId, AText: string;
  const AReplyMarkup: TTelegramInlineKeyboardMarkup);
begin
  if Assigned(AMessage) then
  begin
    if AMessage.Photo <> '' then
    begin
      DeleteMessage(AMessage);
      SendMessage(AChatId, AText, AReplyMarkup);
    end
    else
      EditMessageText(AMessage, AText, AReplyMarkup);
  end
  else
    SendMessage(AChatId, AText, AReplyMarkup);
end;

{ TTelegramModule }

constructor TTelegramModule.Create(const ABot: TTelegramBotEx);
begin
  inherited Create;
  FBot := ABot;
end;

procedure TTelegramModule.Register;
begin
end;

procedure TTelegramModule.Initialize;
begin
end;

function TTelegramModule.OnMessage(const AMessage: TTelegramMessage): Boolean;
begin
  Result := False;
end;

function TTelegramModule.OnCallback(const AAction: string; const AParams: TCallbackData;
  const ACallback: TTelegramCallbackQuery): Boolean;
begin
  Result := False;
end;

function TTelegramModule.OnAction(const AName: string; const AParams: TCallbackData;
  const ACallback: TTelegramCallbackQuery): Boolean;
begin
  Result := False;
end;

function TTelegramModule.OnCommand(const ACommand: string; const AMessage: TTelegramMessage): Boolean;
begin
  Result := False;
end;

function TTelegramModule.CanHandleUser(const ATelegramId: string): Boolean;
begin
  Result := True;
end;

function TTelegramModule.CanShowButton(const AButton, ATelegramId, AData: string): Boolean;
begin
  Result := True;
end;

procedure TTelegramModule.RegisterButton(const AName, ACaption: string; const AURL: string = '');
begin
  FBot.RegisterButton(AName, ACaption, AURL);
end;

procedure TTelegramModule.RegisterButton<T>(const AName, ACaption: string; const AHandler: TProc<T>; const AACL: TFunc<T, Boolean>);
begin
  FBot.RegisterButton<T>(AName, ACaption, AHandler, AACL);
end;

procedure TTelegramModule.RegisterUrlButton<T>(const AName, ACaption, AURL: string; const AACL: TFunc<T, Boolean>);
begin
  FBot.RegisterUrlButton<T>(AName, ACaption, AURL, AACL);
end;

procedure TTelegramModule.RegisterAction(const AName: string);
begin
  FBot.RegisterAction(AName);
end;

procedure TTelegramModule.RegisterAction<T>(const AName: string; const AHandler: TProc<T, TTgModalResult>);
begin
  FBot.RegisterAction<T>(AName, AHandler);
end;

procedure TTelegramModule.RegisterCommand(const ACommand, ADescription: string);
begin
  FBot.RegisterCommand(ACommand, ADescription);
end;

procedure TTelegramModule.RegisterMenu(const AMenuName, ACaption: string);
begin
  FBot.RegisterMenu(AMenuName, ACaption);
end;

procedure TTelegramModule.RegisterMenu(const AMenuName, ACaption: string; const AButtons: TButtons; const ABackButton: string = '');
begin
  FBot.RegisterMenu(AMenuName, ACaption, AButtons, ABackButton);
end;

procedure TTelegramModule.RegisterMenu(const AMenuName: string; const AConstructProcedure: TConstructSimpleMenuProcedure; const AButtonCaption: string = '');
begin
  FBot.RegisterMenu(AMenuName, AConstructProcedure, AButtonCaption);
end;

procedure TTelegramModule.RegisterMenu<T>(const AMenuName, ACaption: string; const AACL: TFunc<T, Boolean>);
begin
  FBot.RegisterMenu<T>(AMenuName, ACaption, AACL);
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

{ TTypedButtonHandler<T> }

constructor TTypedButtonHandler<T>.Create(const AHandler: TProc<T>; const AACL: TFunc<T, Boolean>);
begin
  FHandler := AHandler;
  FACL := AACL;
end;

function TTypedButtonHandler<T>.CreateData: TCallbackData;
begin
  Result := T.Create;
end;

procedure TTypedButtonHandler<T>.Execute(const AData: TCallbackData);
begin
  if Assigned(FHandler) then
    FHandler(T(AData));
end;

function TTypedButtonHandler<T>.CheckACL(const AData: TCallbackData): Boolean;
begin
  if Assigned(FACL) then
    Result := FACL(T(AData))
  else
    Result := True;
end;

function TTypedButtonHandler<T>.HasHandler: Boolean;
begin
  Result := Assigned(FHandler);
end;

{ TTypedActionHandler<T> }

constructor TTypedActionHandler<T>.Create(const AHandler: TProc<T, TTgModalResult>);
begin
  FHandler := AHandler;
end;

procedure TTypedActionHandler<T>.Execute(const AParams: TCallbackData; const ACallback: TTelegramCallbackQuery);
var
  vData: T;
  vShifted: string;
  vModalResult: TTgModalResult;
  I: Integer;
begin
  vModalResult := TTgModalResult(AParams.GetInteger(2));
  vShifted := '0';
  for I := 3 to AParams.Count - 1 do
    vShifted := vShifted + ' ' + AParams.GetString(I);
  vData := T.Create;
  try
    vData.LoadData(vShifted);
    vData.FCallback := ACallback;
    vData.Parse;
    FHandler(vData, vModalResult);
  finally
    FreeAndNil(vData);
  end;
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

function TCallbackData.GetCallback: TTelegramCallbackQuery;
begin
  if not Assigned(FCallback) then
    raise Exception.Create('Callback недоступен в контексте ACL — используй ParseForACL');
  Result := FCallback;
end;

procedure TCallbackData.Serialize;
begin
end;

procedure TCallbackData.ParseFields;
begin
end;

procedure TCallbackData.Parse;
begin
  ParseFields;
end;

procedure TCallbackData.ParseForACL(const ATelegramId: string);
begin
  ParseFields;
end;

procedure TCallbackData.LoadData(const AData: string);
begin
  FParams.DelimitedText := AData;
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

initialization
  TTelegramBotEx.FModuleClasses := TList<TTelegramModuleClass>.Create;

finalization
  FreeAndNil(TTelegramBotEx.FModuleClasses);

end.
