unit MT4Communication;

{$mode objfpc}{$H+}

interface

type
  TD_Terna = array[0..2] of double;
  TIPair = array[0..1] of LongInt; // 32 bit int

function ClearSymbolStatus(symbolName:PChar):boolean;stdcall;
function PostSymbolStatus(symbolName:PChar;lots:double;isLong:integer; isShort:integer; pyramidBase: double; renkoPyramidPips: double): PChar; stdcall;
function GetSymbolStatus(symbolName:PChar; var longOrShort:TIPair;var lotsPyramidBaseAndPips:TD_Terna):boolean;stdcall;

function setGridMode(symbolName:PChar;isMaster:integer;gridMode:PChar):boolean;stdcall;
function getGridMode(symbolName:PChar;isMaster:integer):PChar;stdcall;

function getAntiGridOptions(symbolName:PChar;isMaster:integer;var distant:tiPair):boolean;stdcall;
function setAntiGridOptions(symbolName:PChar;isMaster:integer;isDistant:integer;allowReenter:integer):boolean;stdcall;

function setGridOptions(symbolName:PChar;enable:integer;gridBottom:double;gridTop:double):boolean;stdcall;
function getGridOptions(symbolName:PChar;var enable:tiPair;var bottomAndTop:TD_Terna):boolean;stdcall;

function setExposure(symbolName:PChar;isMaster:integer;exposureLots:double):boolean;stdcall;
function getExposure(symbolName:PChar;isMaster:integer):double;stdcall;

function getBalance_NAV_UsedMargin(isMaster:integer;var balance:double;var NAV:double;var usedMargin:double):boolean;stdcall;
function setBalance_NAV_UsedMargin(isMaster:integer;balance:double;NAV:double;usedMargin:double):boolean;stdcall;

function getMultiplierForMicroLot(symbolName:PChar):integer;stdcall;
function setMultiplierForMicroLot(symbolName:PChar;multiplier:integer):boolean;stdcall;

function setProfits(symbolName:PChar;isMaster:integer;profits:double):boolean;stdcall;
function getProfits(symbolName:PChar;isMaster:integer):double;stdcall;

function setCloseOpenTrades(symbolName:PChar;isMaster:integer;isClose:integer):boolean;stdcall;
function getCloseOpenTrades(symbolName:PChar;isMaster:integer):boolean;stdcall;

implementation

uses
  Classes, SysUtils, Registry; // ,Dialogs;

function appendMasterTagToSymbolName(isMaster:integer;symbolName:PChar):ansistring;
begin
     if (isMaster<>0) then result:=AnsiString(symbolName)+'_MASTER'
     else result:=AnsiString(symbolName);
end;

function setCloseOpenTrades(symbolName:PChar;isMaster:integer;isClose:integer):boolean;stdcall;
var entry:ansistring;
begin
   With TRegistry.Create do
   try
      RootKey:=HKEY_CURRENT_USER;
      entry:=appendMasterTagToSymbolName(isMaster,symbolName);
      if OpenKey('Software\VB and VBA Program Settings\MT4Channel\CloseOpenTrades',true) then
         WriteInteger(entry,isClose);
      finally
         free;
      end;
   result:=true;
end;

function getCloseOpenTrades(symbolName:PChar;isMaster:integer):boolean;stdcall;
var entry:ansistring;
    resInteger:integer;
begin
     result:=false; // default
     With TRegistry.Create do
       try
         RootKey:=HKEY_CURRENT_USER;
         entry:=appendMasterTagToSymbolName(isMaster,symbolName);
         If OpenKeyReadOnly('Software\VB and VBA Program Settings\MT4Channel\CloseOpenTrades') then
         If ValueExists(entry) then
         begin
            resInteger:=ReadInteger(entry);
            if (resInteger<>0) then result:=true;
         end;
       finally
         free;
       end;
end;

function setProfits(symbolName:PChar;isMaster:integer;profits:double):boolean;stdcall;
var entry:ansistring;
begin
   With TRegistry.Create do
   try
      RootKey:=HKEY_CURRENT_USER;
      entry:=appendMasterTagToSymbolName(isMaster,symbolName);
      if OpenKey('Software\VB and VBA Program Settings\MT4Channel\Profits',true) then
         WriteFloat(entry,profits);
      finally
         free;
      end;
   result:=true;
end;

