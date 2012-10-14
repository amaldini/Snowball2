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
    ButtonCalcTargetNAV: TButton;
    ButtonCloseAll: TButton;
    GridMenuItem: TMenuItem;
    GridSetTopPrice: TMenuItem;
    GridSetBottomPrice: TMenuItem;
    GridEnable: TMenuItem;
    MenuItem2: TMenuItem;
    BurstGridEnable: TMenuItem;
    mnuRebalance: TMenuItem;
    txtProfitTarget: TEdit;
    Label2: TLabel;
    lblTargetNAV: TLabel;
    lblProfits: TLabel;
    MainMenu1: TMainMenu;
    AntiGridOptions: TMenuItem;
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
    MenuItem1: TMenuItem;
    Lots001: TMenuItem;
    Lots002: TMenuItem;
    Lots003: TMenuItem;
    Lots004: TMenuItem;
    Lots005: TMenuItem;
    LongReenter: TMenuItem;
    ShortReenter: TMenuItem;
    ShortWait: TRadioButton;
    ShortGrid: TRadioButton;
    ShortAntiGrid: TRadioButton;
    StatusBar1: TStatusBar;
    Timer1: TTimer;
    procedure Button1Click(Sender: TObject);
    procedure btnCloseLongClick(Sender: TObject);
    procedure btnCloseShortClick(Sender: TObject);
    procedure ButtonCalcTargetNAVClick(Sender: TObject);
    procedure ButtonCloseAllClick(Sender: TObject);
    procedure FormCreate(Sender: TObject);
    procedure GridEnableClick(Sender: TObject);
    procedure GridSetBottomPriceClick(Sender: TObject);
    procedure Label2Click(Sender: TObject);
    procedure ListBox1Click(Sender: TObject);
    procedure Lots001Click(Sender: TObject);
    procedure Lots002Click(Sender: TObject);
    procedure Lots003Click(Sender: TObject);
    procedure Lots004Click(Sender: TObject);
    procedure Lots005Click(Sender: TObject);
    procedure LongReenterClick(Sender: TObject);
    procedure GridSetTopPriceClick(Sender: TObject);
    procedure BurstGridEnableClick(Sender: TObject);
    procedure mnuRebalanceClick(Sender: TObject);
    procedure ShortReenterClick(Sender: TObject);
    procedure Timer1Timer(Sender: TObject);

  private
    { private declarations }
  public
    { public declarations }
  end; 

var
  Form1: TForm1;
  currentNav:double;
  targetNav:double;

  gridBottom:double;
  gridTop:double;

implementation

{$R *.lfm}

{ TForm1 }

function getSelectedSymbol():PChar;
begin
     result:=PChar(form1.listbox1.getSelectedText);
end;

procedure updateGridTopAndBottom();
begin
     form1.GridSetBottomPrice.caption:='Set bottom price ('+FormatFloat('0.00000',gridBottom)+')';
     form1.GridSetTopPrice.caption:='Set top price ('+FormatFloat('0.00000',gridTop)+')';
end;

procedure loadGridOptions();
var
   enable:tiPair;
   bottomAndTop:TD_Terna;
   bEnable:boolean;
begin
     bEnable:=false;
     gridBottom:=0;
     gridTop:=0;
     if (getGridOptions(getSelectedSymbol(),enable,bottomAndTop)) then
     begin
          bEnable:=(enable[0]<>0);
          gridBottom:=bottomAndTop[0];
          gridTop:=bottomAndTop[1];
     end;
     Form1.gridEnable.checked:=bEnable;
     updateGridTopAndBottom();
end;

procedure loadBurstGridOptions();
var
   enable:tiPair;
   bEnable:boolean;
begin
     bEnable:=false;

     if (getBurstGridOptions(getSelectedSymbol(),enable)) then
     begin
          bEnable:=(enable[0]<>0);
     end;
     Form1.BurstGridEnable.checked:=bEnable;
end;

