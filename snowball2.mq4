//+----------------------------------------------------------------------------------+
//|                        Copyright © 2010, Bernd Kreuss, Andrea Maldini            |
//|                        PayPal donations go here -> 7bit@arcor.de                 |
//+----------------------------------------------------------------------------------+
#property copyright "© Bernd Kreuss, Version 2010.6.11.1 - Andrea Maldini November 2011"
#property link      "http://sites.google.com/site/prof7bit/"

#include <common_functions.mqh>
#include <offline_charts.mqh> 
//#include <oanda.mqh> 

extern double lots = 0.01; // lots to use per trade
//extern double oanda_factor = 25000;
extern int stop_distance = 20;
extern int min_stop_distance = 10;
extern bool dynamicStopDistance = false;
////////////////////////////////////////
extern double profit_target = 0;
extern int auto_tp = 2; // auto-takeprofit this many levels (roughly) above the BE point
extern bool stopWhenAutoTP=true;
////////////////////////////////////////
extern bool useBreakEven=true;
extern double breakEvenOffset=2;
////////////////////////////////////////
extern bool breakoutMode=false;
extern int breakoutBars=25;
extern bool breakoutBiDir=true;
////////////////////////////////////////
extern bool useMA=false;
extern bool useMAEntry=false;
////////////////////////////////////////
extern int exitBars=3;
extern int exitBarsLevel=2;
extern bool exitBarsHeikenAshi=true;
////////////////////////////////////////
extern bool useDailyCycle=false;
////////////////////////////////////////
extern bool    BREAKEVEN=true;
extern double  BREAKEVEN_ARM_PIPS=5;
extern double  BREAKEVEN_EXECUTE_PIPS=-5;
////////////////////////////////////////
extern bool is_ecn_broker = false; // different market order procedure when resuming after pause


extern color clr_breakeven_level = Lime;
extern color clr_buy = Blue;
extern color clr_sell = Red;
extern color clr_gridline = Lime;
extern color clr_stopline_active = Magenta;
extern color clr_stopline_triggered = Aqua;
extern string sound_grid_trail = "";
extern string sound_grid_step = "";
extern string sound_order_triggered = "";
extern string sound_stop_all = "";

string name = "sno2_";

double pip;
double points_per_pip;
string comment;
int magic;
bool running;
int direction;
double last_line;
int level; // current level, signed, minus=short, calculated in trade()
double realized; // total realized (all time) (calculated in info())
double cycle_total_profit; // total profit since cycle started (calculated in info())
double stop_value; // dollars (account) per single level (calculated in info())
double auto_tp_price; // the price where auto_tp should trigger, calculated during break even calc.
double auto_tp_profit; // rough estimation of auto_tp profit, calculated during break even calc.

bool start_immediately;
bool stopAlreadyReduced;
bool lastFloatingWasNegative;
double lastFloating=0;

string stringToAppendToInfo;
bool initCalled=false;
bool stopped=false;

#define SP "                                    "

// trading direction
#define BIDIR 0
#define LONG  1
#define SHORT 2

int getBreakOut() {

   int Current = 0; // 0 per ogni tick, 1 per penultima bar
   double close = iClose(NULL, 0, Current+0);
   double Range_high = High[iHighest(NULL,0,MODE_HIGH,breakoutBars,1)];
   double Range_low = Low[iLowest(NULL,0,MODE_LOW,breakoutBars,1)];


   int dir=-1;
   if (close > Range_high) {
      dir=LONG;
   }   
   if (close < Range_low) {
      dir=SHORT;
   }   
   if (dir>0 && breakoutBiDir) return (BIDIR);
   return (dir);
}

void checkBreakout() {
   if (!breakoutMode) return;
   if (running) return;
   
   int dir = getBreakOut();
   if (dir<0) return; 
   
   if (running) {
      if (direction==dir) return;
      stop();
   }  
   
   go(dir);
   
}

void defaults(){

   IS_ECN_BROKER = true; // different market order procedure when resuming after pause

   /*
   
   //auto_tp = 2;
   
   if (IsTesting()){
      return(0);
   }
   if (Symbol6() == "GBPUSD"){
      lots = 0.1;
      oanda_factor = 900;
      stop_distance = 30;
   }
   if (Symbol6() == "EURUSD"){
      lots = 0.1;
      oanda_factor = 1800;
      stop_distance = 30;
   }
   if (Symbol6() == "USDCHF"){
      lots = 0.1;
      oanda_factor = 1800;
      stop_distance = 20;
   }
   if (Symbol6() == "USDJPY"){
      lots = 0.1;
      oanda_factor = 1800;
      stop_distance = 30;
   }
   
   sound_grid_step = "expert.wav";
   sound_grid_trail = "alert2.wav";
   sound_stop_all = "alert.wav";
   sound_order_triggered = "alert.wav";
   */
}


int init(){
   initCalled = true;
   
   if (!IsDllsAllowed()){
      MessageBox("DLL imports must be allowed!", "Snowball");
      return(-1);
   }
      
   IS_ECN_BROKER = is_ecn_broker;
   CLR_BUY_ARROW = clr_buy;
   CLR_SELL_ARROW = clr_sell;
   CLR_CROSSLINE_ACTIVE = clr_stopline_active;
   CLR_CROSSLINE_TRIGGERED = clr_stopline_triggered;
   
   defaults();

   points_per_pip = pointsPerPip();
   pip = Point * points_per_pip;
   
   comment = name + "_" + Symbol6();
   magic = makeMagicNumber(name + "_" + Symbol());
   
   if (last_line == 0){
      last_line = getLine();
   }
   
   if (IsTesting()){
      setGlobal("realized", 0);
      setGlobal("running", 0);
   }
   
   readVariables();
   
   if (IsTesting() && !IsVisualMode()){
      maldaLog("!!! This is not an automated strategy! Automated backtesting is nonsense! Starting in bidirectional mode!");
      running = true;
      direction = BIDIR;
      placeLine(Bid);
   }
    
   info();
}

