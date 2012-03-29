unit ControlPanel;

{$mode objfpc}{$H+}

interface

uses
  Classes, SysUtils, FileUtil, Forms, Controls, Graphics, Dialogs, ExtCtrls,
  StdCtrls, ComCtrls, Grids, mt4communication;

type

  { TForm1 }

  TForm1 = class(TForm)
    Button1: TButton;
    GroupBox1: TGroupBox;
    GroupBox2: TGroupBox;
    ListBox1: TListBox;
    LongWait: TRadioButton;
    LongGrid: TRadioButton;
    LongAntiGrid: TRadioButton;
    ShortWait: TRadioButton;
    ShortGrid: TRadioButton;
    ShortAntiGrid: TRadioButton;
    StatusBar1: TStatusBar;
    procedure Button1Click(Sender: TObject);
    procedure ListBox1Click(Sender: TObject);

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


procedure TForm1.ListBox1Click(Sender: TObject);
var symbol:PChar;
    isMaster:integer;
    mode:PChar;
begin
  GroupBox1.Enabled:=true;
  GroupBox2.Enabled:=true;

  symbol:=PChar(listbox1.getSelectedText);

  isMaster:=1;
  mode:=getGridMode(symbol,isMaster);
  if ((mode='W') or (mode='')) then longWait.Checked:=true;
  if (mode='G') then longGrid.Checked:=true;
  if (mode='A') then longAntiGrid.Checked:=true;

  isMaster:=0;
  mode:=getGridMode(symbol,isMaster);
  if ((mode='W') or (mode='')) then shortWait.Checked:=true;
  if (mode='G') then shortGrid.Checked:=true;
  if (mode='A') then shortAntiGrid.Checked:=true;
end;

procedure TForm1.Button1Click(Sender: TObject);
var isMaster:integer;
    symbol:PChar;
    masterMode:PChar;
    slaveMode:PChar;
begin
  symbol:=PChar(listbox1.getSelectedText);

  masterMode:=''; slaveMode:='';

  isMaster:=1;
  if (longWait.Checked) then masterMode:='W';
  if (longGrid.Checked) then masterMode:='G';
  if (longAntiGrid.Checked) then masterMode:='A';
  setGridMode(symbol,isMaster,masterMode);

  isMaster:=0;
  if (shortWait.Checked) then slaveMode:='W';
  if (shortGrid.Checked) then slaveMode:='G';
  if (shortAntiGrid.Checked) then slaveMode:='A';
  setGridMode(symbol,isMaster,PChar(slaveMode));

  StatusBar1.SimpleText :=
                        'Changes applied to '+listbox1.GetSelectedText+' '+
                        masterMode+'/'+slaveMode;
end;

end.