procedure TForm1.ListBox1Click(Sender: TObject);
var symbol:PChar;
    isMaster:integer;
    mode:PChar;
    distant:TIPair;
    boolValue:boolean;
    boolValue2:boolean;
    multiplierForMicroLot:integer;
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
  boolValue2:=false;
  if (getAntiGridOptions(symbol,1,distant)) then
  begin
       if (distant[0]<>0) then boolValue:=true;
       if (distant[1]<>0) then boolValue2:=true;
  end;
  // longDistant.checked:=boolValue;
  LongReenter.Checked:=boolValue2;

  boolValue:=false;
  boolValue2:=false;
  if (getAntiGridOptions(symbol,0,distant)) then
  begin
       if (distant[0]<>0) then boolValue:=true;
       if (distant[1]<>0) then boolValue2:=true;
  end;
  // shortDistant.checked:=boolValue;
  ShortReenter.Checked:= boolValue2;

  multiplierForMicroLot:=getMultiplierForMicroLot(symbol);
  case multiplierForMicroLot of
  1:Lots001.checked:=true;
  2:Lots002.checked:=true;
  3:Lots003.checked:=true;
  4:Lots004.checked:=true;
  5:Lots005.checked:=true;
  end;

  loadGridOptions();
  loadBurstGridOptions();
end;

procedure updateAntiGridLongOptions();
var symbol:pchar;
    isDistant:integer;
    allowReenter:integer;
begin
  if (form1.listbox1.itemindex>=0) then
  begin
       isDistant:=0; allowReenter:=0;
       symbol:=getSelectedSymbol();
       // if (form1.longDistant.checked) then isDistant:=1;
       if (form1.longReenter.checked) then allowReenter:=1;
       setAntiGridOptions(symbol,1,isDistant,allowReenter);
  end;
end;

procedure updateAntiGridShortOptions();
var symbol:pchar;
    isDistant:integer;
    allowReenter:integer;
begin
     if (form1.listbox1.itemindex>=0) then
     begin
        isDistant:=0; allowReenter:=0;
        symbol:=getSelectedSymbol();
        // if (form1.shortDistant.checked) then isDistant:=1;
        if (form1.ShortReenter.checked) then allowReenter:=1;
        setAntiGridOptions(symbol,0,isDistant,allowReenter);
     end;
end;

procedure updateGridOptions();
var symbol:pchar;
    enable:integer;
begin
     if (form1.listbox1.itemindex>=0) then
     begin
        enable:=0;
        symbol:=getSelectedSymbol();
        if (form1.GridEnable.Checked) then enable:=1;
        setGridOptions(symbol,enable,gridBottom,gridTop);
        updateGridTopAndBottom();
     end;
end;

procedure updateBurstGridOptions();
var symbol:pchar;
    enable:integer;
begin
     if (form1.listbox1.itemindex>=0) then
     begin
        enable:=0;
        symbol:=getSelectedSymbol();
        if (form1.BurstGridEnable.Checked) then enable:=1;
        setBurstGridOptions(symbol,enable);
     end;
end;

procedure TForm1.LongReenterClick(Sender: TObject);
begin
     LongReenter.Checked:=not LongReenter.Checked;
     updateAntiGridLongOptions();
end;

procedure TForm1.GridSetTopPriceClick(Sender: TObject);
var responseStr : string;
    price:double;
begin
     if (inputQuery('Grid ', 'Top price', responseStr)) then
     try
        gridTop:=StrToFloat(responseStr);
        updateGridOptions();
     except
       on E:Exception do
          ShowMessage(E.Message);
     end;
end;

procedure TForm1.BurstGridEnableClick(Sender: TObject);
begin
     BurstGridEnable.Checked:=not BurstGridEnable.Checked;
     updateBurstGridOptions();
end;

procedure TForm1.mnuRebalanceClick(Sender: TObject);
begin
     setCmd(getSelectedSymbol(),1,'rebalance');
     setCmd(getSelectedSymbol(),0,'rebalance');
     statusbar1.SimpleText:='Rebalance command issued to '+getSelectedSymbol();
end;

procedure TForm1.GridSetBottomPriceClick(Sender: TObject);
var responseStr : string;
    price:double;
begin
     if (inputQuery('Grid ', 'Bottom price', responseStr)) then
     try
        gridBottom:=StrToFloat(responseStr);
        updateGridOptions();
     except
       on E:Exception do
          ShowMessage(E.Message);
     end;
end;

procedure TForm1.GridEnableClick(Sender: TObject);
begin
  GridEnable.Checked:=not GridEnable.Checked;
  updateGridOptions();
end;

procedure TForm1.ShortReenterClick(Sender: TObject);
begin
     ShortReenter.Checked:= not ShortReenter.checked;
     updateAntiGridShortOptions();
end;


