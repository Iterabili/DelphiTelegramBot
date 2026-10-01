unit uTelegramBotEx;

interface

uses
  uTelegramTypes, uTelegramBot, Generics.Collections, Classes, SysUtils;

type
  TCallbackData = class;  // Forward declaration
  TTelegramBotEx = class;  // Forward declaration
  TFlowContext = class;    // Forward declaration

  EFlowCancelled = class(EAbort);
  TFlowPendingType = (fptNone, fptMessage, fptCallback, fptMessageOrCallback, fptAsyncSend);
  TFlowProc = reference to procedure(const ACtx: TFlowContext);

  TFlowInputKind = (fikText, fikPhoto, fikDocument, fikContact, fikOther);
  TFlowInputKinds = set of TFlowInputKind;

  TFlowInput = record
    Kind: TFlowInputKind;
    Text: string;
    Photo: string;
    Document: string;
    Phone: string;
    ContactOwner: string;
    MessageId: Integer;
  end;

  TFlowInputValidator = reference to function(const AInput: TFlowInput): string;

const
  cFlowAnyInput = [Low(TFlowInputKind)..High(TFlowInputKind)];

type

  TConstructSimpleMenuProcedure = reference to procedure (const ATelegramId: string; const AData: TCallbackData;
    out ACaption: string; out AKeyboard: TTelegramInlineKeyboardMarkup);
  TConstructListMenuProcedure = reference to procedure (const ATelegramId: string; const AData: TCallbackData;
    const APage: Integer; out ACaption: string; out AKeyboard: TTelegramInlineKeyboardMarkup);

  TButtonsRow = array of string;
  TButtons = array of TButtonsRow;

  TTgModalResult = (tmrYes, tmrNo);

  TActionData<T: class> = class
  private
    FCallback: TTelegramCallbackQuery;
    FModalResult: TTgModalResult;
    FDate: TDateTime;
    FParams: T;
  public
    constructor Create(const AParams: T);
    destructor Destroy; override;
    property Callback: TTelegramCallbackQuery read FCallback;
    property ModalResult: TTgModalResult read FModalResult;
    property Date: TDateTime read FDate;
    property Params: T read FParams;
  end;

  TTelegramModuleClass = class of TTelegramModule;

  TTelegramModule = class
  private
    FBot: TTelegramBotEx;
  protected
    property Bot: TTelegramBotEx read FBot;
    procedure RegisterButton(const AName, ACaption: string; const AURL: string = ''); overload;
    procedure RegisterButton<T: TCallbackData, constructor>(const AName, ACaption: string; const AHandler: TProc<T>; const AACL: TFunc<T, Boolean> = nil); overload;
    procedure RegisterUrlButton<T: TCallbackData, constructor>(const AName, ACaption, AURL: string; const AACL: TFunc<T, Boolean>);
    procedure RegisterAction<T: TCallbackData, constructor>(const AName: string; const AHandler: TProc<TActionData<T>>);
    procedure RegisterCommand(const ACommand, ADescription: string); overload;
    procedure RegisterCommand(const ACommand, ADescription: string; const AHandler: TFunc<TTelegramMessage, Boolean>); overload;
    procedure RegisterMessageHandler(const AHandler: TOnTelegramMessage; const APriority: Integer = 100);
    procedure RegisterMenuButton(const AMenuName, ACaption: string); overload;
    procedure RegisterMenuButton<T: TCallbackData, constructor>(const AMenuName, ACaption: string; const AACL: TFunc<T, Boolean>); overload;
    procedure RegisterMenuButton<T: TCallbackData, constructor>(const AMenuName, ACaption: string; const AACL: TFunc<T, Boolean>; const AConstructProcedure: TConstructSimpleMenuProcedure); overload;
    procedure SetMenuContent(const AMenuName, ACaption: string; const AButtons: TButtons; const ABackButton: string = ''); overload;
    procedure SetMenuContent(const AMenuName: string; const AConstructProcedure: TConstructSimpleMenuProcedure; const AButtonCaption: string = ''); overload;
    procedure SetListMenuContent(const AMenuName: string; const AConstructProcedure: TConstructListMenuProcedure; const AButtonCaption: string = '');
    procedure RegisterListMenuButton<T: TCallbackData, constructor>(const AMenuName, ACaption: string; const AACL: TFunc<T, Boolean>; const AConstructProcedure: TConstructListMenuProcedure);
  public
    constructor Create(const ABot: TTelegramBotEx); virtual;
    procedure Register; virtual;
    procedure Initialize; virtual;
    function OnMessage(const AMessage: TTelegramMessage): Boolean; virtual;
    function OnCallback(const AAction: string; const AParams: TCallbackData;
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

  TMessageHandlerEntry = record
    Priority: Integer;
    Handler: TOnTelegramMessage;
  end;

  TBotCommand = class
  public
    Command: string;
    Description: string;
    Handler: TFunc<TTelegramMessage, Boolean>;

    constructor Create(const ACommand, ADescription: string; const AHandler: TFunc<TTelegramMessage, Boolean> = nil);
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
    procedure Execute(const AParamsData: string; const ACallback: TTelegramCallbackQuery;
      const AModalResult: TTgModalResult; const ADate: TDateTime); virtual; abstract;
  end;

  TTypedActionHandler<T: TCallbackData, constructor> = class(TTypedActionHandler)
  private
    FHandler: TProc<TActionData<T>>;
  public
    constructor Create(const AHandler: TProc<TActionData<T>>);
    procedure Execute(const AParamsData: string; const ACallback: TTelegramCallbackQuery;
      const AModalResult: TTgModalResult; const ADate: TDateTime); override;
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
    FPendingSendToken: Int64;
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
    function SendPromptResulted(const AText: string; const AReplyMarkup: TTelegramKeyboardMarkup): TTelegramMessage;
    function SendCalendarPromptResulted(const ACurrentDate, AMinDate: TDateTime; const ACancelButton: string;
      const ACancelData: TCallbackData): TTelegramMessage;
    function AwaitValidated(const APrompt: string; const AKinds: TFlowInputKinds; const AValidator: TFlowInputValidator;
      const ACancelButton: string; ACancelData: TCallbackData; const ARequestContact: Boolean): TFlowInput;
  public
    constructor Create(const ABot: TTelegramBotEx; const AChatId: string;
      const ASchedulerFiber: Pointer; const AProc: TFlowProc);
    destructor Destroy; override;
    property ChatId: string read FChatId;
    property CancelButton: string write FCancelButton;
    property CancelButtonData: TCallbackData write SetCancelButtonData;
    // Валиден только сразу после Await* (до следующего Await) — сообщение освобождается в ProceedMessage
    property LastMessage: TTelegramMessage read FPendingMessage;
    function Await(const APrompt: string; const AKinds: TFlowInputKinds; const ACancelButton: string = '';
      ACancelData: TCallbackData = nil; const ARequestContact: Boolean = False): TFlowInput;
    function AwaitInteger(const APrompt: string; const ACancelButton: string = ''; ACancelData: TCallbackData = nil): Integer;
    function AwaitPositiveInteger(const APrompt: string; const ACancelButton: string = ''; ACancelData: TCallbackData = nil): Integer;
    function AwaitUsername(const APrompt: string; const ACancelButton: string = ''; ACancelData: TCallbackData = nil): string;
    procedure AwaitTimeRange(const APrompt: string; out AFrom, ATo: TDateTime; const ACancelButton: string = ''; ACancelData: TCallbackData = nil);
    function AwaitButton(const APrompt: string; const AActions, ACaptions: array of string; const ACancelButton: string = ''; ACancelData: TCallbackData = nil): string;
    function AwaitStringOrSkip(const APrompt, ASkipButton, ASkipCaption: string): string;
    function AwaitDate(const ACurrentDate, AMinDate: TDateTime; const ACancelButton: string = ''; ACancelData: TCallbackData = nil): TDateTime;
    procedure Send(const AText: string);
  end;

  TFlowState = class
  public
    FiberHandle: Pointer;
    Context: TFlowContext;
    destructor Destroy; override;
  end;

  TPendingSendResult = record
    ChatId: string;
    Token: Int64;
    Message: TTelegramMessage;
  end;

  TSimpleMenu = class
    Id: Integer;
    Caption: string;
    BackButton: string;
    Buttons: TObjectList<TList<TSimpleButton>>;
    ConstructProcedure: TConstructSimpleMenuProcedure;
    ListConstructProcedure: TConstructListMenuProcedure;

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
    FMessageHandlers: TList<TMessageHandlerEntry>;
    FTypedHandlers: TObjectDictionary<string, TTypedButtonHandler>;
    FTypedActions: TObjectDictionary<Integer, TTypedActionHandler>;
    FSchedulerFiber: Pointer;
    FActiveFlows: TObjectDictionary<string, TFlowState>;
    FPendingSendResults: TThreadList<TPendingSendResult>;
    FNextSendToken: Int64;
    function InternalExecuteCalbackAction(const ACallback: TTelegramCallbackQuery): Boolean;
    function IsCommandMessage(const AMessage: TTelegramMessage): Boolean;
    function TryResumeFlowWithMessage(const AMessage: TTelegramMessage): Boolean;
    function HandleRegisteredMessages(const AMessage: TTelegramMessage): Boolean;
    function DispatchCommandMessage(const AMessage: TTelegramMessage): Boolean;
    function TryResumeFlowWithCallback(const ACallback: TTelegramCallbackQuery): Boolean;
    procedure SilentTerminateFlow(const AChatId: string; const AState: TFlowState);
    function NextSendToken: Int64;
    procedure QueueSendResult(const AChatId: string; const AToken: Int64; const AMessage: TTelegramMessage);
    procedure ProcessPendingSendResults;
    function RegisterActionId(const AName: string): Integer;
    procedure InternalSendMenu(const AMessage: TTelegramMessage; const AMenuName, ARecipient: string;
      const AExtraData: TCallbackData; const ACaption, APhoto: string; const APhotoStream: TStream;
      const APage: Integer);
    function ExecuteAction(const AActionId: Integer; const AParamsData: string; const ACallback: TTelegramCallbackQuery;
      const AModalResult: TTgModalResult; const ADate: TDateTime): Boolean;
    function AppendKeyboard(const AKeyboard: TTelegramInlineKeyboardMarkup; const AButton: string; const AData: string; const ACaption: string = ''; const ARow: Integer = -1): Integer; overload;
  protected
    FSimpleButtons: TObjectDictionary<Integer, TSimpleButton>;
    FButtonsMap: TDictionary<string, TSimpleButton>;
    FPersistedButtonIds: TDictionary<string, Integer>;
    FNextButtonId: Integer;
    FButtonIdsChanged: Boolean;
    FActionsMap: TDictionary<string, Integer>;
    FCommands: TObjectList<TBotCommand>;
    procedure LoadButtonIds;
    procedure SaveButtonIds;
    function CheckButtonAdd(const AButton, ATelegramId, AData: string): Boolean; virtual;
    procedure DoBeforeDispatchUpdate; override;
    function DoOnMessage(const AMessage: TTelegramMessage): Boolean; override;
    function DoOnCallbackQuery(const ACallbackQuery: TTelegramCallbackQuery): Boolean; override;

    procedure SendCommandsToTelegram;

    procedure DoInitialize; virtual;

    function HandleModulesMessage(const AMessage: TTelegramMessage): Boolean;
    function HandleModulesCallback(const ACallback: TTelegramCallbackQuery): Boolean;
  public
    constructor Create(const AToken: string); override;
    destructor Destroy; override;

    procedure Initialize;

    class procedure RegisterModule(const AClass: TTelegramModuleClass);
    function FindModule(const AClass: TTelegramModuleClass): TTelegramModule;
    function DispatchCommand(const ACommand: string; const AMessage: TTelegramMessage): Boolean;
    procedure RegisterMessageHandler(const AHandler: TOnTelegramMessage; const APriority: Integer = 100);

    procedure RegisterDoOnMessage(const AFunction: TOnTelegramMessage);
    procedure RegisterDoOnCallbackQuery(const AFunction: TOnTelegramCallbackQuery);

    procedure Poll; override;
    procedure StartFlow(const AChatId: string; const AProc: TFlowProc);
    procedure CancelFlow(const AChatId: string);
    procedure DoFlowError(const AChatId: string; const AException: Exception); virtual;
    procedure DoUnrecognizedCommand(const AMessage: TTelegramMessage); virtual;
    procedure InitSchedulerFiber;
    procedure SendCalendarResulted(const ATelegramId: string;
      const ACurrentDate, AMinDate: TDateTime; const ACancelButton: string; const ACancelData: TCallbackData;
      const AOnSent: TProc<TTelegramMessage>);
    procedure RegisterAction<T: TCallbackData, constructor>(const AName: string; const AHandler: TProc<TActionData<T>>);
    procedure RegisterButton(const AName: string; const ACaption: string; const AURL: string = ''); overload;
    procedure RegisterButton<T: TCallbackData, constructor>(const AName, ACaption: string; const AHandler: TProc<T>; const AACL: TFunc<T, Boolean> = nil); overload;
    procedure RegisterUrlButton<T: TCallbackData, constructor>(const AName, ACaption, AURL: string; const AACL: TFunc<T, Boolean>);
    procedure RegisterCommand(const ACommand, ADescription: string); overload;
    procedure RegisterCommand(const ACommand, ADescription: string; const AHandler: TFunc<TTelegramMessage, Boolean>); overload;

    procedure RegisterMenuButton(const AMenuName, ACaption: string); overload;
    procedure RegisterMenuButton<T: TCallbackData, constructor>(const AMenuName, ACaption: string; const AACL: TFunc<T, Boolean>); overload;
    procedure RegisterMenuButton<T: TCallbackData, constructor>(const AMenuName, ACaption: string; const AACL: TFunc<T, Boolean>; const AConstructProcedure: TConstructSimpleMenuProcedure); overload;
    procedure SetMenuContent(const AMenuName, ACaption: string; const AButtons: TButtons; const ABackButton: string = ''); overload;
    procedure SetMenuContent(const AMenuName: string; const AConstructProcedure: TConstructSimpleMenuProcedure; const AButtonCaption: string = ''); overload;
    procedure SetListMenuContent(const AMenuName: string; const AConstructProcedure: TConstructListMenuProcedure; const AButtonCaption: string = '');
    procedure RegisterListMenuButton<T: TCallbackData, constructor>(const AMenuName, ACaption: string; const AACL: TFunc<T, Boolean>; const AConstructProcedure: TConstructListMenuProcedure);
    function PageBounds(const ACount, APage, APageSize: Integer; out AActualPage, AFirst, ALast: Integer): Integer;
    procedure AppendPagination(const AKeyboard: TTelegramInlineKeyboardMarkup; const AMenuName: string;
      const AData: TCallbackData; const APage, APageCount: Integer; const ACounterButton: string = '');
    procedure SendListMenu(const AMessage: TTelegramMessage; const AMenuName, ARecipient: string;
      const AData: TCallbackData; const APage: Integer);
    function IsButtonVisible(const AButton, ATelegramId: string; const AData: TCallbackData): Boolean;

    procedure BuildCalendarKeyboard(const ATelegramId: string;
      const ACurrentDate, AMinDate: TDateTime; const ASelectDateAction, AData,
      AAcceptBtn, ACancelBtn: string; out ACaption: string;
      out AKeyboard: TTelegramInlineKeyboardMarkup;
      const ACancelData: TCallbackData = nil);
    procedure SendCalendar(const AMessage: TTelegramMessage; const ACurrentDate, AMinDate: TDateTime; const ATelegramId, ASelectDateAction, AData, AAcceptBtn: string;
      const ACancelBtn: string = '');


    function AppendKeyboard(const AKeyboard: TTelegramInlineKeyboardMarkup; const AButton: string; const AData: TCallbackData = nil; const ACaption: string = ''; const ARow: Integer = -1; const AStyle: TTelegramButtonStyle = tbsNone): Integer; overload;
    function AppendMenuKeyboard(const AKeyboard: TTelegramInlineKeyboardMarkup; const AButton, ATelegramId: string; const AData: TCallbackData; const ACaption: string = ''; const ARow: Integer = -1; const AStyle: TTelegramButtonStyle = tbsNone): Boolean; overload;
    function AppendMenuKeyboard(const AKeyboard: TTelegramInlineKeyboardMarkup; const AButton, ATelegramId, AData: string; const ACaption: string = ''; const ARow: Integer = -1; const AStyle: TTelegramButtonStyle = tbsNone): Boolean; overload;
    //todo: add captions
    procedure SendConfirmation(const AMessage: TTelegramMessage; const ATelegramId, AText, AAction: string; const AOwnedData: TCallbackData; const APhoto: string = ''; const ADocument: string = ''); overload;
    procedure SendConfirmationResulted(const AMessage: TTelegramMessage; const ATelegramId, AText, AAction: string;
      const AOwnedData: TCallbackData; const AOnSent: TProc<TTelegramMessage>);

    procedure SendMenu(const AMessage: TTelegramMessage; const AMenuName: string; const ARecipient: string = '';
      const AExtraData: TCallbackData = nil; const ACaption: string = ''; const APhoto: string = ''); overload;
    procedure SendMenu<T: TCallbackData, constructor>(const AMessage: TTelegramMessage; const AMenuName, ARecipient: string; const AOwnedExtraData: T; const ACaption: string = ''; const APhoto: string = ''); overload;
    procedure SendMenu(const AMessage: TTelegramMessage; const AMenuName, ARecipient: string;
      const AExtraData: TCallbackData; const ACaption: string; const APhotoStream: TStream); overload;
    procedure SendMenu<T: TCallbackData, constructor>(const AMessage: TTelegramMessage; const AMenuName, ARecipient: string;
      const AOwnedExtraData: T; const ACaption: string; const APhotoStream: TStream); overload;

    procedure Replace(const AMessage: TTelegramMessage; const AChatId, AText: string;
      const AReplyMarkup: TTelegramInlineKeyboardMarkup = nil);
  end;

function CreateDelimitedList(const ADelimitedText: string; const ADelimiter: Char = ';'): TStrings;
function NormalizeTimeString(const AText: string): string;

implementation

uses
  Math, DateUtils, StrUtils, Generics.Defaults, Windows;

const
  cButtonIdsFileName = 'telegram_button_ids.txt';
  cActionIdPrefix = 'action:';
  cMenuPhotoFileName = 'photo.png';
  cListPageButton = 'list_page';

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

function TFlowContext.SendPromptResulted(const AText: string; const AReplyMarkup: TTelegramKeyboardMarkup): TTelegramMessage;
var
  vToken: Int64;
begin
  vToken := FBot.NextSendToken;
  FPendingSendToken := vToken;
  FBot.SendMessageResulted(FChatId, AText, AReplyMarkup,
    procedure(AMsg: TTelegramMessage)
    begin
      FBot.QueueSendResult(FChatId, vToken, AMsg);
    end);
  FPendingType := fptAsyncSend;
  SwitchToScheduler;
  Result := FPendingMessage;
end;

function TFlowContext.SendCalendarPromptResulted(const ACurrentDate, AMinDate: TDateTime; const ACancelButton: string;
  const ACancelData: TCallbackData): TTelegramMessage;
var
  vToken: Int64;
begin
  vToken := FBot.NextSendToken;
  FPendingSendToken := vToken;
  FBot.SendCalendarResulted(FChatId, ACurrentDate, AMinDate, ACancelButton, ACancelData,
    procedure(AMsg: TTelegramMessage)
    begin
      FBot.QueueSendResult(FChatId, vToken, AMsg);
    end);
  FPendingType := fptAsyncSend;
  SwitchToScheduler;
  Result := FPendingMessage;
end;

procedure TFlowContext.Send(const AText: string);
begin
  FBot.SendMessage(FChatId, AText);
end;

function ExtractDigits(const AText: string): string;
var
  I: Integer;
begin
  Result := '';
  for I := 1 to Length(AText) do
    if (AText[I] >= '0') and (AText[I] <= '9') then
      Result := Result + AText[I];
end;

function ReadFlowInput(const AMessage: TTelegramMessage): TFlowInput;
begin
  Result.Kind := fikOther;
  Result.Text := '';
  Result.Photo := '';
  Result.Document := '';
  Result.Phone := '';
  Result.ContactOwner := '';
  Result.MessageId := 0;
  if not Assigned(AMessage) then
    Exit;
  Result.MessageId := AMessage.MessageId;
  Result.Text := Trim(AMessage.Text);
  Result.Photo := AMessage.Photo;
  Result.Document := AMessage.Document;
  if Assigned(AMessage.Contact) then
  begin
    Result.Kind := fikContact;
    Result.Phone := ExtractDigits(AMessage.Contact.Phone);
    Result.ContactOwner := AMessage.Contact.UserId;
  end
  else if Result.Photo <> '' then
    Result.Kind := fikPhoto
  else if Result.Document <> '' then
    Result.Kind := fikDocument
  else if Result.Text <> '' then
    Result.Kind := fikText;
end;

function FlowInputHint(const AKinds: TFlowInputKinds; const ARequestContact: Boolean): string;
const
  cKindNames: array[TFlowInputKind] of string = ('текст', 'фото', 'файл', 'контакт', 'другое сообщение');
var
  vKind: TFlowInputKind;
begin
  if ARequestContact and (AKinds = [fikContact]) then
    Exit('Нажмите кнопку «Отправить контакт» под полем ввода');
  Result := '';
  for vKind := Low(TFlowInputKind) to High(TFlowInputKind) do
    if vKind in AKinds then
    begin
      if Result <> '' then
        Result := Result + ' или ';
      Result := Result + cKindNames[vKind];
    end;
  Result := 'Ожидается ' + Result;
end;

function TFlowContext.AwaitValidated(const APrompt: string; const AKinds: TFlowInputKinds;
  const AValidator: TFlowInputValidator; const ACancelButton: string; ACancelData: TCallbackData;
  const ARequestContact: Boolean): TFlowInput;
var
  vKeyboard: TTelegramInlineKeyboardMarkup;
  vKeyboardReq: TTelegramReplyKeyboardMarkup;
  vEmptyKeyboard: TTelegramReplyKeyboardRemove;
  vMsg, vClearMsg: TTelegramMessage;
  vError: string;
begin
  vMsg := nil;
  vKeyboard := BuildCancelKeyboard(GetEffectiveCancelButton(ACancelButton), GetEffectiveCancelData(ACancelData));
  FreeAndNil(ACancelData);
  try
    if APrompt <> '' then
      if ARequestContact then
      begin
        vKeyboardReq := TTelegramReplyKeyboardMarkup.Create(
          [[TTelegramReplyKeyboardButton.Create('Отправить контакт').RequestContact]]);
        try
          vMsg := SendPromptResulted(APrompt, vKeyboardReq);
        finally
          FreeAndNil(vKeyboardReq);
        end;
        if Assigned(vMsg) then
          FBot.EditMessageReplyMarkup(vMsg, vKeyboard);
      end
      else
        vMsg := SendPromptResulted(APrompt, vKeyboard);
  finally
    FreeAndNil(vKeyboard);
  end;
  try
    while True do
    begin
      FPendingType := fptMessage;
      FPendingMessage := nil;
      SwitchToScheduler;
      Result := ReadFlowInput(FPendingMessage);
      if not (Result.Kind in AKinds) then
      begin
        FBot.SendMessage(FChatId, FlowInputHint(AKinds, ARequestContact));
        Continue;
      end;
      if Assigned(AValidator) then
      begin
        vError := AValidator(Result);
        if vError <> '' then
        begin
          FBot.SendMessage(FChatId, vError);
          Continue;
        end;
      end;
      Break;
    end;
    if ARequestContact then
    begin
      vEmptyKeyboard := TTelegramReplyKeyboardRemove.Create;
      try
        vClearMsg := SendPromptResulted('clear', vEmptyKeyboard);
        FBot.DeleteMessage(vClearMsg);
        FreeAndNil(vClearMsg);
      finally
        FreeAndNil(vEmptyKeyboard);
      end;
    end;
  finally
    if Assigned(vMsg) then
      FBot.DeleteKeyboard(vMsg);
    FreeAndNil(vMsg);
  end;
end;

function TFlowContext.Await(const APrompt: string; const AKinds: TFlowInputKinds; const ACancelButton: string = '';
  ACancelData: TCallbackData = nil; const ARequestContact: Boolean = False): TFlowInput;
begin
  Result := AwaitValidated(APrompt, AKinds, nil, ACancelButton, ACancelData, ARequestContact);
end;

function TFlowContext.AwaitInteger(const APrompt: string; const ACancelButton: string = ''; ACancelData: TCallbackData = nil): Integer;
begin
  Result := StrToInt(AwaitValidated(APrompt, [fikText],
    function(const AInput: TFlowInput): string
    var
      vValue: Integer;
    begin
      Result := '';
      if not TryStrToInt(AInput.Text, vValue) then
        Result := 'Введите целое число';
    end, ACancelButton, ACancelData, False).Text);
end;

function TFlowContext.AwaitPositiveInteger(const APrompt: string; const ACancelButton: string = ''; ACancelData: TCallbackData = nil): Integer;
begin
  Result := StrToInt(AwaitValidated(APrompt, [fikText],
    function(const AInput: TFlowInput): string
    var
      vValue: Integer;
    begin
      Result := '';
      if not TryStrToInt(AInput.Text, vValue) or (vValue <= 0) then
        Result := 'Введите целое число больше нуля';
    end, ACancelButton, ACancelData, False).Text);
end;

function TFlowContext.AwaitUsername(const APrompt: string; const ACancelButton: string = ''; ACancelData: TCallbackData = nil): string;
var
  vText: string;
begin
  vText := AwaitValidated(APrompt, [fikText],
    function(const AInput: TFlowInput): string
    begin
      Result := '';
      if (Length(AInput.Text) < 2) or (AInput.Text[1] <> '@') then
        Result := 'Введите username, начиная с @';
    end, ACancelButton, ACancelData, False).Text;
  Result := Copy(vText, 2, Length(vText) - 1);
end;

function TryParseTimeRange(const AText: string; out AFrom, ATo: TDateTime): Boolean;
var
  vTimeRange: TStrings;
begin
  vTimeRange := CreateDelimitedList(AText, '-');
  try
    Result := (vTimeRange.Count = 2) and
      TryStrToTime(NormalizeTimeString(vTimeRange[0]), AFrom) and
      TryStrToTime(NormalizeTimeString(vTimeRange[1]), ATo);
  finally
    FreeAndNil(vTimeRange);
  end;
end;

procedure TFlowContext.AwaitTimeRange(const APrompt: string; out AFrom, ATo: TDateTime; const ACancelButton: string = ''; ACancelData: TCallbackData = nil);
var
  vText: string;
begin
  vText := AwaitValidated(APrompt, [fikText],
    function(const AInput: TFlowInput): string
    var
      vFrom, vTo: TDateTime;
    begin
      Result := '';
      if not TryParseTimeRange(AInput.Text, vFrom, vTo) then
        Result := 'Введите время в формате 17-19 или 15:30-18:30';
    end, ACancelButton, ACancelData, False).Text;
  TryParseTimeRange(vText, AFrom, ATo);
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
  vMsg := SendPromptResulted(APrompt, vKeyboard);
  FreeAndNil(vKeyboard);
  vSavedCancelButton := FCancelButton;
  FCancelButton := vEffectiveCancel;
  try
    if Assigned(vMsg) then
      FAwaiterMessageId := vMsg.MessageId
    else
      FAwaiterMessageId := -1;
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

function TFlowContext.AwaitStringOrSkip(const APrompt, ASkipButton, ASkipCaption: string): string;
var
  vKeyboard: TTelegramInlineKeyboardMarkup;
  vMsg: TTelegramMessage;
  vData: TCallbackData;
begin
  vKeyboard := TTelegramInlineKeyboardMarkup.Create;
  vData := TCallbackData.Create;
  try
    FBot.AppendKeyboard(vKeyboard, ASkipButton, vData, ASkipCaption);
  finally
    FreeAndNil(vData);
  end;
  vMsg := SendPromptResulted(APrompt, vKeyboard);
  FreeAndNil(vKeyboard);
  try
    if Assigned(vMsg) then
      FAwaiterMessageId := vMsg.MessageId
    else
      FAwaiterMessageId := -1;
    FPendingAction := '';
    while True do
    begin
      FPendingType := fptMessageOrCallback;
      SwitchToScheduler;
      if FPendingAction = ASkipButton then
      begin
        Result := '';
        Break;
      end
      else if Assigned(FPendingMessage) and (Trim(FPendingMessage.Text) <> '') then
      begin
        Result := Trim(FPendingMessage.Text);
        Break;
      end;
    end;
  finally
    FAwaiterMessageId := -1;
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
  vMsg := SendCalendarPromptResulted(ACurrentDate, AMinDate, vEffectiveCancel, GetEffectiveCancelData(ACancelData));
  FreeAndNil(ACancelData);
  vSavedCancelButton := FCancelButton;
  FCancelButton := vEffectiveCancel;
  try
    if Assigned(vMsg) then
      FAwaiterMessageId := vMsg.MessageId
    else
      FAwaiterMessageId := -1;
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

function TTelegramBotEx.IsCommandMessage(const AMessage: TTelegramMessage): Boolean;
var
  vText: string;
begin
  Result := False;
  if not Assigned(AMessage) then
    Exit;
  if (AMessage.Photo <> '') or (AMessage.Document <> '') or Assigned(AMessage.Contact) then
    Exit;
  vText := Trim(AMessage.Text);
  Result := (vText <> '') and (vText[1] = '/');
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

  if vState.Context.FPendingType = fptAsyncSend then
  begin
    ProcessPendingSendResults;
    if not FActiveFlows.TryGetValue(AMessage.From.Id, vState) then
      Exit;
  end;

  // Type mismatch: Flow ждёт кнопку, но пришёл текст → тихо завершаем, текст идёт дальше
  if vState.Context.FPendingType = fptCallback then
  begin
    SilentTerminateFlow(AMessage.From.Id, vState);
    Exit(False);
  end;

  if not (vState.Context.FPendingType in [fptMessage, fptMessageOrCallback]) then
    Exit;

  if IsCommandMessage(AMessage) then
  begin
    SilentTerminateFlow(AMessage.From.Id, vState);
    Exit(False);
  end;

  vState.Context.FPendingMessage := AMessage;
  vState.Context.FPendingAction := '';
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
begin
  Result := False;
  vChatId := '';
  if not FActiveFlows.TryGetValue(ACallback.From.Id, vState) then
    Exit;

  if vState.Context.FPendingType = fptAsyncSend then
  begin
    ProcessPendingSendResults;
    if not FActiveFlows.TryGetValue(ACallback.From.Id, vState) then
      Exit;
  end;

  vCallbackData := TCallbackData.Create(ACallback.Data);
  try
    if vCallbackData.Count < 1 then Exit;
    vBId := vCallbackData.GetInteger(0);
    if not FSimpleButtons.ContainsKey(vBId) then Exit;
    vButton := FSimpleButtons[vBId].Name;

    // Type mismatch: Flow ждёт текст, но пришла кнопка → тихо завершаем, кнопка идёт дальше
    if vState.Context.FPendingType = fptMessage then
    begin
      SilentTerminateFlow(ACallback.From.Id, vState);
      Exit(False);
    end;

    if not (vState.Context.FPendingType in [fptCallback, fptMessageOrCallback]) then Exit;

    // Навигация по календарю — не прерываем Fiber, идёт в обычный роутинг
    if (vButton = 'calendar_date') or (vButton = cListPageButton) then Exit;

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
    vState.Context.FPendingMessage := nil;
    if vButton = 'flow_accept_date' then
      vState.Context.FPendingDate := StrToDate(vCallbackData.GetString(1));
    vState.Context.FPendingType := fptNone;
    Result := True;
    vChatId := ACallback.From.Id;
    SwitchToFiber(vState.FiberHandle);
  finally
    FreeAndNil(vCallbackData);
  end;

  vCompleted := vState.Context.FCompleted;
  if vCompleted then
    FActiveFlows.Remove(vChatId);
end;

function TTelegramBotEx.NextSendToken: Int64;
begin
  Inc(FNextSendToken);
  Result := FNextSendToken;
end;

procedure TTelegramBotEx.QueueSendResult(const AChatId: string; const AToken: Int64; const AMessage: TTelegramMessage);
var
  vItem: TPendingSendResult;
begin
  vItem.ChatId := AChatId;
  vItem.Token := AToken;
  vItem.Message := AMessage;
  FPendingSendResults.Add(vItem);
end;

procedure TTelegramBotEx.ProcessPendingSendResults;
var
  vList: TList<TPendingSendResult>;
  vItems: TArray<TPendingSendResult>;
  vItem: TPendingSendResult;
  vState: TFlowState;
  vChatId: string;
  vCompleted: Boolean;
begin
  vList := FPendingSendResults.LockList;
  try
    if vList.Count = 0 then
      Exit;
    vItems := vList.ToArray;
    vList.Clear;
  finally
    FPendingSendResults.UnlockList;
  end;
  for vItem in vItems do
  begin
    if FActiveFlows.TryGetValue(vItem.ChatId, vState) and (vState.Context.FPendingType = fptAsyncSend) and
       (vState.Context.FPendingSendToken = vItem.Token) then
    begin
      vState.Context.FPendingMessage := vItem.Message;
      vState.Context.FPendingType := fptNone;
      vChatId := vItem.ChatId;
      SwitchToFiber(vState.FiberHandle);
      vCompleted := vState.Context.FCompleted;
      if vCompleted then
        FActiveFlows.Remove(vChatId);
    end
    else
      FreeAndNil(vItem.Message);
  end;
end;

procedure TTelegramBotEx.DoBeforeDispatchUpdate;
begin
  ProcessPendingSendResults;
end;

procedure TTelegramBotEx.Poll;
begin
  try
    inherited;
  finally
    ProcessPendingSendResults;
  end;
end;

procedure TTelegramBotEx.Initialize;
var
  vModule: TTelegramModule;
  I: Integer;
begin
  LoadButtonIds;

  RegisterButton('confirm', 'Подтвердить');
  RegisterButton('reject', 'Отклонить');
  RegisterButton('calendar_date', 'Выбор дня в календаре');
  RegisterButton('flow_accept_date', 'Подтвердить дату');
  RegisterButton('flow_enter_text', 'Ввести вручную');
  RegisterButton(cListPageButton, 'Страница списка');

  RegisterDoOnMessage(TryResumeFlowWithMessage);
  RegisterDoOnCallbackQuery(TryResumeFlowWithCallback);

  for I := 0 to FModuleClasses.Count - 1 do
    FModules.Add(FModuleClasses[I].Create(Self));

  for vModule in FModules do
    vModule.Register;

  for vModule in FModules do
    vModule.Initialize;

  RegisterDoOnMessage(DispatchCommandMessage);
  RegisterDoOnMessage(HandleRegisteredMessages);
  RegisterDoOnMessage(HandleModulesMessage);
  RegisterDoOnCallbackQuery(InternalExecuteCalbackAction);
  RegisterDoOnCallbackQuery(HandleModulesCallback);

  SaveButtonIds;

  DoInitialize;
  SendCommandsToTelegram;
end;

function TTelegramBotEx.InternalExecuteCalbackAction(const ACallback: TTelegramCallbackQuery): Boolean;
var
  vBId, vAId, I: Integer;
  vButton: string;
  vModalResult: TTgModalResult;
  vData, vCancelBtn: string;
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
    if not FSimpleButtons.ContainsKey(vBId) then
      Exit(False);
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
      if vButton = 'confirm' then
        vModalResult := tmrYes
      else
        vModalResult := tmrNo;
      vData := '';
      for I := 2 to vCallbackData.Count - 1 do
      begin
        if vData <> '' then
          vData := vData + ' ';
        vData := vData + vCallbackData.GetString(I);
      end;
      ExecuteAction(vCallbackData.GetInteger(1, -1), vData, ACallback, vModalResult, 0);
    end
    else if vButton = 'calendar_date' then
    begin
      vAId := vCallbackData.GetInteger(1, -1);

      vData := '';
      for I := 6 to vCallbackData.Count - 1 do
      begin
        if vData <> '' then
          vData := vData + ' ';
        vData := vData + vCallbackData.GetString(I);
      end;

      if not ExecuteAction(vAId, vData, ACallback, tmrYes, StrToDate(vCallbackData.GetString(2))) then
      begin
        vCancelBtn := '';
        if FSimpleButtons.ContainsKey(vCallbackData.GetInteger(5, -1)) then
          vCancelBtn := FSimpleButtons[vCallbackData.GetInteger(5)].Name;

        SendCalendar(ACallback.AtMessage, StrToDate(vCallbackData.GetString(2)), StrToDate(vCallbackData.GetString(3)),
          ACallback.From.Id, '', vData, FSimpleButtons[vCallbackData.GetInteger(4)].Name, vCancelBtn);
      end;
    end
    else if vButton = cListPageButton then
    begin
      vAId := vCallbackData.GetInteger(1, -1);
      if FSimpleButtons.ContainsKey(vAId) and FSimpleMenus.ContainsKey(FSimpleButtons[vAId].Name) then
      begin
        vExtraData := TCallbackData.Create;
        try
          for I := 3 to vCallbackData.Count - 1 do
            vExtraData.Add(vCallbackData.GetString(I));
          if CheckButtonAdd(FSimpleButtons[vAId].Name, ACallback.From.Id, vExtraData.ToString) then
            InternalSendMenu(ACallback.AtMessage, FSimpleButtons[vAId].Name, ACallback.From.Id, vExtraData, '', '',
              nil, vCallbackData.GetInteger(2, 0));
        finally
          FreeAndNil(vExtraData);
        end;
      end;
    end
    else if FSimpleMenus.ContainsKey(vButton) then
    begin
      vExtraData := TCallbackData.Create;
      try
        for I := 1 to vCallbackData.Count - 1 do
          vExtraData.Add(vCallbackData.GetString(I));
        if CheckButtonAdd(vButton, ACallback.From.Id, vExtraData.ToString) then
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


function TTelegramBotEx.AppendKeyboard(const AKeyboard: TTelegramInlineKeyboardMarkup; const AButton: string; const AData: TCallbackData = nil; const ACaption: string = ''; const ARow: Integer = -1; const AStyle: TTelegramButtonStyle = tbsNone): Integer;
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
      Result := AKeyboard.AddButton(vCaption, IntToStr(vButton.Id) + ' ' + vCallbackData.ToString, ARow, AStyle)
    else
      Result := AKeyboard.AddButton(vCaption, IntToStr(vButton.Id), ARow, AStyle);
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

function TTelegramBotEx.AppendMenuKeyboard(const AKeyboard: TTelegramInlineKeyboardMarkup; const AButton, ATelegramId: string; const AData: TCallbackData; const ACaption: string; const ARow: Integer; const AStyle: TTelegramButtonStyle): Boolean;
var
  vDataStr: string;
begin
  vDataStr := '';
  if Assigned(AData) then
  begin
    AData.Serialize;
    vDataStr := AData.ToString;
  end;
  Result := CheckButtonAdd(AButton, ATelegramId, vDataStr);
  if Result then
    AppendKeyboard(AKeyboard, AButton, AData, ACaption, ARow, AStyle);
end;

function TTelegramBotEx.AppendMenuKeyboard(const AKeyboard: TTelegramInlineKeyboardMarkup; const AButton, ATelegramId, AData, ACaption: string; const ARow: Integer; const AStyle: TTelegramButtonStyle): Boolean;
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
        AppendKeyboard(AKeyboard, AButton, vCallbackData, ACaption, ARow, AStyle);
      finally
        FreeAndNil(vCallbackData);
      end;
    end
    else
      AppendKeyboard(AKeyboard, AButton, nil, ACaption, ARow, AStyle);
  end;
end;

constructor TTelegramBotEx.Create(const AToken: string);
begin
  inherited;
  FSimpleButtons := TObjectDictionary<Integer, TSimpleButton>.Create([doOwnsValues]);
  FButtonsMap := TDictionary<string, TSimpleButton>.Create;
  FPersistedButtonIds := TDictionary<string, Integer>.Create;
  FNextButtonId := 0;
  FButtonIdsChanged := False;
  FSimpleMenus := TObjectDictionary<string, TSimpleMenu>.Create([doOwnsValues]);
  FActionsMap := TDictionary<string, Integer>.Create;
  FActiveFlows := TObjectDictionary<string, TFlowState>.Create([doOwnsValues]);
  FPendingSendResults := TThreadList<TPendingSendResult>.Create;
  FPendingSendResults.Duplicates := dupAccept;
  FNextSendToken := 0;
  FTypedHandlers := TObjectDictionary<string, TTypedButtonHandler>.Create([doOwnsValues]);
  FTypedActions := TObjectDictionary<Integer, TTypedActionHandler>.Create([doOwnsValues]);
  FSchedulerFiber := nil;
  FCommands := TObjectList<TBotCommand>.Create;
  FOnMessageProcedures := TList<TOnTelegramMessage>.Create;
  FOnCallbackQueryProcedures := TList<TOnTelegramCallbackQuery>.Create;
  FModules := TObjectList<TTelegramModule>.Create;
  FMessageHandlers := TList<TMessageHandlerEntry>.Create;
end;

destructor TTelegramBotEx.Destroy;
begin
  FreeAndNil(FActiveFlows);
  FreeAndNil(FPendingSendResults);
  FreeAndNil(FTypedHandlers);
  FreeAndNil(FTypedActions);
  FreeAndNil(FModules);
  FreeAndNil(FMessageHandlers);
  FreeAndNil(FSimpleButtons);
  FreeAndNil(FSimpleMenus);
  FreeAndNil(FButtonsMap);
  FreeAndNil(FPersistedButtonIds);
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

function TTelegramBotEx.ExecuteAction(const AActionId: Integer; const AParamsData: string;
  const ACallback: TTelegramCallbackQuery; const AModalResult: TTgModalResult; const ADate: TDateTime): Boolean;
var
  vTypedAction: TTypedActionHandler;
begin
  Result := FTypedActions.TryGetValue(AActionId, vTypedAction);
  if Result then
    vTypedAction.Execute(AParamsData, ACallback, AModalResult, ADate);
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

procedure TTelegramBotEx.RegisterMessageHandler(const AHandler: TOnTelegramMessage; const APriority: Integer);
var
  vEntry: TMessageHandlerEntry;
  I: Integer;
begin
  vEntry.Priority := APriority;
  vEntry.Handler := AHandler;
  I := 0;
  while (I < FMessageHandlers.Count) and (FMessageHandlers[I].Priority <= APriority) do
    Inc(I);
  FMessageHandlers.Insert(I, vEntry);
end;

function TTelegramBotEx.HandleRegisteredMessages(const AMessage: TTelegramMessage): Boolean;
var
  vEntry: TMessageHandlerEntry;
begin
  Result := False;
  for vEntry in FMessageHandlers do
    if vEntry.Handler(AMessage) then
      Exit(True);
end;

function TTelegramBotEx.DispatchCommandMessage(const AMessage: TTelegramMessage): Boolean;
var
  vText, vCommand: string;
  vSpacePos, vAtPos: Integer;
begin
  Result := False;
  vText := Trim(AMessage.Text);
  if (vText = '') or (vText[1] <> '/') then
    Exit;

  vSpacePos := Pos(' ', vText);
  if vSpacePos > 0 then
    vCommand := Copy(vText, 1, vSpacePos - 1)
  else
    vCommand := vText;

  vAtPos := Pos('@', vCommand);
  if vAtPos > 0 then
    vCommand := Copy(vCommand, 1, vAtPos - 1);

  if not DispatchCommand(vCommand, AMessage) then
    DoUnrecognizedCommand(AMessage);
  Result := True;
end;

procedure TTelegramBotEx.DoUnrecognizedCommand(const AMessage: TTelegramMessage);
begin
  SendMessage(AMessage.From.Id, 'Неизвестная команда');
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
    if not FSimpleButtons.ContainsKey(vBId) then
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
  vCommand: TBotCommand;
begin
  Result := False;
  for vCommand in FCommands do
    if Assigned(vCommand.Handler) and ('/' + vCommand.Command = ACommand) then
      if vCommand.Handler(AMessage) then
        Exit(True);

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

function TTelegramBotEx.RegisterActionId(const AName: string): Integer;
var
  vKey: string;
begin
  Assert(not FActionsMap.ContainsKey(AName), 'Action ' + AName + ' is already presented');
  vKey := cActionIdPrefix + AName;
  if not FPersistedButtonIds.TryGetValue(vKey, Result) then
  begin
    Result := FNextButtonId;
    Inc(FNextButtonId);
    FPersistedButtonIds.Add(vKey, Result);
    FButtonIdsChanged := True;
  end;
  FActionsMap.Add(AName, Result);
end;

procedure TTelegramBotEx.RegisterAction<T>(const AName: string; const AHandler: TProc<TActionData<T>>);
begin
  FTypedActions.Add(RegisterActionId(AName), TTypedActionHandler<T>.Create(AHandler));
end;

procedure TTelegramBotEx.LoadButtonIds;
var
  vLines: TStringList;
  I, vId: Integer;
  vName: string;
begin
  if not FileExists(cButtonIdsFileName) then
    Exit;
  vLines := TStringList.Create;
  try
    vLines.LoadFromFile(cButtonIdsFileName);
    for I := 0 to vLines.Count - 1 do
    begin
      vName := vLines.Names[I];
      if vName = '' then
        Continue;
      if not TryStrToInt(vLines.ValueFromIndex[I], vId) then
        Continue;
      FPersistedButtonIds.AddOrSetValue(vName, vId);
      if vId >= FNextButtonId then
        FNextButtonId := vId + 1;
    end;
  finally
    FreeAndNil(vLines);
  end;
end;

procedure TTelegramBotEx.SaveButtonIds;
var
  vLines: TStringList;
  vPair: TPair<string, Integer>;
begin
  if not FButtonIdsChanged then
    Exit;
  vLines := TStringList.Create;
  try
    for vPair in FPersistedButtonIds do
      vLines.Add(vPair.Key + '=' + IntToStr(vPair.Value));
    vLines.SaveToFile(cButtonIdsFileName);
    FButtonIdsChanged := False;
  finally
    FreeAndNil(vLines);
  end;
end;

procedure TTelegramBotEx.RegisterButton(const AName: string; const ACaption: string; const AURL: string);
var
  vButton: TSimpleButton;
  vId: Integer;
begin
  Assert(not FButtonsMap.ContainsKey(AName), 'Button ' + AName + ' is already presented');
  if not FPersistedButtonIds.TryGetValue(AName, vId) then
  begin
    vId := FNextButtonId;
    Inc(FNextButtonId);
    FPersistedButtonIds.Add(AName, vId);
    FButtonIdsChanged := True;
  end;
  vButton := TSimpleButton.Create(vId, AName, ACaption, AURL);
  FSimpleButtons.Add(vId, vButton);
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
begin
  RegisterCommand(ACommand, ADescription, nil);
end;

procedure TTelegramBotEx.RegisterCommand(const ACommand, ADescription: string; const AHandler: TFunc<TTelegramMessage, Boolean>);
var
  vCommand: TBotCommand;
begin
  vCommand := TBotCommand.Create(ACommand, ADescription, AHandler);
  FCommands.Add(vCommand);
end;

procedure TTelegramBotEx.SendCommandsToTelegram;
var
  vCommands: TStringList;
  vSeen: TDictionary<string, Boolean>;
  vCommand: TBotCommand;
begin
  if FCommands.Count = 0 then
    Exit;

  vCommands := TStringList.Create;
  vSeen := TDictionary<string, Boolean>.Create;
  try
    for vCommand in FCommands do
      if not vSeen.ContainsKey(vCommand.Command) then
      begin
        vSeen.Add(vCommand.Command, True);
        vCommands.Add(vCommand.Command + '=' + vCommand.Description);
      end;
    SetMyCommands(vCommands);
  finally
    FreeAndNil(vSeen);
    FreeAndNil(vCommands);
  end;
end;

procedure TTelegramBotEx.RegisterMenuButton(const AMenuName, ACaption: string);
begin
  if not FButtonsMap.ContainsKey(AMenuName) then
    RegisterButton(AMenuName, ACaption);
end;

procedure TTelegramBotEx.RegisterMenuButton<T>(const AMenuName, ACaption: string; const AACL: TFunc<T, Boolean>);
var
  vTypedHandler: TTypedButtonHandler<T>;
begin
  if not FButtonsMap.ContainsKey(AMenuName) then
    RegisterButton(AMenuName, ACaption);
  vTypedHandler := TTypedButtonHandler<T>.Create(nil, AACL);
  FTypedHandlers.Add(AMenuName, vTypedHandler);
end;

procedure TTelegramBotEx.RegisterMenuButton<T>(const AMenuName, ACaption: string; const AACL: TFunc<T, Boolean>;
  const AConstructProcedure: TConstructSimpleMenuProcedure);
var
  vTypedHandler: TTypedButtonHandler<T>;
begin
  Assert(Assigned(AConstructProcedure), 'Функция создания должна быть!');
  if not FButtonsMap.ContainsKey(AMenuName) then
    RegisterButton(AMenuName, ACaption);
  vTypedHandler := TTypedButtonHandler<T>.Create(nil, AACL);
  FTypedHandlers.Add(AMenuName, vTypedHandler);
  FSimpleMenus.Add(AMenuName, TSimpleMenu.Create(FSimpleMenus.Count, AConstructProcedure));
end;

procedure TTelegramBotEx.SetListMenuContent(const AMenuName: string;
  const AConstructProcedure: TConstructListMenuProcedure; const AButtonCaption: string = '');
var
  vMenu: TSimpleMenu;
begin
  Assert(Assigned(AConstructProcedure), 'Функция создания должна быть!');
  vMenu := TSimpleMenu.Create(FSimpleMenus.Count, TConstructSimpleMenuProcedure(nil));
  vMenu.ListConstructProcedure := AConstructProcedure;
  FSimpleMenus.Add(AMenuName, vMenu);
  if (AButtonCaption <> '') and not FButtonsMap.ContainsKey(AMenuName) then
    RegisterButton(AMenuName, AButtonCaption);
end;

procedure TTelegramBotEx.RegisterListMenuButton<T>(const AMenuName, ACaption: string; const AACL: TFunc<T, Boolean>;
  const AConstructProcedure: TConstructListMenuProcedure);
var
  vMenu: TSimpleMenu;
begin
  Assert(Assigned(AConstructProcedure), 'Функция создания должна быть!');
  if not FButtonsMap.ContainsKey(AMenuName) then
    RegisterButton(AMenuName, ACaption);
  FTypedHandlers.Add(AMenuName, TTypedButtonHandler<T>.Create(nil, AACL));
  vMenu := TSimpleMenu.Create(FSimpleMenus.Count, TConstructSimpleMenuProcedure(nil));
  vMenu.ListConstructProcedure := AConstructProcedure;
  FSimpleMenus.Add(AMenuName, vMenu);
end;

function TTelegramBotEx.PageBounds(const ACount, APage, APageSize: Integer;
  out AActualPage, AFirst, ALast: Integer): Integer;
begin
  Result := Max(1, (ACount + APageSize - 1) div APageSize);
  AActualPage := EnsureRange(APage, 0, Result - 1);
  AFirst := AActualPage * APageSize;
  ALast := Min(ACount, AFirst + APageSize) - 1;
end;

procedure TTelegramBotEx.AppendPagination(const AKeyboard: TTelegramInlineKeyboardMarkup; const AMenuName: string;
  const AData: TCallbackData; const APage, APageCount: Integer; const ACounterButton: string = '');
var
  vPrefix, vTail, vCounter: string;
  vRow: Integer;

  function PageData(const APageNumber: Integer): string;
  begin
    Result := vPrefix + ' ' + IntToStr(APageNumber);
    if vTail <> '' then
      Result := Result + ' ' + vTail;
  end;

begin
  if APageCount <= 1 then
    Exit;
  vPrefix := IntToStr(FButtonsMap.Items[AMenuName].Id);
  vTail := '';
  if Assigned(AData) then
    vTail := AData.ToString;
  vCounter := Format('%d / %d', [APage + 1, APageCount]);
  vRow := -1;
  if APage > 0 then
  begin
    vRow := AppendKeyboard(AKeyboard, cListPageButton, PageData(0), '|◀');
    AppendKeyboard(AKeyboard, cListPageButton, PageData(APage - 1), '◀', vRow);
  end;
  if ACounterButton <> '' then
    vRow := AppendKeyboard(AKeyboard, ACounterButton, vTail, vCounter, vRow)
  else if vRow = -1 then
    vRow := AKeyboard.AddButton(vCounter, '-1')
  else
    AKeyboard.AddButton(vCounter, '-1', vRow);
  if APage < APageCount - 1 then
  begin
    AppendKeyboard(AKeyboard, cListPageButton, PageData(APage + 1), '▶', vRow);
    AppendKeyboard(AKeyboard, cListPageButton, PageData(APageCount - 1), '▶|', vRow);
  end;
end;

procedure TTelegramBotEx.SendListMenu(const AMessage: TTelegramMessage; const AMenuName, ARecipient: string;
  const AData: TCallbackData; const APage: Integer);
begin
  InternalSendMenu(AMessage, AMenuName, ARecipient, AData, '', '', nil, APage);
end;

function TTelegramBotEx.IsButtonVisible(const AButton, ATelegramId: string; const AData: TCallbackData): Boolean;
var
  vDataStr: string;
begin
  vDataStr := '';
  if Assigned(AData) then
  begin
    AData.Serialize;
    vDataStr := AData.ToString;
  end;
  Result := CheckButtonAdd(AButton, ATelegramId, vDataStr);
end;

procedure TTelegramBotEx.SetMenuContent(const AMenuName: string;
  const AConstructProcedure: TConstructSimpleMenuProcedure; const AButtonCaption: string = '');
begin
  Assert(Assigned(AConstructProcedure), 'Функция создания должна быть!');
  FSimpleMenus.Add(AMenuName, TSimpleMenu.Create(FSimpleMenus.Count, AConstructProcedure));
  if (AButtonCaption <> '') and not FButtonsMap.ContainsKey(AMenuName) then
    RegisterButton(AMenuName, AButtonCaption);
end;

procedure TTelegramBotEx.SetMenuContent(const AMenuName: string;
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
  vActionId := -1;
  if ASelectDateAction <> '' then
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
  const ACancelBtn: string = '');
var
  vCaption: string;
  vKeyboard: TTelegramInlineKeyboardMarkup;
begin
  BuildCalendarKeyboard(ATelegramId, ACurrentDate, AMinDate, ASelectDateAction,
    AData, AAcceptBtn, ACancelBtn, vCaption, vKeyboard);
  try
    if Assigned(AMessage) then
      EditMessageText(AMessage, vCaption, vKeyboard)
    else
      SendMessage(ATelegramId, vCaption, vKeyboard);
  finally
    FreeAndNil(vKeyboard);
  end;
end;

procedure TTelegramBotEx.SendCalendarResulted(const ATelegramId: string;
  const ACurrentDate, AMinDate: TDateTime; const ACancelButton: string; const ACancelData: TCallbackData;
  const AOnSent: TProc<TTelegramMessage>);
var
  vCaption: string;
  vKeyboard: TTelegramInlineKeyboardMarkup;
begin
  BuildCalendarKeyboard(ATelegramId, ACurrentDate, AMinDate, '',
    '', 'flow_accept_date', ACancelButton, vCaption, vKeyboard, ACancelData);
  try
    SendMessageResulted(ATelegramId, vCaption, vKeyboard, AOnSent);
  finally
    FreeAndNil(vKeyboard);
  end;
end;

procedure TTelegramBotEx.SendConfirmation(const AMessage: TTelegramMessage; const ATelegramId, AText, AAction: string; const AOwnedData: TCallbackData; const APhoto: string = ''; const ADocument: string = '');
var
  vActionId: Integer;
  vKeyboard: TTelegramInlineKeyboardMarkup;
  vDataStr: string;
begin
  try
    if Assigned(AOwnedData) then
    begin
      AOwnedData.Serialize;
      vDataStr := AOwnedData.ToString;
    end;
  finally
    AOwnedData.Free;
  end;
  if Assigned(AMessage) then
    DeleteMessage(AMessage);
  Assert(FActionsMap.TryGetValue(AAction, vActionId), 'Action <'+AAction+'> not found');
  vKeyboard := TTelegramInlineKeyboardMarkup.Create;
  AppendKeyboard(vKeyboard, 'confirm', IntToStr(vActionId) + ' ' + vDataStr);
  AppendKeyboard(vKeyboard, 'reject', IntToStr(vActionId) + ' ' + vDataStr);
  if APhoto <> '' then
    SendPhoto(ATelegramId, APhoto, AText, vKeyboard)
  else if ADocument <> '' then
    SendDocument(ATelegramId, ADocument, AText, vKeyboard)
  else
    SendMessage(ATelegramId, AText, vKeyboard);
  FreeAndNil(vKeyboard);
end;

procedure TTelegramBotEx.SendConfirmationResulted(const AMessage: TTelegramMessage; const ATelegramId, AText, AAction: string;
  const AOwnedData: TCallbackData; const AOnSent: TProc<TTelegramMessage>);
var
  vActionId: Integer;
  vKeyboard: TTelegramInlineKeyboardMarkup;
  vDataStr: string;
begin
  try
    if Assigned(AOwnedData) then
    begin
      AOwnedData.Serialize;
      vDataStr := AOwnedData.ToString;
    end;
  finally
    AOwnedData.Free;
  end;
  if Assigned(AMessage) then
    DeleteMessage(AMessage);
  Assert(FActionsMap.TryGetValue(AAction, vActionId), 'Action <'+AAction+'> not found');
  vKeyboard := TTelegramInlineKeyboardMarkup.Create;
  try
    AppendKeyboard(vKeyboard, 'confirm', IntToStr(vActionId) + ' ' + vDataStr);
    AppendKeyboard(vKeyboard, 'reject', IntToStr(vActionId) + ' ' + vDataStr);
    SendMessageResulted(ATelegramId, AText, vKeyboard, AOnSent);
  finally
    FreeAndNil(vKeyboard);
  end;
end;

procedure TTelegramBotEx.SendMenu(const AMessage: TTelegramMessage;
  const AMenuName, ARecipient: string; const AExtraData: TCallbackData; const ACaption, APhoto: string);
begin
  InternalSendMenu(AMessage, AMenuName, ARecipient, AExtraData, ACaption, APhoto, nil, 0);
end;

procedure TTelegramBotEx.SendMenu(const AMessage: TTelegramMessage; const AMenuName, ARecipient: string;
  const AExtraData: TCallbackData; const ACaption: string; const APhotoStream: TStream);
begin
  InternalSendMenu(AMessage, AMenuName, ARecipient, AExtraData, ACaption, '', APhotoStream, 0);
end;

procedure TTelegramBotEx.InternalSendMenu(const AMessage: TTelegramMessage; const AMenuName, ARecipient: string;
  const AExtraData: TCallbackData; const ACaption, APhoto: string; const APhotoStream: TStream;
  const APage: Integer);
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
  vPhotoStream, vSendStream: TStream;
  vHasPhoto: Boolean;
begin
  vPhotoStream := APhotoStream;
  vOwnData := False;
  vData := nil;
  vKeyboard := nil;
  try
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
    if Assigned(vMenu.ListConstructProcedure) then
      vMenu.ListConstructProcedure(vRecipient, vData, APage, vCaption, vKeyboard)
    else if Assigned(vMenu.ConstructProcedure) then
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
    vHasPhoto := (APhoto <> '') or Assigned(vPhotoStream);
    if Assigned(AMessage) and ((AMessage.Photo <> '') or vHasPhoto) then
    begin
      if not vHasPhoto then
      begin
        DeleteMessage(AMessage);
        SendMessage(vRecipient, vCaption, vKeyboard);
      end
      else if Assigned(vPhotoStream) then
      begin
        vSendStream := vPhotoStream;
        vPhotoStream := nil;
        EditMessageMedia(AMessage, vSendStream, cMenuPhotoFileName, vCaption, vKeyboard);
      end
      else
        EditMessageMedia(AMessage, APhoto, vCaption, vKeyboard);
    end
    else if Assigned(AMessage) then
      EditMessageText(AMessage, vCaption, vKeyboard)
    else if not vHasPhoto then
      SendMessage(vRecipient, vCaption, vKeyboard)
    else if Assigned(vPhotoStream) then
    begin
      vSendStream := vPhotoStream;
      vPhotoStream := nil;
      SendPhoto(vRecipient, vSendStream, cMenuPhotoFileName, vCaption, vKeyboard);
    end
    else
      SendPhoto(vRecipient, APhoto, vCaption, vKeyboard);
  finally
    if vOwnData then
      FreeAndNil(vData);
    FreeAndNil(vKeyboard);
    FreeAndNil(vPhotoStream);
  end;
end;

procedure TTelegramBotEx.SendMenu<T>(const AMessage: TTelegramMessage;
  const AMenuName, ARecipient: string; const AOwnedExtraData: T; const ACaption, APhoto: string);
begin
  try
    AOwnedExtraData.Serialize;
    SendMenu(AMessage, AMenuName, ARecipient, TCallbackData(AOwnedExtraData), ACaption, APhoto);
  finally
    AOwnedExtraData.Free;
  end;
end;

procedure TTelegramBotEx.SendMenu<T>(const AMessage: TTelegramMessage; const AMenuName, ARecipient: string;
  const AOwnedExtraData: T; const ACaption: string; const APhotoStream: TStream);
begin
  try
    AOwnedExtraData.Serialize;
    InternalSendMenu(AMessage, AMenuName, ARecipient, TCallbackData(AOwnedExtraData), ACaption, '', APhotoStream, 0);
  finally
    AOwnedExtraData.Free;
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

procedure TTelegramModule.RegisterAction<T>(const AName: string; const AHandler: TProc<TActionData<T>>);
begin
  FBot.RegisterAction<T>(AName, AHandler);
end;

procedure TTelegramModule.RegisterCommand(const ACommand, ADescription: string);
begin
  FBot.RegisterCommand(ACommand, ADescription);
end;

procedure TTelegramModule.RegisterCommand(const ACommand, ADescription: string; const AHandler: TFunc<TTelegramMessage, Boolean>);
begin
  FBot.RegisterCommand(ACommand, ADescription, AHandler);
end;

procedure TTelegramModule.RegisterMessageHandler(const AHandler: TOnTelegramMessage; const APriority: Integer);
begin
  FBot.RegisterMessageHandler(AHandler, APriority);
end;

procedure TTelegramModule.RegisterMenuButton(const AMenuName, ACaption: string);
begin
  FBot.RegisterMenuButton(AMenuName, ACaption);
end;

procedure TTelegramModule.SetMenuContent(const AMenuName, ACaption: string; const AButtons: TButtons; const ABackButton: string = '');
begin
  FBot.SetMenuContent(AMenuName, ACaption, AButtons, ABackButton);
end;

procedure TTelegramModule.SetListMenuContent(const AMenuName: string; const AConstructProcedure: TConstructListMenuProcedure; const AButtonCaption: string = '');
begin
  FBot.SetListMenuContent(AMenuName, AConstructProcedure, AButtonCaption);
end;

procedure TTelegramModule.RegisterListMenuButton<T>(const AMenuName, ACaption: string; const AACL: TFunc<T, Boolean>;
  const AConstructProcedure: TConstructListMenuProcedure);
begin
  FBot.RegisterListMenuButton<T>(AMenuName, ACaption, AACL, AConstructProcedure);
end;

procedure TTelegramModule.SetMenuContent(const AMenuName: string; const AConstructProcedure: TConstructSimpleMenuProcedure; const AButtonCaption: string = '');
begin
  FBot.SetMenuContent(AMenuName, AConstructProcedure, AButtonCaption);
end;

procedure TTelegramModule.RegisterMenuButton<T>(const AMenuName, ACaption: string; const AACL: TFunc<T, Boolean>);
begin
  FBot.RegisterMenuButton<T>(AMenuName, ACaption, AACL);
end;

procedure TTelegramModule.RegisterMenuButton<T>(const AMenuName, ACaption: string; const AACL: TFunc<T, Boolean>;
  const AConstructProcedure: TConstructSimpleMenuProcedure);
begin
  FBot.RegisterMenuButton<T>(AMenuName, ACaption, AACL, AConstructProcedure);
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

constructor TBotCommand.Create(const ACommand, ADescription: string; const AHandler: TFunc<TTelegramMessage, Boolean>);
begin
  Command := ACommand;
  Description := ADescription;
  Handler := AHandler;
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

constructor TTypedActionHandler<T>.Create(const AHandler: TProc<TActionData<T>>);
begin
  FHandler := AHandler;
end;

procedure TTypedActionHandler<T>.Execute(const AParamsData: string; const ACallback: TTelegramCallbackQuery;
  const AModalResult: TTgModalResult; const ADate: TDateTime);
var
  vData: T;
  vShifted: string;
  vAction: TActionData<T>;
begin
  vShifted := '0';
  if AParamsData <> '' then
    vShifted := vShifted + ' ' + AParamsData;
  vData := T.Create;
  vAction := TActionData<T>.Create(vData);
  try
    vData.LoadData(vShifted);
    vData.FCallback := ACallback;
    vData.Parse;
    vAction.FCallback := ACallback;
    vAction.FModalResult := AModalResult;
    vAction.FDate := ADate;
    FHandler(vAction);
  finally
    FreeAndNil(vAction);
  end;
end;

constructor TActionData<T>.Create(const AParams: T);
begin
  inherited Create;
  FParams := AParams;
end;

destructor TActionData<T>.Destroy;
begin
  FParams.Free;
  inherited;
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
