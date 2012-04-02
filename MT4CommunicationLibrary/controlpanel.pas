unit ControlPanel;

{$mode objfpc}{$H+}

interface

uses
  Classes, SysUtils, FileUtil, Forms, Controls, Graphics, Dialogs, ExtCtrls,
  StdCtrls, ComCtrls, Menus, mt4communication;

type

  { TForm1 }

  TForm1 = class(TForm)
    Button1: TButton;
    btnCloseLong: TButton;
    btnCloseShort: TButton;
    ButtonCloseAll: TButton;
    MainMenu1: TMainMenu;
    GridDistance: TMenuItem;
    GroupBox1: TGroupBox;
    GroupBox2: TGroupBox;
    Label1: TLabel;
    lblStatsAccount1: TLabel;
    lblStatsAccount2: TLabel;
    lblTotals: TLabel;
    ListBox1: TListBox;
    LongWait: TRadioButton;
    LongGrid: TRadioButton;
    LongAntiGrid: TRadioButton;
    LongDistant: TMenuItem;
    ShortDistant: TMenuItem;
    ShortWait: TRadioButton;
    ShortGrid: TRadioButton;
    ShortAntiGrid: TRadioButton;
    StatusBar1: TStatusBar;
    Timer1: TTimer;
    procedure Button1Click(Sender: TObject);
    procedure btnCloseLongClick(Sender: TObject);
    procedure btnCloseShortClick(Sender: TObject);
    procedure ButtonCloseAllClick(Sender: TObject);
    procedure FormCreate(Sender: TObject);
    procedure ListBox1Click(Sender: TObject);
    procedure LongDistantClick(Sender: TObject);
    procedure ShortDistantClick(Sender: TObject);
    procedure Timer1Timer(Sender: TObject);

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
    distant:TIPair;
    boolValue:boolean;
begin
  GroupBox1.Enabled:=true;
  GroupBox2.Enabled:=true;

  symbol:=PChar(listbox1.getSelectedText);

  isMaster:=1;
  mode:=getGridMode(symbol,isMaster);
  if ((mode='W') or (mode='') or (mode='CLOSE')) then longWait.Checked:=true;
  if (mode='G') then longGrid.Checked:=true;
  if (mode='A') then longAntiGrid.Checked:=true;

  isMaster:=0;
  mode:=getGridMode(symbol,isMaster);
  if ((mode='W') or (mode='') or (mode='CLOSE')) then shortWait.Checked:=true;
  if (mode='G') then shortGrid.Checked:=true;
  if (mode='A') then shortAntiGrid.Checked:=true;

  boolValue:=false;
  if (getGridOptions(symbol,1,distant)) then
  begin
       if (distant[0]<>0) then boolValue:=true;
  end;
  longDistant.checked:=boolValue;

  boolValue:=false;
  if (getGridOptions(symbol,0,distant)) then
  begin
       if (distant[0]<>0) then boolValue:=true;
  end;
  shortDistant.checked:=boolValue;
end;

function getSelectedSymbol():PChar;
begin
     result:=PChar(form1.listbox1.getSelectedText);
end;

procedure TForm1.LongDistantClick(Sender: TObject);
var symbol:pchar;
    isDistant:integer;
begin
     if (form1.ListBox1.ItemIndex>=0) then
     begin
       symbol:=getSelectedSymbol();
       LongDistant.Checked:=not longDistant.Checked;
       isDistant:=0;
       if (longDistant.checked) then isDistant:=1;
       setGridOptions(symbol,1,isDistant);
     end;
end;

procedure TForm1.ShortDistantClick(Sender: TObject);
var symbol:pchar;
    isDistant:integer;
begin
     if (form1.listbox1.itemindex>=0) then
     begin
       symbol:=getSelectedSymbol();
       ShortDistant.checked := not shortDistant.checked;
       isDistant:=0;
       if (shortDistant.checked) then isDistant:=1;
       setGridOptions(symbol,0,isDistant);
     end;
end;

procedure TForm1.Timer1Timer(Sender: TObject);
var Balance1,nav1,usedmargin1:double;
    Balance2,nav2,usedmargin2:double;
begin
     Balance1:=0; nav1:=0; usedMargin1:=0;
     Balance2:=0; nav2:=0; usedMargin2:=0;
     if (getBalance_NAV_UsedMargin(1,Balance1,nav1,usedMargin1)) then
        lblStatsAccount1.caption :=
                                 floatToStr(Balance1)+sLineBreak+
                                 sLineBreak+
                                 floatToStr(nav1)+sLineBreak+
                                 sLineBreak+
                                 floatToStr(usedMargin1);
     if (getBalance_NAV_UsedMargin(0,Balance2,nav2,usedMargin2)) then
        lblStatsAccount2.caption :=
                                 floatToStr(Balance2)+sLineBreak+
                                 sLineBreak+
                                 floatToStr(nav2)+sLineBreak+
                                 sLineBreak+
                                 floatToStr(usedMargin2);
     lblTotals.caption :=
                                 floatToStr(Balance1+Balance2)+sLineBreak+
                                 sLineBreak+
                                 floatToStr(nav1+nav2)+sLineBreak+
                                 sLineBreak+
                                 floatToStr(usedMargin1+usedMargin2);

end;

procedure TForm1.Button1Click(Sender: TObject);
var isMaster:integer;
    symbol:PChar;
    masterMode:PChar;
    slaveMode:PChar;
begin
  symbol:=getSelectedSymbol();

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

procedure TForm1.btnCloseLongClick(Sender: TObject);
var symbol:ansistring;
    isMaster:integer;
begin
  isMaster:=1;
  symbol:=getSelectedSymbol();
  setGridMode(PChar(symbol),isMaster,'CLOSE');
  longWait.checked :=true;
  statusbar1.SimpleText :='Close command issued for '+symbol+' MASTER';
end;

procedure TForm1.btnCloseShortClick(Sender: TObject);
var symbol:ansistring;
    isMaster:integer;
begin
  isMaster:=0;
  symbol:=getSelectedSymbol();
  setGridMode(PChar(symbol),isMaster,'CLOSE');
  shortWait.checked:=true;
  statusbar1.SimpleText :='Close command issued for '+symbol+' SLAVE';
end;

procedure TForm1.ButtonCloseAllClick(Sender: TObject);
var i:integer;
    symbol:ansistring;
begin
     for i := 0 to listbox1.count-1 do
     begin
          symbol:=listbox1.items[i];
          setGridMode(PChar(symbol),0,'CLOSE');
          setGridMode(PChar(symbol),1,'CLOSE');
     end;
     longWait.checked:=true;
     shortWait.checked:=true;
     statusbar1.SimpleText:='Close All command issued.';
end;

procedure TForm1.FormCreate(Sender: TObject);
begin
     setBalance_NAV_UsedMargin(0,-1,-1,-1);
     setBalance_NAV_UsedMargin(1,-1,-1,-1);
end;

end.

