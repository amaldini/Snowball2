unit MT4Communication;

{$mode objfpc}{$H+}

interface

type
  TD_Terna = array[0..2] of double;
  TIPair = array[0..1] of LongInt; // 32 bit int

function ClearSymbolStatus(symbolName:PChar):boolean;stdcall;
function PostSymbolStatus(symbolName:PChar;lots:double;isLong:integer; isShort:integer; pyramidBase: double; renkoPyramidPips: double): PChar; stdcall;
function GetSymbolStatus(symbolName:PChar; var longOrShort:TIPair;var lotsPyramidBaseAndPips:TD_Terna):boolean;stdcall;

function setGridMode(symbolName:PChar;isMaster:integer;gridMode:PChar):boolean;
function getGridMode(symbolName:PChar;isMaster:integer):PChar;stdcall;

function getBalance_NAV_UsedMargin(isMaster:integer;var balanceAndNAV:TD_Terna):boolean;stdcall;
function setBalance_NAV_UsedMargin(isMaster:integer;balance:double;NAV:double;usedMargin:double):boolean;stdcall;

implementation

uses
  Classes, SysUtils, Registry;


function getBalance_NAV_UsedMargin(isMaster:integer;var balanceAndNAV:TD_Terna):boolean;stdcall;
begin
end;

function setBalance_NAV_UsedMargin(isMaster:integer;balance:double;NAV:double;usedMargin:double):boolean;stdcall;
var
     s :ansistring; // reference counted and memory managed strings.
     entry:ansistring;
begin
    // our PChar will be copied into an ansistring automatically,
    // no need to worry about the ugly details of memory allocation.
    // s := 'Hello ' + FloatToStr(symbolName) + ' ' + y + '!';
    s := FloatToStr(balance)+';'+
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


// R = RENKOASHI WITH SUPPORT / RESISTANCE BREAKOUT, OR RENKO SLAVE
// G
// AG = ANTI GRID
function setGridMode(symbolName:PChar;isMaster:integer;gridMode:PChar):boolean;
begin
   With TRegistry.Create do
   try
      RootKey:=HKEY_CURRENT_USER;
      if (isMaster<>0) then symbolName:=PChar(symbolName+'_MASTER');
      if OpenKey('Software\VB and VBA Program Settings\MT4Channel\GridMode',true) then
         WriteString(symbolName,gridMode);
      finally
         free;
      end;
   result:=true;
end;

function getGridMode(symbolName:PChar;isMaster:integer):PChar;stdcall;
begin
  result:=PChar('');
  With TRegistry.Create do
       try
         RootKey:=HKEY_CURRENT_USER;
         if (isMaster<>0) then symbolName:=PChar(symbolName+'_MASTER');
         If OpenKeyReadOnly('Software\VB and VBA Program Settings\MT4Channel\GridMode') then
         If ValueExists(symbolName) then
            result:=PChar(ReadString(symbolName)); // Or whatever it is. ReadInteger/ReadBool
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