int deinit(){
   deleteStartButtons();
   deleteStopButtons();
   deleteMAButtons();
   storeVariables();
   if (UninitializeReason() == REASON_PARAMETERS){
      Comment("Parameters changed, pending orders deleted, will be replaced with the next tick");
      closeOpenOrders(OP_SELLSTOP, magic);
      closeOpenOrders(OP_BUYSTOP, magic);
   }else{
      Comment("EA removed, open orders, trades and status untouched!");
   }
}

void onTick(){
   /*
   if (TimeHour(TimeLocal())>9 && TimeMinute(TimeLocal())>44) {
      stopped=true;
   } */
   
   if (stopped) {
      Comment("STOPPED!!!");
      return(0);
   }
   

   recordEquity(name+Symbol6(), PERIOD_H1, magic);
   //checkOanda(magic, oanda_factor);
   checkLines();
   checkButtons();
   checkBreakout();
   trade();
   info(); // calcola lastFloating
   checkAutoTP();
   checkStopToBreakEven();
   checkBreakEven2();
   checkProfitTarget(); // usa lastFloating
   checkExitBars();
   checkMA();
   checkDailyCycle();
   if(!IsTesting()){
      plotNewOpenTrades(magic);
      plotNewClosedTrades(magic);
   }
   checkForStopReduction();
}

void checkBreakEven2() {
   
   
   // TODO: armed é da calcolare al volo per ogni trade (non mettere in variabile statica)
   //       in base al massimo / minimo prezzo raggiunto.
   //       
   #define VERYBIG 10000000
   static double maxPrice=0;
   static double minPrice=VERYBIG;
   
   if (level==0) {
      maxPrice=0;
      minPrice=VERYBIG;     
      return;
   } else {
      if (Bid>maxPrice) maxPrice=Bid;
      if (Ask<minPrice) minPrice=Ask;
   }
   
   if (!BREAKEVEN) return;
   
   int total = OrdersTotal();
   
   bool doCycle = true;
   while (doCycle) {
      doCycle = false;
      for (int cnt = 0; cnt < total; cnt++) {      
         OrderSelect(cnt, SELECT_BY_POS, MODE_TRADES);
         if (isMyOrder(magic)) {
               int type = OrderType();
               int clr;
               
               bool armed = false;
               double armPrice;
               
               if (type == OP_BUY){
                  armPrice = OrderStopLoss()+ pip * (stop_distance+BREAKEVEN_ARM_PIPS);
                  clr = CLR_SELL_ARROW;
                  if (armPrice<=maxPrice) armed = true;
               }
        
               if (type == OP_SELL){
                  armPrice = OrderStopLoss()- pip * (stop_distance+BREAKEVEN_ARM_PIPS);
                  clr = CLR_BUY_ARROW;
                  if (armPrice>=minPrice) armed = true;
               }
               // if (armed) maldaLog("BreakEven armed..."); 
   
               double orderPrice; // lo calcolo in base allo stoploss perché dopo un resume 
                                  // i prezzi sono tutti uguali mentre gli stop loss sono diversi  
        
               bool isToClose = false;
               
               if (armed) {     
                  if (type == OP_BUY){
                     orderPrice = OrderStopLoss()+ pip * (stop_distance+BREAKEVEN_EXECUTE_PIPS);
                     clr = CLR_SELL_ARROW;
                     if (orderPrice>=Bid) isToClose = true;
                  }
        
                  if (type == OP_SELL){
                     orderPrice = OrderStopLoss()- pip * (stop_distance+BREAKEVEN_EXECUTE_PIPS);
                     clr = CLR_BUY_ARROW;
                     if (orderPrice<=Ask) isToClose = true;
                  }
               }
            
               if (isToClose) {
                  maldaLog("BE2: Close order "+OrderTicket()+" at BreakEven: "+orderPrice);
                  orderCloseReliable(OrderTicket(), OrderLots(), 0, 999, clr);
                  
                  // quando si esegue una chiusura per breakeven,
                  // il massimo/minimo prezzo raggiunto si imposta=al prezzo corrente
                  maxPrice=Bid;
                  minPrice=Ask;
                  
                  doCycle=true;
                  break; // cycle again starting from 0 (HELLO FIFO!)
               }
            }
         }
   }

}

void onOpen(){
}

void checkDailyCycle() {
   static bool justRestarted;
      
   if (!useDailyCycle) return(0);
   
   if (Hour()==0) {
      if (!justRestarted) {
         if (running) stop();
         go(BIDIR);
         justRestarted = true;
      }         
   } else {
      justRestarted = false;
   }
   
   
}

void checkMA() {
   if (!useMA) return;
   
   int Current = 0; // 0 per ogni tick, 1 per penultima bar
   double close = iClose(NULL, 0, Current+0);
   
   double maValue = iMA(NULL,0,5,3,MODE_LWMA,PRICE_TYPICAL,0);
   
   if (level>0) {
      if (close<maValue) {
         maldaLog("MA STOP! (profit= "+lastFloating+")");
         stop();
      }
   } else if (level<0) {
      if (close>maValue) {
         maldaLog("MA STOP! (profit= "+lastFloating+")");
         stop();
      }
   } else if (level==0 && useMAEntry) {
      // ENTRY ?
      if (close>maValue+pip*10) { // LONG 
         if (running) stop();
         start_immediately = true;
         maldaLog("MA LONG entry!");
         go(LONG);      
      } else if (close<maValue-pip*10) { // SHORT 
         if (running) stop();
         start_immediately = true;
         maldaLog("MA SHORT entry!");
         go(SHORT);   
      }
   }
   
}

