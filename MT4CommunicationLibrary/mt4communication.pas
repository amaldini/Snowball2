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

function getGridOptions(symbolName:PChar;isMaster:integer;var distant:tiPair):boolean;stdcall;
function setGridOptions(symbolName:PChar;isMaster:integer;isDistant:integer):boolean;stdcall;

function getEquity_NAV_UsedMargin(isMaster:integer;var equity:double;var NAV:double;var usedMargin:double):boolean;stdcall;
function setEquity_NAV_UsedMargin(isMaster:integer;equity:double;NAV:double;usedMargin:double):boolean;stdcall;

implementation

uses
  Classes, SysUtils, Registry; // ,Dialogs;


function getEquity_NAV_UsedMargin(isMaster:integer;var Equity:double;var NAV:double;var usedMargin:double):boolean;stdcall;
var
   list:TStringList;
   i:integer;
   s:string;
   entry:ansistring;
begin
  if (isMaster<>0) then entry := 'EquityAndNAV_Master'
  else entry := 'EquityAndNAV_Slave';
  With TRegistry.Create do
       try
         RootKey:=HKEY_CURRENT_USER;
         If OpenKeyReadOnly('Software\VB and VBA Program Settings\MT4Channel\EquityAndNAV') then
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
              0: Equity := strToFloat(list.valueFromIndex[i]);  // Equity
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

function setEquity_NAV_UsedMargin(isMaster:integer;Equity:double;NAV:double;usedMargin:double):boolean;stdcall;
var
     s :ansistring; // reference counted and memory managed strings.
     entry:ansistring;
begin
    // our PChar will be copied into an ansistring automatically,
    // no need to worry about the ugly details of memory allocation.
    // s := 'Hello ' + FloatToStr(symbolName) + ' ' + y + '!';
    s := FloatToStr(Equity)+';'+
         FloatToStr(NAV)+';'+
         FloatToStr(UsedMargin);
    // cast it back into a pointer. Metatrader will copy the
    // string from the pointer into it's own memory.
    if (isMaster<>0) then entry := 'EquityAndNAV_Master'
    else entry := 'EquityAndNAV_Slave';
    With TRegistry.Create do
         try
            RootKey:=HKEY_CURRENT_USER;
            if OpenKey('Software\VB and VBA Program Settings\MT4Channel\EquityAndNAV',true) then
            WriteString(entry,s);
         finally
            free;
         end;

    result := true;
end;

function appendMasterTagToSymbolName(isMaster:integer;symbolName:PChar):ansistring;
begin
     if (isMaster<>0) then result:=AnsiString(symbolName)+'_MASTER'
     else result:=AnsiString(symbolName);
end;

function setGridOptions(symbolName:PChar;isMaster:integer;isDistant:integer):boolean;stdcall;
var entry:ansistring;
begin
   With TRegistry.Create do
   try
      RootKey:=HKEY_CURRENT_USER;
      entry:=appendMasterTagToSymbolName(isMaster,symbolName);
      if OpenKey('Software\VB and VBA Program Settings\MT4Channel\GridOption_Distant',true) then
         WriteInteger(entry,isDistant);
      finally
         free;
      end;
   result:=true;
end;

function getGridOptions(symbolName:PChar;isMaster:integer;var distant:tiPair):boolean;stdcall;
var entry:ansistring;
begin
     result:=false;
     With TRegistry.Create do
       try
         RootKey:=HKEY_CURRENT_USER;
         entry:=appendMasterTagToSymbolName(isMaster,symbolName);
         If OpenKeyReadOnly('Software\VB and VBA Program Settings\MT4Channel\GridOption_Distant') then
         If ValueExists(entry) then
            distant[0] := ReadInteger(entry);
            result:=true; // Or whatever it is. ReadInteger/ReadBool
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

end.