procedure _setLotMultiplierForMicrolot(multiplier:integer);
var symbol:pchar;
begin
     if (form1.ListBox1.ItemIndex>=0) then
     begin
          symbol:=getSelectedSymbol();
          setMultiplierForMicroLot(symbol,multiplier);
     end;
end;

procedure TForm1.Lots001Click(Sender: TObject);
begin
     _setLotMultiplierForMicrolot(1);
end;

procedure TForm1.Lots002Click(Sender: TObject);
begin
     _setLotMultiplierForMicrolot(2);
end;

procedure TForm1.Lots003Click(Sender: TObject);
begin
     _setLotMultiplierForMicrolot(3);
end;

procedure TForm1.Lots004Click(Sender: TObject);
begin
     _setLotMultiplierForMicrolot(4);
end;

procedure TForm1.Lots005Click(Sender: TObject);
begin
     _setLotMultiplierForMicrolot(5);
end;



procedure checkProfits();
const myFormat:string='0.00';
var i:integer;
    symbol:string;
    text:string;
    profits1:double;
    profits2:double;
begin
     text:='Profits:'+sLineBreak;
     for i := 0 to (Form1.listbox1.count-1) do
     begin
          symbol:=Form1.listbox1.items[i];
          profits1:= getProfits(PChar(symbol),1);
          profits2:= getProfits(PChar(symbol),0);
          if ((profits1+profits2)<>0) then
          begin
             text+=symbol+' '+
                            FormatFloat(myFormat,profits1)+' '+
                            FormatFloat(myFormat,profits2)+' '+
                            FormatFloat(myFormat,profits1+profits2)+' '+sLineBreak;
          end;
     end;
     Form1.lblProfits.caption := text;
end;

procedure calcNewTargetNAV();
begin
     targetNav := currentNav+StrToFloat(Form1.txtProfitTarget.text);
     Form1.lblTargetNav.Caption:='Target NAV: '+FormatFloat('0.00',targetNav);
end;

procedure closeOpenTrades();
var i:integer;
    symbol:ansistring;
begin
     for i := 0 to form1.listbox1.count-1 do
     begin
          symbol:=form1.listbox1.items[i];
          setCloseOpenTrades(PChar(symbol),0,1);
          setCloseOpenTrades(PChar(symbol),1,1);
     end;
     form1.statusbar1.SimpleText:='Closing open trades.';
end;

procedure TForm1.Timer1Timer(Sender: TObject);
const myFormat:string='#.00';
var Balance1,nav1,usedmargin1:double;
    Balance2,nav2,usedmargin2:double;
begin
     Balance1:=0; nav1:=0; usedMargin1:=0;
     Balance2:=0; nav2:=0; usedMargin2:=0;
     if (getBalance_NAV_UsedMargin(1,Balance1,nav1,usedMargin1)) then
        lblStatsAccount1.caption :=
                                 formatFloat(myFormat,Balance1)+sLineBreak+
                                 sLineBreak+
                                 formatFloat(myFormat,nav1)+sLineBreak+
                                 sLineBreak+
                                 formatFloat(myFormat,usedMargin1);
     if (getBalance_NAV_UsedMargin(0,Balance2,nav2,usedMargin2)) then
        lblStatsAccount2.caption :=
                                 formatFloat(myFormat,Balance2)+sLineBreak+
                                 sLineBreak+
                                 formatFloat(myFormat,nav2)+sLineBreak+
                                 sLineBreak+
                                 formatFloat(myFormat,usedMargin2);
     currentNav := nav1+nav2;
     lblTotals.caption :=
                                 formatFloat(myFormat,Balance1+Balance2)+sLineBreak+
                                 sLineBreak+
                                 formatFloat(myFormat,currentNav)+sLineBreak+
                                 sLineBreak+
                                 formatFloat(myFormat,usedMargin1+usedMargin2);

     checkProfits();

     if (nav1>0) and (nav2>0) then
     begin
          if (targetNAV=0) then
          begin
               calcNewTargetNAV();
          end;
          if (currentNav>targetNAV) then
          begin
               closeOpenTrades();
               calcNewTargetNAV();
          end;
     end;

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

procedure TForm1.ButtonCalcTargetNAVClick(Sender: TObject);
begin
     calcNewTargetNAV();
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
     targetNav:=0;
     setBalance_NAV_UsedMargin(0,-1,-1,-1);
     setBalance_NAV_UsedMargin(1,-1,-1,-1);
end;

procedure TForm1.Label2Click(Sender: TObject);
begin

end;

end.

