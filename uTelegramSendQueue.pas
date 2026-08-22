unit uTelegramSendQueue;

interface

uses
  System.Classes, System.SysUtils, System.Types, System.Generics.Collections,
  Net.HttpClient;

type
  TTelegramQueueKind = (tqkSend, tqkControl, tqkBroadcast);

  TTelegramSendQueue = class
  public
    class procedure Start; static;
    class procedure Stop; static;
    class procedure Enqueue(const AProc: TProc; const AKind: TTelegramQueueKind); static;
    class procedure EnqueueWithCallback<T>(const AFunc: TFunc<T>; const ACallback: TProc<T>;
      const AKind: TTelegramQueueKind); static;
    class function HTTPClient(const AKind: TTelegramQueueKind): THTTPClient; static;
  end;

implementation

uses
  madExcept;

type
  TTelegramSendThread = class(TThread)
  private
    FWorkQueue: TThreadedQueue<TProc>;
    FBroadcastQueue: TThreadedQueue<TProc>;
    FHTTPClient: THTTPClient;
    FRateLimited: Boolean;
  protected
    procedure Execute; override;
  public
    constructor Create(const ARateLimited: Boolean; const AWithBroadcastQueue: Boolean = False);
    destructor Destroy; override;
    property WorkQueue: TThreadedQueue<TProc> read FWorkQueue;
    property BroadcastQueue: TThreadedQueue<TProc> read FBroadcastQueue;
    property HTTPClient: THTTPClient read FHTTPClient;
  end;

const
  cSendRateLimitInterval = 1000;
  cSendRateLimit = 30;
  cInteractivePollTimeout = 10;
  cBroadcastPollTimeout = 50;

constructor TTelegramSendThread.Create(const ARateLimited: Boolean; const AWithBroadcastQueue: Boolean = False);
begin
  FRateLimited := ARateLimited;
  if AWithBroadcastQueue then
  begin
    FWorkQueue := TThreadedQueue<TProc>.Create(1000, INFINITE, cInteractivePollTimeout);
    FBroadcastQueue := TThreadedQueue<TProc>.Create(1000, INFINITE, cBroadcastPollTimeout);
  end
  else
    FWorkQueue := TThreadedQueue<TProc>.Create(1000);
  FHTTPClient := THTTPClient.Create;
  FHTTPClient.SecureProtocols := [THTTPSecureProtocol.TLS1, THTTPSecureProtocol.TLS11,
    THTTPSecureProtocol.TLS12, THTTPSecureProtocol.TLS13];
  FHTTPClient.HandleRedirects := True;
  inherited Create(False);
end;

destructor TTelegramSendThread.Destroy;
begin
  FreeAndNil(FWorkQueue);
  FreeAndNil(FBroadcastQueue);
  FreeAndNil(FHTTPClient);
  inherited;
end;

procedure TTelegramSendThread.Execute;
var
  vProc: TProc;
  vTick: UInt64;
  vCounter: Integer;
  vWaitResult: TWaitResult;
begin
  vTick := TThread.GetTickCount64;
  vCounter := 0;
  while not Terminated do
  begin
    vWaitResult := FWorkQueue.PopItem(vProc);
    if (vWaitResult <> TWaitResult.wrSignaled) and Assigned(FBroadcastQueue) then
      vWaitResult := FBroadcastQueue.PopItem(vProc);

    if (vWaitResult = TWaitResult.wrSignaled) and Assigned(vProc) then
    begin
      if FRateLimited then
      begin
        if TThread.GetTickCount64 - vTick >= cSendRateLimitInterval then
        begin
          vTick := TThread.GetTickCount64;
          vCounter := 0;
        end;
        if vCounter >= cSendRateLimit then
        begin
          Sleep(cSendRateLimitInterval - Integer(TThread.GetTickCount64 - vTick));
          vTick := TThread.GetTickCount64;
          vCounter := 0;
        end;
      end;
      try
        vProc();
      except
        on E: Exception do
          HandleException;
      end;
      Inc(vCounter);
    end
    else if FWorkQueue.ShutDown and (not Assigned(FBroadcastQueue) or FBroadcastQueue.ShutDown) then
      Break;
  end;
end;

var
  gSendThread: TTelegramSendThread;
  gControlThread: TTelegramSendThread;

function GetThread(const AKind: TTelegramQueueKind): TTelegramSendThread;
begin
  if AKind = tqkControl then
    Result := gControlThread
  else
    Result := gSendThread;
end;

class procedure TTelegramSendQueue.Start;
begin
  if not Assigned(gSendThread) then
    gSendThread := TTelegramSendThread.Create(True, True);
  if not Assigned(gControlThread) then
    gControlThread := TTelegramSendThread.Create(False);
end;

class procedure TTelegramSendQueue.Stop;
begin
  if Assigned(gSendThread) then
  begin
    gSendThread.WorkQueue.DoShutDown;
    gSendThread.BroadcastQueue.DoShutDown;
    gSendThread.Terminate;
    gSendThread.WaitFor;
    FreeAndNil(gSendThread);
  end;
  if Assigned(gControlThread) then
  begin
    gControlThread.WorkQueue.DoShutDown;
    gControlThread.Terminate;
    gControlThread.WaitFor;
    FreeAndNil(gControlThread);
  end;
end;

class procedure TTelegramSendQueue.Enqueue(const AProc: TProc; const AKind: TTelegramQueueKind);
begin
  if AKind = tqkBroadcast then
    gSendThread.BroadcastQueue.PushItem(AProc)
  else
    GetThread(AKind).WorkQueue.PushItem(AProc);
end;

class procedure TTelegramSendQueue.EnqueueWithCallback<T>(const AFunc: TFunc<T>; const ACallback: TProc<T>;
  const AKind: TTelegramQueueKind);
begin
  Enqueue(
    procedure
    var
      vResult: T;
    begin
      vResult := AFunc();
      if Assigned(ACallback) then
        ACallback(vResult);
    end,
    AKind);
end;

class function TTelegramSendQueue.HTTPClient(const AKind: TTelegramQueueKind): THTTPClient;
begin
  if AKind = tqkBroadcast then
    Result := gSendThread.HTTPClient
  else
    Result := GetThread(AKind).HTTPClient;
end;

end.
