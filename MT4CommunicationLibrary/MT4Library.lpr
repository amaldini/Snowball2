// {$define TESTING}

{$IFDEF TESTING}
program MT4Library;
{$ELSE}
library MT4Library;
{$ENDIF}

{$mode objfpc}{$H+}

uses
  sysutils,registry,Classes;

type
  TDPair = array[0..1] of double;
  TIPair = array[0..1] of LongInt; // 32 bit int

// function parameters declared as var will accept pointers.
procedure VarsByReference(var a: TDPair; var b: TIPair); stdcall;
begin
  // now let's make some changes to the variables
  a[0] += a[1];
  a[1] -= a[0];
  b[0] += b[1];
  b[1] -= b[0];
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
function PostSymbolStatus(symbolName:PChar; isLong:integer; isShort:integer; pyramidBase: double; renkoPyramidPips: double): PChar; stdcall;
var
  s :ansistring; // reference counted and memory managed strings.
begin
  // our PChar will be copied into an ansistring automatically,
  // no need to worry about the ugly details of memory allocation.
  // s := 'Hello ' + FloatToStr(symbolName) + ' ' + y + '!';
  s := IntToStr(isLong)+';'+
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

function GetSymbolStatus(symbolName:PChar; var longOrShort:TIPair;var pyramidBaseAndPips:TDPair):boolean;stdcall;
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
  if (list.Count=4) then
  begin
         for i:=0 to list.Count-1 do
         begin
              case i of
              0: longOrShort[0] := strToInt(list.ValueFromIndex[i]);          // isLong
              1: longOrShort[1] := strToInt(list.ValueFromIndex[i]);          // isShort
              2: pyramidBaseAndPips[0] := strToFloat(list.valueFromIndex[i]); // pyramidBase
              3: pyramidBaseAndPips[1] := strToFloat(list.valueFromIndex[i]); // pyramidPips
              end;
              // Writeln(list.ValueFromIndex[i]);
         end;
         result:=true;
  end;


  // Writeln(list.Count);

  list.free;

end;

exports
  PostSymbolStatus,
  GetSymbolStatus,
  ClearSymbolStatus,
  VarsByReference; // esempio

{$IFDEF TESTING}

var a:TIPair;
   b:TDPair;
   r:boolean;
   i:integer;
begin
  for i:=1 to 1000 do
  begin
    Writeln('');
    Writeln('Iteration #'+IntToStr(i));
    PostSymbolStatus('EURUSD',false,false,1.30,20);
    r:= GetSymbolStatus('EURUSD',a,b);
    Writeln('GetSymbolStatus: '+BoolToStr(r));
    Writeln(a[0]);
    Writeln(a[1]);
    Writeln(b[0]);
    Writeln(b[1]);
    r:= GetSymbolStatus('EURUSD',a,b);
    Writeln('GetSymbolStatus: '+BoolToStr(r));
  end;
  readln;
end.
{$ELSE}

begin
end.

{$ENDIF}