void checkExitBars() {
   static int maxAbsLevel=0;

   if (!running || level==0) {
      maxAbsLevel=0;
      return;
   }
   
   int absLevel = MathAbs(level);
   if (absLevel>maxAbsLevel) maxAbsLevel = absLevel;
   
   int Current = 0; // 0 per ogni tick, 1 per penultima bar
   double close = iClose(NULL, 0, Current+0);
   
   bool shouldStop=false;
   if (maxAbsLevel>=exitBarsLevel) {
      if (!exitBarsHeikenAshi) { // CANDLESTICKS
         if (level>0) {
            double Range_low = Low[iLowest(NULL,0,MODE_LOW,exitBars,1)];
            if (close<Range_low) shouldStop=true;
         } if (level<0) {
            double Range_high = High[iHighest(NULL,0,MODE_HIGH,exitBars,1)];
            if (close>Range_high) shouldStop=true; 
         }
      } else { // HEIKENASHI
         shouldStop = checkExitBars_HeikenAshi(close);
      }
   }
   
   if (shouldStop) {
      maldaLog("ExitBars STOP!");
      stop();
   }
}

bool checkExitBars_HeikenAshi(double close) {
   color color1 = Red;
   color color2 = White;
   color color3 = Red;
   color color4 = White;
   #define HAHIGH      0
   #define HALOW       1
   #define HAOPEN      2
   #define HACLOSE     3

   bool shouldStop = false;   

   int i;
   if (level>0) {
   
      // double Heiken_op = iCustom(NULL,0,"Heiken Ashi",Red,White,Red,White,2,0);
      // double Heiken_cl = iCustom(NULL,0,"Heiken Ashi",Red,White,Red,White,3,0);
      double Range_low = 10000000;
      for (i=1;i<=exitBars;i++) {
         double HALow = iCustom(NULL,0,"Heiken Ashi", color1,color2,color3,color4, HALOW, i);
         if (HALow < Range_low) Range_low = HALow;
      }
      if (close<Range_low) shouldStop=true;
   } if (level<0) {
      double Range_high = 0;
      for (i=1;i<=exitBars;i++) {
         double HAHigh = iCustom(NULL,0,"Heiken Ashi",color1,color2,color3,color4, HAHIGH, i);
         if (HAHigh > Range_high) Range_high = HAHigh;
      }
      if (close>Range_high) shouldStop=true; 
   }
   
   return (shouldStop);
}

void storeVariables(){
   setGlobal("running", running);
   setGlobal("direction", direction);
}

void readVariables(){
   running = getGlobal("running");
   direction = getGlobal("direction");
}

void deleteStartButtons(){
   ObjectDelete("start_long");
   ObjectDelete("start_short");
   ObjectDelete("start_bidir");
   ObjectDelete("long_now");
   ObjectDelete("short_now");
   ObjectDelete("toggle_breakout1");
}

void deleteStopButtons(){
   ObjectDelete("stop");
   ObjectDelete("pause");
   ObjectDelete("close");
   ObjectDelete("toggle_breakout2");
}

void deleteMAButtons() {
   ObjectDelete("toggle_MA1");
   ObjectDelete("toggle_MA2");
}

/**
* mark the start (or resume) of the cycle in the chart 
*/
void startArrow(){
   string aname = "cycle_start_" + TimeToStr(TimeCurrent());
   ObjectCreate(aname, OBJ_ARROW, 0, TimeCurrent(), Close[0]);
   ObjectSet(aname, OBJPROP_ARROWCODE, 5);
   ObjectSet(aname, OBJPROP_COLOR, clr_gridline);
   ObjectSet(aname, OBJPROP_BACK, true);
}

/**
* mark the end (or pause) of the cycle in the chart 
*/
void endArrow(){
   string aname = "cycle_end_" + TimeToStr(Time[0]);
   ObjectCreate(aname, OBJ_ARROW, 0, TimeCurrent(), Close[0]);
   ObjectSet(aname, OBJPROP_ARROWCODE, 6);
   ObjectSet(aname, OBJPROP_COLOR, clr_gridline);
   ObjectSet(aname, OBJPROP_BACK, true);
}

void stop(){
   endArrow();
   deleteStopButtons();
   closeOpenOrders(-1, magic);
   running = false;
   storeVariables();
   setGlobal("realized", getProfitRealized(magic)); // store this only on pyramid close
   //checkOanda(magic, oanda_factor);
   if (sound_stop_all != ""){
      PlaySound(sound_stop_all);
   }
}

void closeTrades() {
   closeOpenOrders(OP_BUY,-1);
   closeOpenOrders(OP_SELL,-1);
}

void go(int mode){
   startArrow();
   deleteStartButtons();
   running = true;
   direction = mode;
   storeVariables();
   resume();
}

void pause(){
   endArrow();
   deleteStopButtons();
   label("paused_level", 15, 100, 1, level, Yellow);
   closeOpenOrders(-1, magic);
   running = false;
   storeVariables();
   //checkOanda(magic, oanda_factor);
   if (sound_stop_all != ""){
      PlaySound(sound_stop_all);
   }
}

/**
* resume trading after we paused it.
* Find the text label containing the level where we hit pause
* and re-open the corresponding amounts of lots, then delete the label.
*/ 
void resume(){
   int i;
   double sl;
   double line = getLine();
   level = StrToInteger(ObjectDescription("paused_level"));
   
   if (direction == LONG){
      level = MathAbs(level);
   }
   
   if (direction == SHORT){
      level = -MathAbs(level);
   }
   
   if (level == 0 && start_immediately) {
      if (direction == SHORT) {
         level=-1;
      }
      if (direction == LONG) {
         level=1;
      }
   } 
   
   if (level > 0){
      // maldaLog("RESUMING LONG from level:"+level);
      for (i=1; i<=level; i++){
         sl = line - pip * i * stop_distance;
         // maldaLog("buying at "+NormalizeDouble(Ask,5)+" with stop loss="+sl);
         buy(lots, sl, 0, magic, comment);
      }
   }
   
   if (level < 0){
      // maldaLog("RESUMING SHORT from level:"+(-level));
      for (i=1; i<=-level; i++){
         sl = line + pip * i * stop_distance;
         // maldaLog(" selling at "+NormalizeDouble(Bid,5)+" with stop loss="+sl);
         sell(lots, sl, 0, magic, comment);
      }
   }
      
   ObjectDelete("paused_level");
}

