//{$define TESTING}

{$IFDEF TESTING}
program MT4Library;
{$ELSE}
library MT4Library;
{$ENDIF}

{$mode objfpc}{$H+}

uses
  sysutils,registry,Classes,MT4Communication;

exports
  PostSymbolStatus,
  GetSymbolStatus,
  ClearSymbolStatus,
  getGridMode;

{$IFDEF TESTING}

var a:TIPair;
   b:TD_Terna;
   r:boolean;
   i:integer;
begin
  for i:=1 to 10 do
  begin
    Writeln('');
    Writeln('Iteration #'+IntToStr(i));
    PostSymbolStatus('EURUSD',0.01,0,0,1.30,20);
    r:= GetSymbolStatus('EURUSD',a,b);
    Writeln('GetSymbolStatus: '+BoolToStr(r));
    Writeln(a[0]);
    Writeln(a[1]);
    Writeln(b[0]);
    Writeln(b[1]);
    Writeln(b[2]);
    r:= GetSymbolStatus('EURUSD',a,b);
    Writeln('GetSymbolStatus: '+BoolToStr(r));
  end;

  Writeln('setGridMode/getGridMode TEST:');
  setGridMode('EURUSDtest',1,'TEST OK!');
  Writeln(getGridMode('EURUSDTest',1));
  readln;
end.
{$ELSE}

begin
end.

{$ENDIF}

