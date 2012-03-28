unit ControlPanel;

{$mode objfpc}{$H+}

interface

uses
  Classes, SysUtils, FileUtil, Forms, Controls, Graphics, Dialogs, ExtCtrls,
  StdCtrls, ComCtrls, Grids, SynMemo;

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
begin
  GroupBox1.Enabled:=true;
  GroupBox2.Enabled:=true;
end;

procedure TForm1.Button1Click(Sender: TObject);
begin
  StatusBar1.SimpleText := 'Changes applied to '+listbox1.GetSelectedText;
end;

end.