void checkLines(){
   if (crossedLine("stop")){
      maldaLog("Crossed line 'stop'");
      stop();
   }
   if (crossedLine("pause")){
      maldaLog("Crossed line 'pause'");
      pause();
   }
   if (crossedLine("start long")){
      maldaLog("Crossed line 'start long'");
      go(LONG);
   }
   if (crossedLine("start short")){
      maldaLog("Crossed line 'start short'");
      go(SHORT);
   }
   if (crossedLine("start bidir")){
      maldaLog("Crossed line 'start bidir'");
      go(BIDIR);
   }   
   
   if (crossedLine("long")) {
      maldaLog("Crossed line 'long'");
      if (running) stop();
      start_immediately = true;
      go(LONG);
   }
   
   if (crossedLine("short")) {
      maldaLog("Crossed line 'short'");
      if (running) stop();
      start_immediately = true;
      go(SHORT);
   }
   
}

/**
* Show a button and check if it has been actuated.
* Emulate a button with a label that must be moved by the user.
* Return true if the label has been moved and move it back.
* create it if it does not already exist.
*/
bool labelButtonToggle(string name, int x, int y, int corner, string text, color clr = Gray) {
   if (IsOptimization()) {
      return(false);
   }
   if (ObjectFind(name) != -1) {
      if (ObjectGet(name, OBJPROP_XDISTANCE) != x || ObjectGet(name, OBJPROP_YDISTANCE) != y) {
         ObjectDelete(name);
         return(true);
      }
   }
   label(name, x, y, corner, "[" + text + "]", clr);
   return(false);
}

void checkButtons(){
   if(!running){
      deleteStopButtons();
      
      start_immediately = false; 
      
      
      if (labelButton("start_long", 15, 15*1, 1, "start long", Lime)){
         go(LONG);
      }
      if (labelButton("start_short", 15, 15*2, 1, "start short", Lime)){
         go(SHORT);
      }
      if (labelButton("start_bidir", 15, 15*3, 1, "start bidirectional", Lime)){
         go(BIDIR);
      }
      
      if (labelButton("long_now", 15, 15*4, 1, "long now", Green)){
         start_immediately = true;
         go(LONG);
      }
      
      if (labelButton("short_now", 15, 15*5, 1, "short now", Red)) {
         start_immediately = true;
         go(SHORT);
      }
      
      if (labelButton("toggle_breakout1", 15, 15*6, 1, getBreakOutButtonDescription(), getBreakOutButtonColor())) {
         toggleBreakOut();
      }
      
   }
   
   if (running){
      deleteStartButtons();
      if (labelButton("stop", 15, 15*1, 1, "stop", Red)){
         stop();
      }
      if (labelButton("pause", 15, 15*2, 1, "pause", Yellow)){
         pause();
      }
      if (labelButton("close", 15, 15*3, 1, "close", White)) {
         closeTrades();
      }
      
      if (labelButton("toggle_breakout2", 15, 15*4, 1, getBreakOutButtonDescription(), getBreakOutButtonColor())) {
         toggleBreakOut();
      }
   }
   
   if (!useMA) {
      if (labelButton("toggle_MA1", 15, 16*8,1, getToggleMAButtonDescription(), getToggleMAButtonColor())) {
         useMA = true;
         deleteMAButtons();
      }
   } else {
      if (labelButton("toggle_MA2", 15, 16*8,1, getToggleMAButtonDescription(), getToggleMAButtonColor())) {
         useMA = false;
         deleteMAButtons();   
      }
   }
   
}

string getToggleMAButtonDescription() {
   if (useMA) {
      return ("Trade MA: ON");
   } else {
      return ("Trade MA: OFF");
   }
} 

color getToggleMAButtonColor() {
   if (useMA) return (Green);
   return (Red);
}

color getBreakOutButtonColor() {
   if (breakoutMode) return (Green);
   return (Red);
}

string getBreakOutButtonDescription() {
   if (breakoutMode) {
      return ("AutoBreakOut: ON");
   } else {
      return ("AutoBreakOut: OFF");
   }
}

void toggleBreakOut() {
   breakoutMode=!breakoutMode;
   ObjectDelete("toggle_breakout1");
   ObjectDelete("toggle_breakout2");
}

void checkAutoTP(){
   if (auto_tp > 0 && auto_tp_price > 0){
      if (level > 0 && Close[0] >= auto_tp_price){
         if (stopWhenAutoTP) {
            stop();
         } else {
            closeTrades();
            auto_tp_price = 0;
         }
      }
      if (level < 0 && Close[0] <= auto_tp_price){
         if (stopWhenAutoTP) {
            stop();
         } else {
            closeTrades();
            auto_tp_price = 0;
         }
      }
   }
}