function getProfits(symbolName:PChar;isMaster:integer):double;stdcall;
var entry:ansistring;
begin
     result:=0; // default
     With TRegistry.Create do
       try
         RootKey:=HKEY_CURRENT_USER;
         entry:=appendMasterTagToSymbolName(isMaster,symbolName);
         If OpenKeyReadOnly('Software\VB and VBA Program Settings\MT4Channel\Profits') then
         If ValueExists(entry) then result:=ReadFloat(entry);
       finally
         free;
       end;
end;

function setExposure(symbolName:PChar;isMaster:integer;exposureLots:double):boolean;stdcall;
var entry:ansistring;
begin
   With TRegistry.Create do
   try
      RootKey:=HKEY_CURRENT_USER;
      entry:=appendMasterTagToSymbolName(isMaster,symbolName);
      if OpenKey('Software\VB and VBA Program Settings\MT4Channel\Exposure',true) then
         WriteFloat(entry,exposureLots);
      finally
         free;
      end;
   result:=true;
end;

function getExposure(symbolName:PChar;isMaster:integer):double;stdcall;
var entry:ansistring;
begin
     result:=0; // default
     With TRegistry.Create do
       try
         RootKey:=HKEY_CURRENT_USER;
         entry:=appendMasterTagToSymbolName(isMaster,symbolName);
         If OpenKeyReadOnly('Software\VB and VBA Program Settings\MT4Channel\Exposure') then
         If ValueExists(entry) then result:=ReadFloat(entry);
       finally
         free;
       end;
end;

function setMultiplierForMicroLot(symbolName:PChar;multiplier:integer):boolean;stdcall;
var entry:ansistring;
begin
   With TRegistry.Create do
   try
      RootKey:=HKEY_CURRENT_USER;
      entry:=AnsiString(symbolName);
      if OpenKey('Software\VB and VBA Program Settings\MT4Channel\MultipliersForMicroLots',true) then
         WriteInteger(entry,multiplier);
      finally
         free;
      end;
   result:=true;
end;

function getMultiplierForMicroLot(symbolName:PChar):integer;stdcall;
var entry:ansistring;
begin
     result:=1; // default
     With TRegistry.Create do
       try
         RootKey:=HKEY_CURRENT_USER;
         entry:=AnsiString(symbolName);
         If OpenKeyReadOnly('Software\VB and VBA Program Settings\MT4Channel\MultipliersForMicroLots') then
         If ValueExists(entry) then result:=ReadInteger(entry);
       finally
         free;
       end;
end;


function getBalance_NAV_UsedMargin(isMaster:integer;var balance:double;var NAV:double;var usedMargin:double):boolean;stdcall;
var
   list:TStringList;
   i:integer;
   s:string;
   entry:ansistring;
begin
  if (isMaster<>0) then entry := 'BalanceAndNAV_Master'
  else entry := 'BalanceAndNAV_Slave';
  With TRegistry.Create do
       try
         RootKey:=HKEY_CURRENT_USER;
         If OpenKeyReadOnly('Software\VB and VBA Program Settings\MT4Channel\BalanceAndNAV') then
         If ValueExists(entry) then
            s:=ReadString(entry); // Or whatever it is. ReadInteger/ReadBool
       finally
         free;
       end;
  list := TStringList.Create;
  list.Delimiter := ';';
  list.StrictDelimiter:=true;
  list.DelimitedText:=s;

  result:=false;
  if (list.Count=3) then
  begin
         for i:=0 to list.Count-1 do
         begin
              case i of
              0: Balance := strToFloat(list.valueFromIndex[i]);  // Balance
              1: NAV := strToFloat(list.ValueFromIndex[i]);  // NAV
              2: UsedMargin := strToFloat(list.ValueFromIndex[i]);  // UsedMargin
              end;
              // Writeln(list.ValueFromIndex[i]);
         end;
         result:=true;
  end;


  // Writeln(list.Count);

  list.free;
end;

function setBalance_NAV_UsedMargin(isMaster:integer;Balance:double;NAV:double;usedMargin:double):boolean;stdcall;
var
     s :ansistring; // reference counted and memory managed strings.
     entry:ansistring;
