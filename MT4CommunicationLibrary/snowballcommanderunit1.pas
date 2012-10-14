unit SnowballCommanderUnit1; 

{$mode objfpc}{$H+}

interface

uses
  Classes, SysUtils, FileUtil, Forms, Controls, Graphics, Dialogs, StdCtrls,mt4communication;

type

  { TForm1 }

  TForm1 = class(TForm)
    Button1: TButton;
    ListBox1: TListBox;
    RadioButton1: TRadioButton;
    RadioButton2: TRadioButton;
    RadioButton3: TRadioButton;
    procedure Button1Click(Sender: TObject);
    procedure RadioButton1Change(Sender: TObject);
  private
    { private declarations }
  public
    { public declarations }
  end; 

var
  Form1: TForm1; 

implementation

{$R *.lfm}

{ TForm1 }


procedure TForm1.Button1Click(Sender: TObject);
var
   cmd: AnsiString;
   symbol: AnsiString;

begin
     if (ListBox1.ItemIndex>=0) then
     begin
        if (RadioButton1.Checked) then cmd := 'LONG' ;
        if (RadioButton2.Checked) then cmd := 'SHORT';
        if (RadioButton3.Checked) then cmd := 'PAUSE';

        symbol := ListBox1.GetSelectedText;

        setCmd(PChar(symbol),0,PChar(cmd));
     end;


end;

procedure TForm1.RadioButton1Change(Sender: TObject);
begin

end;

end.