void checkStopToBreakEven() {
   static int maxLevel = 0;
   if (!useBreakEven) return;
   if (level==0) {
      maxLevel=0;
      return;
   }
   int absLevel = MathAbs(level);
   if (absLevel>maxLevel) maxLevel=absLevel;
   // tutti i trade che hanno abs(prezzo-pyramidbase)>absLevel*stop_distance vanno chiusi

   if (absLevel==maxLevel) return;

   double pb = getPyramidBase();
   if (pb<=0) return;

   int cnt;
   double profit = 0;
   int total = OrdersTotal();
   
   bool doCycle = true;
   while (doCycle) {
      doCycle = false;
      for (cnt = 0; cnt < total; cnt++) {      
         OrderSelect(cnt, SELECT_BY_POS, MODE_TRADES);
         if (isMyOrder(magic)) {
               int type = OrderType();
   
               double orderPrice; // lo calcolo in base allo stoploss perché dopo un resume 
                                  // i prezzi sono tutti uguali mentre gli stop loss sono diversi  
        
               bool isToClose = false;
               int clr;     
               if (type == OP_BUY){
                  orderPrice = OrderStopLoss()+ pip * (stop_distance+breakEvenOffset);
                  clr = CLR_SELL_ARROW;
                  if (orderPrice>=Bid) isToClose = true;
                  // isToClose = true;
               }
        
               if (type == OP_SELL){
                  orderPrice = OrderStopLoss()- pip * (stop_distance+breakEvenOffset);
                  clr = CLR_BUY_ARROW;
                  if (orderPrice<=Ask) isToClose = true;
                  // isToClose = true;
               }
            
               if (isToClose) {
                  maldaLog("Close order "+OrderTicket()+" at BreakEven: "+orderPrice);
                  orderCloseReliable(OrderTicket(), OrderLots(), 0, 999, clr);
                  maxLevel = 0; // <== verrà ricalcolato successivamente
                  doCycle=true;
                  break; // cycle again starting from 0 (HELLO FIFO!)
               }
            }
         }
   }
}

void checkProfitTarget() {
   if (profit_target>0 && lastFloating>profit_target) {
      closeTrades();
   }
}

void placeLine(double price){
   horizLine("last_order", price, clr_gridline, SP + "grid position");
   last_line = price;
   WindowRedraw();
}

double getLine(){
   return(ObjectGet("last_order", OBJPROP_PRICE1));
}

bool lineMoved(){
   double line = getLine();
   if (line != last_line){
      // line has been moved by external forces (hello wb ;-)
      if (MathAbs(line - last_line) < stop_distance * pip){
         // minor adjustment by user
         last_line = line;
         return(true);
      }else{
         // something strange (gap? crash? line deleted?)
         if (MathAbs(Bid - last_line) < stop_distance * pip){
            // last_line variable still near price and thus is valid.
            placeLine(last_line); // simply replace line
            return(false); // no action needed
         }else{
            // line is far off or completely missing and last_line doesn't help also
            // make a completely new line at Bid
            placeLine(Bid);
            return(true);
         }
      }
      return(true);
   }else{
      return(false);
   }
}

/**
* manage all the entry order placement
*/
void trade(){
   double start;
   static int last_level;
   
   if (lineMoved()){
      closeOpenOrders(OP_SELLSTOP, magic);
      closeOpenOrders(OP_BUYSTOP, magic);
   }
   start = getLine();
   
   int prevLevel = level;
   
   // calculate global variable level here // FIXME: global variable side-effect hell.
   level = getNumOpenOrders(OP_BUY, magic) - getNumOpenOrders(OP_SELL, magic);
   
   if (running){
      // are we flat?
      if (level == 0){
      
         if (breakoutMode && prevLevel!=0) { // se sono in breakoutMode e sono tornato a livello 0 da un livello!=0, 
                                             // allora stop() e attendo un nuovo breakOut.
            stop();
            return;
         }
      
         if (direction == SHORT && Ask > start){
            if (getNumOpenOrders(OP_SELLSTOP, magic) != 2){
               closeOpenOrders(OP_SELLSTOP, magic);
            }else{
               moveOrders(Ask - start);
            }
            placeLine(Ask);
            start = Ask;
            plotBreakEven();
            if (sound_grid_trail != ""){
               PlaySound(sound_grid_trail);
            }
         }
         
         if (direction == LONG && Bid < start){
            if (getNumOpenOrders(OP_BUYSTOP, magic) != 2){
               closeOpenOrders(OP_BUYSTOP, magic);
            }else{
               moveOrders(Bid - start);
            }
            placeLine(Bid);
            start = Bid;
            plotBreakEven();
            if (sound_grid_trail != ""){
               PlaySound(sound_grid_trail);
            }
         }
         
         // make sure first long orders are in place
         if (direction == BIDIR || direction == LONG){
            longOrders(start);
         }
         
         // make sure first short orders are in place
         if (direction == BIDIR || direction == SHORT){
            shortOrders(start);
         }
      }
   
      // are we already long?
      if (level > 0){
         // make sure the next long orders are in place
         longOrders(start);
      }

      // are we short?
      if (level < 0){
         // make sure the next short orders are in place
         shortOrders(start);
      }
      
      // we have two different models how to move the grid line.
      // If we are *not* flat we can snap it to the nearest grid level,
      // ths is better for handling situations where the order is triggered 
      // by the exact pip and price is immediately reversing.
      // If we are currently flat we *must* move it only when we have reached 
      // it *exactly*, because otherwise this would badly interfere with 
      // the trailing of the grid in the unidirectional modes. Also in 
      // bidirectional mode this would have some unwanted effects.
      if (level != 0){
         // snap to grid
         if (Ask + (pip * stop_distance / 6) >= start + stop_distance*pip){
            jumpGrid(1);
         }
      
         // snap to grid
         if (Bid - (pip * stop_distance / 6) <= start - stop_distance*pip){
            jumpGrid(-1);
         }
      }else{   
         // grid reached exactly
         if (Ask  >= start + stop_distance*pip){
            jumpGrid(1);
         }
         
         // grid reached exactly
         if (Bid  <= start - stop_distance*pip){
            jumpGrid(-1);
         }
      }
      
      // alert on level change (order triggered, not line moved)
      if (level != last_level){
         if (sound_order_triggered != ""){
            PlaySound(sound_order_triggered);
         }
         last_level = level;
      }
      
   }else{ // not running
      placeLine(Bid);
   }
}