begin
    // our PChar will be copied into an ansistring automatically,
    // no need to worry about the ugly details of memory allocation.
    // s := 'Hello ' + FloatToStr(symbolName) + ' ' + y + '!';
    s := FloatToStr(Balance)+';'+
         FloatToStr(NAV)+';'+
         FloatToStr(UsedMargin);
    // cast it back into a pointer. Metatrader will copy the
    // string from the pointer into it's own memory.
    if (isMaster<>0) then entry := 'BalanceAndNAV_Master'
    else entry := 'BalanceAndNAV_Slave';
    With TRegistry.Create do
         try
            RootKey:=HKEY_CURRENT_USER;
            if OpenKey('Software\VB and VBA Program Settings\MT4Channel\BalanceAndNAV',true) then
            WriteString(entry,s);
         finally
            free;
         end;

    result := true;
end;

function setAntiGridOptions(symbolName:PChar;isMaster:integer;isDistant:integer;allowReenter:integer):boolean;stdcall;
var entry:ansistring;
begin
   entry:=appendMasterTagToSymbolName(isMaster,symbolName);
   With TRegistry.Create do
   try
      RootKey:=HKEY_CURRENT_USER;
      if OpenKey('Software\VB and VBA Program Settings\MT4Channel\AntiGridOption_Distant',true) then
         WriteInteger(entry,isDistant);
      finally
         free;
      end;
   With TRegistry.Create do
   try
      RootKey:=HKEY_CURRENT_USER;
      if OpenKey('Software\VB and VBA Program Settings\MT4Channel\AntiGridOption_AllowReenter',true) then
         WriteInteger(entry,allowReenter)
      finally
         free;
      end;
   result:=true;
end;

function getAntiGridOptions(symbolName:PChar;isMaster:integer;var distant:tiPair):boolean;stdcall;
var entry:ansistring;
begin
     result:=false;
     distant[0]:=1;
     distant[1]:=0;
     entry:=appendMasterTagToSymbolName(isMaster,symbolName);
     With TRegistry.Create do
       try
         RootKey:=HKEY_CURRENT_USER;
         If OpenKeyReadOnly('Software\VB and VBA Program Settings\MT4Channel\AntiGridOption_Distant') then
         If ValueExists(entry) then
         begin
            distant[0] := ReadInteger(entry);
            result:=true; // Or whatever it is. ReadInteger/ReadBool
         end;
       finally
         free;
       end;


     With TRegistry.Create do
       try
         RootKey:=HKEY_CURRENT_USER;
         If OpenKeyReadOnly('Software\VB and VBA Program Settings\MT4Channel\AntiGridOption_AllowReenter') then
         If ValueExists(entry) then
         begin
              distant[1] := ReadInteger(entry);
              result:=true; // Or whatever it is. ReadInteger/ReadBool
         end;
       finally
         free;
       end;
end;

// R = RENKOASHI WITH SUPPORT / RESISTANCE BREAKOUT, OR RENKO SLAVE
// G
// AG = ANTI GRID
function setGridMode(symbolName:PChar;isMaster:integer;gridMode:PChar):boolean;stdcall;
var entry:ansistring;
begin
   With TRegistry.Create do
   try
      RootKey:=HKEY_CURRENT_USER;
      entry:=appendMasterTagToSymbolName(isMaster,symbolName);
      if OpenKey('Software\VB and VBA Program Settings\MT4Channel\GridMode',true) then
         WriteString(entry,gridMode);
      finally
         free;
      end;
   result:=true;
end;

function getGridMode(symbolName:PChar;isMaster:integer):PChar;stdcall;
var
   entry:ansistring;
begin
  result:=PChar('');
  With TRegistry.Create do
       try
         RootKey:=HKEY_CURRENT_USER;
         entry:=appendMasterTagToSymbolName(isMaster,symbolName);
         If OpenKeyReadOnly('Software\VB and VBA Program Settings\MT4Channel\GridMode') then
         If ValueExists(entry) then
            result:=PChar(ReadString(entry)); // Or whatever it is. ReadInteger/ReadBool
       finally
         free;
       end;
end;

function ClearSymbolStatus(symbolName:PChar):boolean;stdcall;
begin
   With TRegistry.Create do
   try
      RootKey:=HKEY_CURRENT_USER;
      if OpenKey('Software\VB and VBA Program Settings\MT4Channel',true) then
         WriteString(symbolName,'');
      finally
         free;
      end;
   result:=true;
end;

// strings from and to Metatrader will always be passed
// as PChar which is a pointer to a nullterminated C-string.
function PostSymbolStatus(symbolName:PChar;lots:double;isLong:integer; isShort:integer; pyramidBase: double; renkoPyramidPips: double): PChar; stdcall;
var
  s :ansistring; // reference counted and memory managed strings.
