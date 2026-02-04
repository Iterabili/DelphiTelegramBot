unit uJSONHelper;

interface

uses
  JSON, UITypes, Classes;

type
  TJSONHelper = class helper for TJSONObject
  private
    function DelveIntoPath(const APath: string): TJSONValue;
  public
    function Contains(const APairName: string): Boolean;

    function ToRawString: string;

    function ExtractString(const AKey: string; const APath: string = ''; const ADefault: string = ''): string;
    function ExtractInteger(const AKey: string; const ADefault: Integer = 0): Integer;
    function ExtractInt64(const AKey: string; const ADefault: Int64 = 0): Int64;
    function ExtractFloat(const AKey: string; const ADefault: Double = 0): Double;
    function ExtractBoolean(const AKey: string): Boolean;
    function ExtractDateTime(const AKey: string; const ADefault: Double = 0): TDateTime;
    function ExtractColor(const AKey: string; const ADefault: TAlphaColor = TAlphaColorRec.Null): Cardinal;
    function ExtractObject(const AKey: string): TJSONObject;
    function ExtractArray(const AKey: string): TJSONArray;
    function ExtractStrings(const AKey: string): TStrings;
    function ExtractCurrency(const Akey: string; const ADefault: Currency = 0): Currency;

    procedure StoreString(const AKey: string; const AValue: string);
    procedure StoreInteger(const AKey: string; const AValue: Int64);
    procedure StoreFloat(const AKey: string; const AValue: Double);
    procedure StoreBoolean(const AKey: string; const AValue: Boolean);
    procedure StoreDateTime(const AKey: string; const AValue: TDateTime);
    procedure StoreColor(const AKey: string; const AValue: TAlphaColor);
    procedure StoreStrings(const AKey: string; const AValue: TStrings);
    procedure StoreCurrency(const AKey: string; const AValue: Currency);

    procedure SaveToFile(const AFileName: string);
    class function LoadFromFile(const AFileName: string): TJSONObject; static;
    class function LoadFromText(const AText: string; const APath: string = ''): TJSONObject; static;
  end;

implementation

uses
  SysUtils, RegularExpressions, UIConsts;

{ TJSONHelper }

function JSONDateToDateTime(const AValue: string): TDateTime;
var
  vMatches: TMatchCollection;
  vGroups: TGroupCollection;
  i: Integer;
  vDateTimeParts: array[0..6] of Word;
begin
  Result := 0;
  try
    vMatches := TRegEx.Matches(AValue, '(\d+)-(\d+)-(\d+)T(\d+):(\d+):(\d+)\.(\d+)Z', [roIgnoreCase]);
    if vMatches.Count = 0 then
      Exit;

    vGroups := vMatches[0].Groups;
    for i := 1 to vGroups.Count - 1 do
      vDateTimeParts[i-1] := StrToIntDef(vGroups[i].Value, 0);
    Result := EncodeDate(vDateTimeParts[0], vDateTimeParts[1], vDateTimeParts[2]) +
      EncodeTime(vDateTimeParts[3], vDateTimeParts[4], vDateTimeParts[5], vDateTimeParts[6]);
  except
    Result := 0;
  end;
end;

function TJSONHelper.Contains(const APairName: string): Boolean;
begin
  Result := GetValue(APairName) <> nil;
end;

function TJSONHelper.DelveIntoPath(const APath: string): TJSONValue;
var
  vPath: TStrings;
  i: Integer;
begin
  vPath := TStringList.Create;
  vPath.Delimiter := '/';
  vPath.DelimitedText := Trim(APath);
  Result := Self;
  try
    for i := 0 to vPath.Count - 1 do
    begin
      if Result is TJSONObject then
        Result := TJSONObject(Result).GetValue(Trim(vPath[i]))
      else
        Result := nil;

      if not Assigned(Result) then
        Break;
    end;
  finally
    vPath.Free;
  end;
end;

function TJSONHelper.ExtractArray(const AKey: string): TJSONArray;
begin
  Result := TJSONArray(GetValue(AKey));
end;

function TJSONHelper.ExtractBoolean(const AKey: string): Boolean;
var
  vValue: TJSONValue;
  vStrBool: string;
begin
  vValue := GetValue(AKey);
  if vValue is TJSONTrue then
    Result := True
  else if vValue is TJSONFalse then
    Result := False
  else begin
    vStrBool := ExtractString(AKey);
    if vStrBool = 'true' then
      Result := True
    else if vStrBool = 'false'  then
      Result := False
    else
      Result := Boolean(StrToIntDef(vStrBool, 0));
  end;
end;

function TJSONHelper.ExtractColor(const AKey: string; const ADefault: TAlphaColor): Cardinal;
begin
  Result := StringToAlphaColor(Trim(ExtractString(AKey)));
  if (Result = TAlphaColorRec.Null) and (ADefault <> TAlphaColorRec.Null) then
    Result := ADefault;
end;

function TJSONHelper.ExtractCurrency(const Akey: string; const ADefault: Currency): Currency;
var
  vValue: TJSONValue;
begin
  vValue := GetValue(AKey);
  if Assigned(vValue) then
    Result := TJSONNumber(vValue).{$IF CompilerVersion >= 36}AsCurrency{$ELSE}AsDouble{$ENDIF}
  else
    Result := ADefault;
end;

function TJSONHelper.ExtractDateTime(const AKey: string; const ADefault: Double): TDateTime;
var
  vStrDate: string;
