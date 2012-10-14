// {$define TESTING}

{$IFDEF TESTING}
program MT4Library;
{$ELSE}
library MT4Library;
{$ENDIF}

{$mode objfpc}{$H+}

uses
  sysutils,registry,Classes,MT4Communication;

exports
  setCmd,getCmd;

{$IFDEF TESTING}

var a:TIPair;
   b:TD_Terna;
   i:integer;

   balance,nav,usedMargin:double;
begin

    setCmd('EURUSD',0,'Test');

    Writeln('getCmd: '+getCmd('EURUSD',0));


  readln;
end.
{$ELSE}

begin
end.

{$ENDIF}