/**
* move the line 1 stop_didtance up or down.
* 1 means up, -1 means down.
*/
void jumpGrid(int dir){
   placeLine(getLine() + pip * stop_distance * dir);
   if (sound_grid_step != ""){
      PlaySound(sound_grid_step);
   }
}

/**
* do we need to place a new entry order at this price?
* This is done by looking for a stoploss below or above the price
* where=-1 searches for stoploss below, where=1 for stoploss above price
* return false if there is already an order (open or pending)
*/ 
bool needsOrder(double price, int where){
   //return(false);
   int i;
   int total = OrdersTotal();
   int type;
   // search for a stoploss at exactly one grid distance away from price
   for (i=0; i<total; i++){
      OrderSelect(i, SELECT_BY_POS, MODE_TRADES);
      type = OrderType();
      if (where < 0){ // look only for buy orders (stop below)
         if (isMyOrder(magic) && (type == OP_BUY || type == OP_BUYSTOP)){
            if (isEqualPrice(OrderStopLoss(), price + where * pip * stop_distance)){
               return(false);
            }
         }
      }
      if (where > 0){ // look only for sell orders (stop above)
         if (isMyOrder(magic) && (type == OP_SELL || type == OP_SELLSTOP)){
            if (isEqualPrice(OrderStopLoss(), price + where * pip * stop_distance)){
               return(false);
            }
         }
      }
   }
   return(true);
}

/**
* Make sure there are the next two long orders above start in place.
* If they are already there do nothing, else replace the missing ones.
*/
void longOrders(double start){
   double a = start + stop_distance * pip;
   double b = start + 2 * stop_distance * pip;
   if (needsOrder(a, -1)){
      buyStop(lots, a, start, 0, magic, comment);
   }
   if (needsOrder(b, -1)){
      buyStop(lots, b, a, 0, magic, comment);
   }
}

/**
* Make sure there are the next two short orders below start in place.
* If they are already there do nothing, else replace the missing ones.
*/
void shortOrders(double start){
   double a = start - stop_distance * pip;
   double b = start - 2 * stop_distance * pip;
   if (needsOrder(a, 1)){
      sellStop(lots, a, start, 0, magic, comment);
   }
   if (needsOrder(b, 1)){
      sellStop(lots, b, a, 0, magic, comment);
   }
}

/**
* move all entry orders by the amount of d
*/
void moveOrders(double d){
   int i;
   for(i=0; i<OrdersTotal(); i++){
      OrderSelect(i, SELECT_BY_POS, MODE_TRADES);
      if (isMyOrder(magic)){
         if (MathAbs(OrderOpenPrice() - getLine()) > 3 * stop_distance * pip){
            orderDeleteReliable(OrderTicket());
         }else{
            orderModifyReliable(
               OrderTicket(),
               OrderOpenPrice() + d,
               OrderStopLoss() + d,
               0,
               0,
               CLR_NONE
            );
         }
      }
   }
}

void info(){
   double floating;
   double pb, lp, tp;
   static int last_ticket;
   static datetime last_be_plot = 0; 
   int ticket;
   string dir;
   
   OrderSelect(OrdersHistoryTotal()-1, SELECT_BY_POS, MODE_HISTORY);
   ticket = OrderTicket();
   
   if (ticket != last_ticket) {
      // history changed, need to recalculate realized profit
      realized = getProfitRealized(magic);
      last_ticket = ticket;
      
      // enforce a new break-even arrow plot immediately
      last_be_plot = 0;
   } else {
      // Print("Last ticket:",ticket,"GetProfitRealized:",getProfitRealized(magic),"getGlobal(realized)",getGlobal("realized"),"Realized:",realized);
   }
   
   floating = getProfit(magic);
   lastFloating = floating;
   if (level!=0) {
      lastFloatingWasNegative = (floating<0);
   }
   
   // the variable realized is the total realized of all time. 
   // the MT4-global variable _realized is a snapshot of this value when 
   // the EA was reset the last time. The difference is what we made
   // during the current cycle. Add floating to it and we have the 
   // profit of the current cycle.
   cycle_total_profit = realized - getGlobal("realized") + floating;
   
   if (running == false){
      dir = "trading stopped";
   }else{
      switch(direction){
         case LONG: 
            dir = "trading long";
            break;
         case SHORT: 
            dir = "trading short";
            break;
         default: 
            dir = "trading both directions";
      }
   }
   
   int level_abs = MathAbs(getNumOpenOrders(OP_BUY, magic) - getNumOpenOrders(OP_SELL, magic));
   stop_value = MarketInfo(Symbol(), MODE_TICKVALUE) * lots * stop_distance * points_per_pip;
   
   Comment("\n" + SP + name + magic + ", " + dir +
           "\n" + SP + Symbol() + " IsTesting:" + IsTesting() + 
           "\n" + SP + "1 pip is " + DoubleToStr(pip, Digits) + " " + Symbol6() +
           "\n" + SP + "stop distance: " + stop_distance + " pip, lot-size: " + DoubleToStr(lots, 2) +
           "\n" + SP + "every stop equals " + DoubleToStr(stop_value, 2) + " " + AccountCurrency() +
           "\n" + SP + "realized: " + DoubleToStr(realized - getGlobal("realized"), 2) + "  floating: " + DoubleToStr(floating, 2) +
           "\n" + SP + "profit: " + DoubleToStr(cycle_total_profit, 2) + " " + AccountCurrency() + "  current level: " + level_abs +
           "\n" + SP + "auto-tp: " + auto_tp + " levels (" + DoubleToStr(auto_tp_price, Digits) + ", " + DoubleToStr(auto_tp_profit, 2) + " " + AccountCurrency() + ")" +
           "\n" + SP + "profit target: "+ profit_target + 
           "\n" + stringToAppendToInfo);

   if (last_be_plot == 0 || TimeCurrent() - last_be_plot > 300){ // every 5 minutes
      plotBreakEven();
      last_be_plot = TimeCurrent();
   }

   // If you put a text object (not a label!) with the name "profit",  
   // anywhere on the chart then this can be used as a profit calculator.
   // The following code will find the position of this text object 
   // and calculate your profit, should price reach this position
   // and then write this number into the text object. You can
   // move it around on the chart to get profit projections for
   // any price level you want. 
   if (ObjectFind("profit") != -1){
      pb = getPyramidBase();
      lp = ObjectGet("profit", OBJPROP_PRICE1);
      if (pb ==0){
         if (direction == SHORT){
            pb = getLine() - stop_distance * pip;
         }
         if (direction == LONG){
            pb = getLine() + stop_distance * pip;
         }
         if (direction == BIDIR){
            if (lp < getLine()){
               pb = getLine() - stop_distance * pip;
            }
            if (lp >= getLine()){
               pb = getLine() + stop_distance * pip;
            }
         }
      }
      tp = getTheoreticProfit(MathAbs(lp - pb));
      ObjectSetText("profit", "¯¯¯ " + DoubleToStr(MathRound(realized - getGlobal("realized") + tp), 0) + " " + AccountCurrency() + " profit projection ¯¯¯");
   }
   
}

