unit MT4Communication;

{$mode objfpc}{$H+}

interface

type
  TD_Terna = array[0..2] of double;
  TIPair = array[0..1] of LongInt; // 32 bit int

function setCmd(symbolName:PChar;isMaster:integer;cmd:PChar):boolean;stdcall;
function getCmd(symbolName:PChar;isMaster:integer):PChar;stdcall;

implementation

uses
  Classes, SysUtils, Registry; // ,Dialogs;

function appendMasterTagToSymbolName(isMaster:integer;symbolName:PChar):ansistring;
begin
     if (isMaster<>0) then result:=AnsiString(symbolName)+'_MASTER'
     else result:=AnsiString(symbolName);
end;

// cmd==rebalance...
function setCmd(symbolName:PChar;isMaster:integer;cmd:PChar):boolean;stdcall;
var entry:ansistring;
begin
   With TRegistry.Create do
   try
      RootKey:=HKEY_CURRENT_USER;
      entry:=appendMasterTagToSymbolName(isMaster,symbolName);
      if OpenKey('Software\VB and VBA Program Settings\MT4Channel\Cmd',true) then
         WriteString(entry,cmd);
      finally
         free;
      end;
   result:=true;
end;

function getCmd(symbolName:PChar;isMaster:integer):PChar;stdcall;
var
   entry:ansistring;
begin
  result:=PChar('');
  With TRegistry.Create do
       try
         RootKey:=HKEY_CURRENT_USER;
         entry:=appendMasterTagToSymbolName(isMaster,symbolName);
         If OpenKeyReadOnly('Software\VB and VBA Program Settings\MT4Channel\Cmd') then
         If ValueExists(entry) then
            result:=PChar(ReadString(entry)); // Or whatever it is. ReadInteger/ReadBool
       finally
         free;
       end;
end;


end.