begin
  // our PChar will be copied into an ansistring automatically,
  // no need to worry about the ugly details of memory allocation.
  // s := 'Hello ' + FloatToStr(symbolName) + ' ' + y + '!';
  s := FloatToStr(lots)+';'+
       IntToStr(isLong)+';'+
       IntToStr(isShort)+';'+
       FloatToStr(pyramidBase)+';'+
       FloatToStr(renkoPyramidPips);
  // cast it back into a pointer. Metatrader will copy the
  // string from the pointer into it's own memory.

  With TRegistry.Create do
       try
          RootKey:=HKEY_CURRENT_USER;
          if OpenKey('Software\VB and VBA Program Settings\MT4Channel',true) then
          WriteString(symbolName,s);
       finally
          free;
       end;

  result := PChar(s);
end;

function GetSymbolStatus(symbolName:PChar; var longOrShort:TIPair;var lotsPyramidBaseAndPips:TD_Terna):boolean;stdcall;
var
   list:TStringList;
   i:integer;
   s:string;
begin
  With TRegistry.Create do
       try
         RootKey:=HKEY_CURRENT_USER;
         If OpenKeyReadOnly('Software\VB and VBA Program Settings\MT4Channel') then
         If ValueExists(symbolName) then
            s:=ReadString(symbolName); // Or whatever it is. ReadInteger/ReadBool
       finally
         free;
       end;
  ClearSymbolStatus(symbolName);
  list := TStringList.Create;
  list.Delimiter := ';';
  list.StrictDelimiter:=true;
  list.DelimitedText:=s;

  result:=false;
  if (list.Count=5) then
  begin
         for i:=0 to list.Count-1 do
         begin
              case i of
              0: lotsPyramidBaseAndPips[0] := strToFloat(list.valueFromIndex[i]);
              1: longOrShort[0] := strToInt(list.ValueFromIndex[i]);          // isLong
              2: longOrShort[1] := strToInt(list.ValueFromIndex[i]);          // isShort
              3: lotsPyramidBaseAndPips[1] := strToFloat(list.valueFromIndex[i]); // pyramidBase
              4: lotsPyramidBaseAndPips[2] := strToFloat(list.valueFromIndex[i]); // pyramidPips
              end;
              // Writeln(list.ValueFromIndex[i]);
         end;
         result:=true;
  end;


  // Writeln(list.Count);

  list.free;

end;

function setGridOptions(symbolName:PChar;enable:integer;gridBottom:double;gridTop:double):boolean;stdcall;
var
   entry:ansistring;
   s :ansistring; // reference counted and memory managed strings.
begin
    entry:=appendMasterTagToSymbolName(0,symbolName);

    s := IntToStr(enable)+';'+
         FloatToStr(gridBottom)+';'+
         FloatToStr(gridTop);

    With TRegistry.Create do
         try
            RootKey:=HKEY_CURRENT_USER;
            if OpenKey('Software\VB and VBA Program Settings\MT4Channel\GridOptions',true) then
            WriteString(entry,s);
         finally
            free;
         end;

    result := true;
end;

function getGridOptions(symbolName:PChar;var enable:tiPair;var bottomAndTop:TD_Terna):boolean;stdcall;
var
   entry:ansistring;
   list:TStringList;
   i:integer;
   s:string;
begin
   entry:=appendMasterTagToSymbolName(0,symbolName);

   With TRegistry.Create do
       try
         RootKey:=HKEY_CURRENT_USER;
         If OpenKeyReadOnly('Software\VB and VBA Program Settings\MT4Channel\GridOptions') then
         If ValueExists(entry) then
            s:=ReadString(entry); // Or whatever it is. ReadInteger/ReadBool
       finally
         free;
       end;

  // ShowMessage(s);

  list := TStringList.Create;
  list.Delimiter := ';';
  list.StrictDelimiter:=true;
  list.DelimitedText:=s;

  result:=false;
  if (list.Count=3) then
  begin
         for i:=0 to list.Count-1 do
         begin
              case i of
              0: enable[0] := strToInt(list.valueFromIndex[i]);
              1: bottomAndTop[0] := strToFloat(list.ValueFromIndex[i]);          // gridBottom
              2: bottomAndTop[1] := strToFloat(list.ValueFromIndex[i]);          // gridTop
              end;
              // Writeln(list.ValueFromIndex[i]);
         end;
         result:=true;
  end;


  // Writeln(list.Count);

  list.free;
end;

end.