/**
* Plot an arrow. Default is the price-exact dash symbol
* This function might be moved into common_functions soon
*/
string arrow(string name="", double price=0, datetime time=0, color clr=Red, int arrow_code=4){
   if (time == 0){
      time = TimeCurrent();
   }
   if (name == ""){
      name = "arrow_" + time;
   }
   if (price == 0){
      price = Bid;
   }
   if (ObjectFind(name) < 0){
      ObjectCreate(name, OBJ_ARROW, 0, time, price);
   }else{
      ObjectSet(name, OBJPROP_PRICE1, price);
      ObjectSet(name, OBJPROP_TIME1, time);
   }
   ObjectSet(name, OBJPROP_ARROWCODE, arrow_code);
   ObjectSet(name, OBJPROP_SCALE, 1);
   ObjectSet(name, OBJPROP_COLOR, clr);
   ObjectSet(name, OBJPROP_BACK, true);
   return(name);
}

/**
* plot the break even price into the chart
*/
void plotBreakEvenArrow(string arrow_name, double price){
   arrow(arrow_name + TimeCurrent(), price, 0, clr_breakeven_level);
}


/**
* plot the break-even Point (only a rough estimate plusminus less than one stop_distance,
* it will be most inaccurate just before hitting a stoploss (last trade negative).
* and this will be more obvious at the beginning of a new cycle when losses are still small
* and break even steps increments are still be big.
*
* Side effects: This function will also calculate auto-tp price and profit.
*
* FIXME: This whole break even calculation sucks comets through drinking straws!
* FIXME: Isn't there a more elegant way to calculate break even?
*/
void plotBreakEven(){

   double base = getPyramidBase();
   double be = 0;
   
   // loss is roughly the amount of realized stop hits. But I can't use this number
   // directly because after resuming a paused pyramid this number is wrong. So
   // I have to estimate it with the (always accurate) total profit and the current
   // distance from base. In mose cases the outcome of this calculation is equal
   // to the realized losses as displayed on the screen, only when resuming a pyramid 
   // it will differ and have the value it would have if the pyramid never had been paused.
   double distance = MathAbs(Close[0] - base);
   if ((level > 0 && Close[0] < base) || (level < 0 && Close[0] > base) || level == 0){
      distance = 0;
   }
   double loss = -(cycle_total_profit - getTheoreticProfit(distance));

   // this value should always be positive 
   // or 0 (or slightly below (rounding error)) in case we have a fresh pyramid.
   // If it is not positive (no loss yet) then we dont need to plot break even.
   if (loss <= 0 || !running){
      auto_tp_price = 0;
      auto_tp_profit = 0;
      return(0);
   }
   
   if (direction == LONG){
      if (base==0){
         base = getLine() + stop_distance * pip;
      }
      be = base + getBreakEven(loss);
      plotBreakEvenArrow("breakeven_long", be);
      
      auto_tp_price = be + pip * stop_distance * auto_tp;
      auto_tp_profit = getTheoreticProfit(MathAbs(auto_tp_price - base)) - loss;
   }
   
   if (direction == SHORT){
      if (base==0){
         base = getLine() - stop_distance * pip;
      }
      be = base - getBreakEven(loss);
      plotBreakEvenArrow("breakeven_short", be);
      
      auto_tp_price = be - pip * stop_distance * auto_tp;
      auto_tp_profit = getTheoreticProfit(MathAbs(auto_tp_price - base)) - loss;
   }
   
   if (direction == BIDIR){
      if (base == 0){
         base = getLine() + stop_distance * pip;
         plotBreakEvenArrow("breakeven_long", base + getBreakEven(loss));
         base = getLine() - stop_distance * pip;
         plotBreakEvenArrow("breakeven_short", base - getBreakEven(loss));
         auto_tp_price = 0;
         auto_tp_profit = 0;
      }else{
         if (getLotsOnTableSigned(magic) > 0){
            be = base + getBreakEven(loss);
            plotBreakEvenArrow("breakeven_long", be);
            auto_tp_price = be + pip * stop_distance * auto_tp;
            auto_tp_profit = getTheoreticProfit(MathAbs(auto_tp_price - base)) - loss;
         }else{
            be = base - getBreakEven(loss);
            plotBreakEvenArrow("breakeven_short", be);
            auto_tp_price = be - pip * stop_distance * auto_tp;
            auto_tp_profit = getTheoreticProfit(MathAbs(auto_tp_price - base)) - loss;
         }
      }
   }
   
   if (auto_tp < 1){
      auto_tp_price = 0;
      auto_tp_profit = 0;
   }
}