begin
  vStrDate := ExtractString(AKey);
  if vStrDate <> '' then
    Result := JSONDateToDateTime(vStrDate)
  else
    Result := ADefault;
end;

function TJSONHelper.ExtractFloat(const AKey: string; const ADefault: Double): Double;
var
  vValue: TJSONValue;
begin
  vValue := GetValue(AKey);
  if Assigned(vValue) then
    Result := TJSONNumber(vValue).AsDouble
  else
    Result := ADefault;
end;

function TJSONHelper.ExtractInt64(const AKey: string; const ADefault: Int64): Int64;
var
  vValue: TJSONValue;
begin
  vValue := GetValue(AKey);
  if Assigned(vValue) then
    Result := TJSONNumber(vValue).AsInt64
  else
    Result := ADefault;
end;

function TJSONHelper.ExtractInteger(const AKey: string; const ADefault: Integer): Integer;
var
  vValue: TJSONValue;
begin
  vValue := GetValue(AKey);
  if Assigned(vValue) then
    Result := TJSONNumber(vValue).AsInt
  else
    Result := ADefault;
end;

function TJSONHelper.ExtractObject(const AKey: string): TJSONObject;
begin
  Result := TJSONObject(GetValue(AKey))
end;

function TJSONHelper.ExtractString(const AKey, APath, ADefault: string): string;
var
  vParent: TJSONObject;
  vValue: TJSONValue;
begin
  Result := ADefault;

  if Trim(APath) <> '' then
    vParent := TJSONObject(DelveIntoPath(APath))
  else
    vParent := Self;

  if not Assigned(vParent) then
    Exit;

  vValue := vParent.GetValue(AKey);
  if Assigned(vValue) then
    Result := TJSONString(vValue).Value;
end;

function TJSONHelper.ExtractStrings(const AKey: string): TStrings;
var
  vArray: TJSONArray;
  i: Integer;
  vValue: string;
begin
  vArray := TJSONArray(GetValue(AKey));
  if Assigned(vArray) then
  begin
    Result := TStringList.Create;
    for i := 0 to vArray.Count - 1 do
    begin
      vValue := TJSONString(vArray.Items[i]).Value;
      if Result.IndexOf(vValue) < 0 then
        Result.Add(vValue);
    end;
  end
  else
    Result := nil;
end;

class function TJSONHelper.LoadFromText(const AText, APath: string): TJSONObject;
begin
  try
    Result := TJSONObject(ParseJSONValue(AText));
    if Trim(APath) <> '' then
      Result := TJSONObject(Result.DelveIntoPath(APath));
  except
    Result := nil;
  end;
end;

class function TJSONHelper.LoadFromFile(const AFileName: string): TJSONObject;
var
  vStream: TStringStream;
begin
  vStream := TStringStream.Create('', TEncoding.UTF8);
  try
    vStream.LoadFromFile(AFileName);
    vStream.Position := 0;
    Result := LoadFromText(vStream.DataString);
  finally
    vStream.Free;
  end;
end;

procedure TJSONHelper.SaveToFile(const AFileName: string);
var
  vStream: TStringStream;
begin
  vStream := TStringStream.Create(ToString, TEncoding.UTF8, False);
  try
    vStream.SaveToFile(AFileName);
  finally
    vStream.Free;
  end;
end;

procedure TJSONHelper.StoreBoolean(const AKey: string; const AValue: Boolean);
begin
  if AValue then
    AddPair(AKey, TJSONTrue.Create)
  else
    AddPair(AKey, TJSONFalse.Create);
end;

procedure TJSONHelper.StoreColor(const AKey: string; const AValue: TAlphaColor);
begin
  AddPair(AKey, AlphaColorToString(AValue));
end;

procedure TJSONHelper.StoreCurrency(const AKey: string; const AValue: Currency);
begin
  AddPair(AKey, AValue);
end;

procedure TJSONHelper.StoreDateTime(const AKey: string; const AValue: TDateTime);
var
  vDatePart: array[0..6] of Word;
begin
  DecodeDate(AValue, vDatePart[0], vDatePart[1], vDatePart[2]);
  DecodeTime(AValue, vDatePart[3], vDatePart[4], vDatePart[5], vDatePart[6]);
  AddPair(AKey, SysUtils.Format('%d-%d-%dT%d:%d:%d.%dZ',
    [vDatePart[0], vDatePart[1], vDatePart[2], vDatePart[3],
     vDatePart[4], vDatePart[5], vDatePart[6]]));
end;

procedure TJSONHelper.StoreFloat(const AKey: string; const AValue: Double);
begin
  AddPair(AKey, TJSONNumber.Create(AValue));
end;

procedure TJSONHelper.StoreInteger(const AKey: string; const AValue: Int64);
begin
  AddPair(AKey, TJSONNumber.Create(AValue));
end;

procedure TJSONHelper.StoreString(const AKey, AValue: string);
begin
  AddPair(AKey, AValue);
end;

procedure TJSONHelper.StoreStrings(const AKey: string; const AValue: TStrings);
var
  i: Integer;
  vArray: TJSONArray;
begin
  if not Assigned(AValue) then
    Exit;

  if AValue.Count = 0 then
    Exit;

  vArray := TJSONArray.Create;
  try
    for i := 0 to AValue.Count - 1 do
      vArray.Add(AValue[i]);
  finally
    AddPair(AKey, vArray);
  end;
end;

function TJSONHelper.ToRawString: string;
begin

end;

end.
