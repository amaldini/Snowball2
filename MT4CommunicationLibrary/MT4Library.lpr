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
  getGridMode,
  setGridMode,
  getBalance_NAV_UsedMargin,
  setBalance_NAV_UsedMargin,
  getGridOptions,
  getMultiplierForMicroLot,
  setMultiplierForMicroLot;

{$IFDEF TESTING}

var a:TIPair;
   b:TD_Terna;
   r:boolean;
   i:integer;

   balance,nav,usedMargin:double;
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
  setBalance_NAV_UsedMargin(1,100,90,10);
  if getBalance_NAV_UsedMargin(1,balance,nav,usedMargin) then
     Writeln('Balance:'+FloatToStr(balance)+' NAV:'+FloatToStr(nav)+' UsedMargin:'+FloatToStr(usedMargin));

  readln;
end.
{$ELSE}

begin
end.

{$ENDIF}