/**
* return the entry price of the first order of the pyramid.
* return 0 if we are flat.
*/
double getPyramidBase(){
   double d, max_d, sl;
   int i;
   int type=-1;
   
   // find the stoploss that is farest away from current price
   // we cannot just use the order open price because we might
   // be in resume mode and then all trades would be opened at
   // the same price. the only thing that works reliable is 
   // looking at the stoplossses
   for (i=0; i<OrdersTotal(); i++){
      OrderSelect(i, SELECT_BY_POS, MODE_TRADES);
      if (isMyOrder(magic) && OrderType() < 2){
         d = MathAbs(Close[0] - OrderStopLoss());
         if (d > max_d){
            max_d = d;
            sl = OrderStopLoss();
            type = OrderType();
         }
      }
   }
   
   if (type == OP_BUY){
      return(sl + pip * stop_distance);
   }
   
   if (type == OP_SELL){
      return(sl - pip * stop_distance);
   }
   
   return(0);
}

double getPyramidBase1(){
   int i;
   double pmax = -999999;
   double base = 0;
   for (i=0; i<OrdersTotal(); i++){
      OrderSelect(i, SELECT_BY_POS, MODE_TRADES);
      if (isMyOrder(magic) && OrderType() < 2){
         if (OrderProfit() > pmax){
            base = OrderOpenPrice();
            pmax = OrderProfit();
         }
      }
   }
   return(base);
}

/**
* return the floating profit that would result if
* price would be the specified distance away from
* the base of the pyramid
*/ 
double getTheoreticProfit(double distance){
   int n = MathFloor(distance / (stop_distance * pip));
   double remain = distance - n * stop_distance * pip;
   int mult = n * (n + 1) / 2;
   double profit = MarketInfo(Symbol(), MODE_TICKVALUE) * lots * stop_distance * points_per_pip * mult;
   profit = profit + MarketInfo(Symbol(), MODE_TICKVALUE) * lots * (remain/Point) * (n + 1);
   return(profit);
}

/**
* return the price move relative to base required to compensate realized losses
* FIXME: This algorithm does not qualify as "elegant", not even remotely. 
*/
double getBreakEven(double loss){
   double i = 0;
   
   while(true){
      if (getTheoreticProfit(pip * i) > loss){
         break;
      }
      i += stop_distance;
   }
   
   i -= stop_distance;
   while(true){
      if (getTheoreticProfit(pip * i) > loss){
         break;
      }
      i += 0.1;
   }

   return(pip * i);
}

int start(){
   static int numbars;
   
   if (IsTesting() && !initCalled) {
      init();
   }
   
   onTick();
   if (Bars == numbars){
      return(0);
   }
   numbars = Bars;
   onOpen();
   return(0);
}

void setGlobal(string key, double value){
   GlobalVariableSet(name + magic + "_" + key, value);
}

double getGlobal(string key){
   return(GlobalVariableGet(name + magic + "_" + key));
}

void checkForStopReduction() {   
   if (!running) return;
   
   if (level==0) { // SOLO SE LEVEL=0 VALUTIAMO SE CAMBIARE LO STOP!!!!
      
      if (min_stop_distance<=0 || !dynamicStopDistance) return;
      
      // se ho perso devo aumentare di 5 pips lo stop,
      // ho perso se il floating profit era negativo prima di passare a level 0
      
      double prevStopDistance = stop_distance;
      
      if (lastFloatingWasNegative) {
         lastFloatingWasNegative = false;
         stop_distance+=5;
         stopAlreadyReduced = true;
      }
      
      // altrimenti riduco di 1 pip all'ora (solo se il prezzo é sufficientemente lontano
      
      double newStopDistance = stop_distance-1;
      if (newStopDistance>=min_stop_distance) {
         if (TimeMinute(TimeLocal())==0) {
            if (!stopAlreadyReduced) {
               bool canReduce=true;
               // decremento solo se ho un margine di 1/6*newStopDistance nelle due direzioni
               if (Ask + (pip * newStopDistance / 6) >= last_line + newStopDistance*pip){
                  canReduce = false;
               }
               if (Bid - (pip * newStopDistance / 6) <= last_line - newStopDistance*pip){
                  canReduce = false;
               }
               if (canReduce) {
                  stop_distance=newStopDistance; // qui riduco la stop_distance
                  stopAlreadyReduced = true;
               }
            }   
         } else {
            stopAlreadyReduced = false;
         }        
      }
      
      if (prevStopDistance!=stop_distance) {
         Comment("Stop distance changed, pending orders deleted, will be replaced with the next tick");
         closeOpenOrders(OP_SELLSTOP, magic);
         closeOpenOrders(OP_BUYSTOP, magic);
      }
   }
}

/**
* Replacement for the built-in Print(), output to the chart window.
* use the Comments() display to simulate the behaviour of
* the good old print command, useful for debugging.
* text will be appended as a new line on every call
* and if it has reached 20 lines it will start to scroll.
* if clear is set to True the buffer will be cleared.
*/
void maldaLog(string text, bool clear = False) {
   static string print_lines[20];
   static int print_line_position = 0;
   if (IsOptimization()) {
      return(0);
   }
   string output = "\n";
   string space = "                        ";
   int max_lines = 20;
   int i;
   if (clear) {
      for (i = 0; i < max_lines; i++) {
         print_lines[i] = "";
         // print_line_position = 0;
      }
   }

   //if (print_line_position == max_lines) {
      for (i = max_lines-1; i >=0; i--) {
         print_lines[i+1] = print_lines[i];
      }
      // print_line_position--;
   //}

   print_lines[print_line_position] = TimeToStr(TimeCurrent(),TIME_MINUTES) +" "+ text;
   // print_line_position++;

   for (i = 0; i < max_lines; i++) {
      output = output + print_lines[i] + "\n";
   }

   output = stringReplace(output, "\n", "\n" + space);
   stringToAppendToInfo = output;
}