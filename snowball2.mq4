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
extern int stop_distance = 5;
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
extern bool useMAEntry=false;
extern bool useMAExit=false;
extern int useMA_Period=14;
extern int MA_NumBarsToReenableEntry=4;
////////////////////////////////////////
extern int exitBars=0;
extern int exitBarsLevel=2;
extern bool exitBarsHeikenAshi=true;
////////////////////////////////////////
extern bool useDailyCycle=false;
////////////////////////////////////////
extern bool    BREAKEVEN=false;
extern double  BREAKEVEN_ARM_PIPS=5;
extern double  BREAKEVEN_EXECUTE_PIPS=-5;
////////////////////////////////////////
extern int START_HOUR = 0;
extern int START_MINUTES = 0;
extern int END_HOUR = 24;
extern int END_MINUTES = 0;
////////////////////////////////////////
extern double FOLLOW_PRICE_PIPS_X_MINUTE=0;
int FOLLOW_PRICE_minutePriceMoved=-1;
int FOLLOW_PRICE_secondsCenterMoved=-1;
double FOLLOW_PRICE_minutePriceValue=0;
///////////////////////////////////////
extern bool IS_RENKO_CHART = true;

extern double ACCOUNT_EURO = 350;
extern double RISK_STOPDISTANCE_DIVISOR = 2;
extern bool NO_STOPS = true;
extern double MAX_SPREAD_PIPS = 2.5;

extern double ACCOUNT_PROFIT_TARGET = 30;

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

#define FAKE_STOPLOSS_PIPS 100

#define HALOW       1
#define HAHIGH      0
#define HAOPEN      2
#define HACLOSE     3

#define HAcolor1  Red
#define HAcolor2  White
#define HAcolor3  Red
#define HAcolor4  White

double HALow;
double HAHigh;
double HAClose;
double HAOpen;

void getHeikenAshiValues(int candleIndex) {
   HALow = iCustom(NULL,0,"Heiken Ashi", HAcolor1,HAcolor2,HAcolor3,HAcolor4, HALOW, candleIndex);
   HAHigh = iCustom(NULL,0,"Heiken Ashi", HAcolor1,HAcolor2,HAcolor3,HAcolor4, HAHIGH, candleIndex);
   HAClose = iCustom(NULL,0,"Heiken Ashi", HAcolor1,HAcolor2,HAcolor3,HAcolor4, HACLOSE, candleIndex);
   HAOpen = iCustom(NULL,0,"Heiken Ashi", HAcolor1,HAcolor2,HAcolor3,HAcolor4, HAOPEN, candleIndex);

   if (HAClose>HAOpen) {
      double help = HALow;
      HALow = HAHigh;
      HAHigh = help;
   }   
}

#define NUMBARSFORTREND 8
int getLastTrendIndex(int direction) {
   int shiftStart = 0; int iCount = 0;
   
   // look back
   for (int i = 1; i<Bars && iCount<NUMBARSFORTREND; i++) {
      getHeikenAshiValues(i);
      if (direction*HAClose>direction*HAOpen) {
         if (shiftStart==0) {
            shiftStart = i;
         }
         iCount++;
      } else {
         shiftStart=0;
         iCount = 0;
      }
   }
   
   return (shiftStart);
}

int getShiftOfLastTrend(int direction,double &outValue) {
  
   int shiftStart = getLastTrendIndex(direction); // 1==UP -1==DOWN
   
   // maldaLog("ShiftStart="+shiftStart);
   
   if (direction>0) {
      outValue = 0;
   } else {
      outValue = 100000;
   }
   int iRes = 0;
   while (iRes!=shiftStart) {
      iRes = shiftStart;
      for (int i=-NUMBARSFORTREND;i<=NUMBARSFORTREND;i++) {
         int checkIndex = i+iRes;
         if (checkIndex<Bars && checkIndex>0) {
            getHeikenAshiValues(checkIndex);
            if (direction==1) { 
               if (HAHigh>outValue) {
                  outValue = HAHigh;
                  shiftStart = checkIndex;
               }
            }
            if (direction==-1) {
               if (HALow<outValue) {
                  outValue=HALow;
                  shiftStart = checkIndex;
               }
            }
         }  
      }
   }
   
   
   return (iRes);
}

int findOtherSide(int direction, int shiftStart,double &outValue) {
   
   outValue = 0;
   if (direction<0) outValue = 100000;
   
   bool candle1found = false;
   int candle1shift = -1;
   int i;
   for (i=shiftStart-1;i>0;i--) {
      getHeikenAshiValues(i);
      if (direction*HAClose>direction*HAOpen) { // candela blu con direction==1, candela nera non direction==-1
         candle1found = true;
         if (direction==-1 && outValue>HALow) {
            outValue = HALow;
            candle1shift = i;
         } else if (direction==1 && outValue<HAHigh) {
            outValue = HAHigh;
            candle1shift = i;
         }
      }
   }
   if (!candle1found) return (-1);
   
   // trova candela opposta con chiusura dentro alle minibollingher (medie mobili sel prezzo alto e basso
   
   double MA;
   bool candle2found = false;
   for (i=candle1shift-1;i>0;i--) {
      getHeikenAshiValues(i);
      if (direction==-1 && (HAClose>HAOpen)) {
         MA = iMA(NULL,0,5,0,MODE_SMMA, PRICE_LOW, i);
         if (HAClose>MA) {
            candle2found = true;
         }
      } else if (direction==1 && (HAClose<HAOpen)) {
         MA = iMA(NULL,0,5,0,MODE_SMMA, PRICE_HIGH, i);
         if (HAClose<MA) {
            candle2found = true;
         }
      }
   }
   
   if (!candle2found) return (-1);   
   
   return (candle1shift);
}

#define NO_SUPPORT -1
#define NO_RESISTANCE 1000000

double support=NO_SUPPORT; int supportShift = 0;
double resistance =NO_RESISTANCE; int resistanceShift = 0;

void resetSupportAndResistance() {
   support = NO_SUPPORT; // <== questi default fanno si che sia impossibile che il prezzo rompa il supporto/resistenza
   resistance = NO_RESISTANCE;
   supportShift=0;
   resistanceShift=0;
}

void findSupportAndResistance(double &support,double &resistance) {
   double high=0,low=0;
   
   int shiftUp;
   int shiftDown;
   
   if (resistance!=NO_RESISTANCE && support!=NO_SUPPORT) return;
   
   if (resistance==NO_RESISTANCE && support==NO_SUPPORT) {
      shiftUp = getShiftOfLastTrend(1,high);
      shiftDown = getShiftOfLastTrend(-1,low); 
   
      if (shiftUp<shiftDown) {
         // ultimo trend é stato UP
         resistance = high; resistanceShift = shiftUp;
      }
      
      if (shiftDown<shiftUp) {
         // ultimo trend é stato DOWN
         support = low; supportShift = shiftDown; 
      }
   } 
   
   if (resistance!=NO_RESISTANCE) {
      // a partire da shiftUP, cerca il low (candela nera che sia seguita da candela blu con corpo dentro la media)
      shiftDown = findOtherSide(-1,resistanceShift,low);
      if (shiftDown>0) {
         support = low;
         supportShift = shiftDown;
      }
   }
   
   if (support!=NO_SUPPORT) {
      shiftUp = findOtherSide(1, supportShift, high);
      if (shiftUp>0) {
         resistance = high;
         resistanceShift = shiftUp; 
      }
   }
   
   if (resistance!=NO_RESISTANCE) { 
      place_SL_Line(resistance,"highResistance","Resistance");
   } else {
      ObjectDelete("highResistance");
   }
   if (support!=NO_SUPPORT) {
      place_SL_Line(support,"lowSupport","Support");
   } else {
      ObjectDelete("lowSupport");
   }
   
}

void tradeRenko() {

   if (!IS_RENKO_CHART) return;

   // return (0);

   bool isLong=false;
   bool isShort=false;
   if (getNumOpenOrders(OP_BUY, magic)>0) {
      isLong = true;
   } else if (getNumOpenOrders(OP_SELL, magic)>0) {
      isShort = true;
   }

   if (isLong||isShort) { 
      resetSupportAndResistance();
   }

   if (!(isLong||isShort)) {
      
      findSupportAndResistance(support,resistance);

      // verifica se posso entrare
      /*
      if (heikenAshiHasNearOpenWiggle(1)) {
         maldaLog("heikenAshiHasNearOpenWiggle==true!");
         return;
      } 
      */
  
      getHeikenAshiValues(1);
      double HAOpen1 = HAOpen;
      double HAClose1 = HAClose;
      double HAHigh1 = HAHigh;
      double HALow1 = HALow;
   
      getHeikenAshiValues(0);
      double HAOpen0 = HAOpen;
      double HAClose0 = HAClose;
      double HAHigh0 = HAHigh;
      double HALow0 = HALow;  
   
      bool HADirectionUP = (HAClose1>HAOpen1) && (HAClose0>HAOpen0);
      bool HADirectionDown = (HAClose1<HAOpen1) && (HAClose0<HAOpen0);
   
      double RSI = RenkoRSI();
   
      double MACDUp0 = MACD_Colored_v105(0,0);
      double MACDDown0 = MACD_Colored_v105(1,0);
      double MACDSignal0 = MACD_Colored_v105(2,0);
      double MACDHistoGram0 = MACDUp0+MACDDown0; 
   
      double MACDUp1 = MACD_Colored_v105(0,1);
      double MACDDown1 = MACD_Colored_v105(1,1);
      double MACDSignal1 = MACD_Colored_v105(2,1);
      double MACDHistoGram1 = MACDUp1+MACDDown1; 
    
      // maldaLog("RSI="+RSI+" MACDSignal="+MACDSignal0+" MACDUp="+MACDUp0+" MACDDown="+MACDDown0+ "MACDHistogram="+(MACDHistoGram0));
      if (RSI>55) {
         if (HAClose0>resistance && HAClose1>resistance) {  
            if (HADirectionUP) { // blue candles
               // check to  go long
               //start_immediately = true;
               //go(LONG);
               if ((MACDHistoGram0>MACDHistoGram1) && (MACDHistoGram1>MACDSignal1)) {
                  maldaLog("RENKO GO LONG!!!");
                  Alert(Symbol6()+" RENKO GO LONG!!!");
               }
            } else {
               maldaLog("HA direction NOT up!!!");
            }
         }
      }
      if (RSI<45) { 
         if (HAClose0<support && HAClose1<support) { 
            if (HADirectionDown) { // black candles
               // check to go short
               // start_immediately = true;
               // go(SHORT);
               if ((MACDHistoGram0<MACDHistoGram1) && (MACDHistoGram1<MACDSignal1)) {
                  maldaLog("RENKO GO SHORT!!!");
                  Alert(Symbol6()+" RENKO GO SHORT!!!");
               } 
            } else {
               maldaLog("HA direction NOT down!!!");
            }
         }
      }
   }
}

int getStopDistance() {
   if (NO_STOPS) {
      return (FAKE_STOPLOSS_PIPS);
   } else {
      return (stop_distance);
   }
}

double calcStopLossByPrice(int op,double price) {
   if (op==OP_SELLSTOP || op==OP_SELLLIMIT || op==OP_SELL) {
      return (price+getStopDistance()*pip);
   } else { // BUY 
      return (price-getStopDistance()*pip);
   }
}

double calcPriceByStopLoss(int op, double SL) {
  if (op==OP_SELLSTOP || op==OP_SELLLIMIT || op==OP_SELL) { // stop above
      return (SL-getStopDistance()*pip);
   } else { // BUY (stop below) 
      return (SL+getStopDistance()*pip);
   } 
}

double getOrderStopLoss(int op,double SL) {
   if (!NO_STOPS) return (SL);
   if (op==OP_SELLSTOP || op==OP_SELLLIMIT || op==OP_SELL) {
      return (SL+(getStopDistance()-stop_distance)*pip);
   } else { // BUY 
      return (SL-(getStopDistance()-stop_distance)*pip);   
   }
}

double STOP_FOR_1_PERCENT_RISK() {

   double toDestCurrency;
   double PointValue;
   double pipValueInDollars;

   double eu_ask = MarketInfo("EURUSD",MODE_ASK); 
   double eu_bid = MarketInfo("EURUSD",MODE_BID);
   double EURUSD = (eu_ask + eu_bid) / 2;

   double lotSize = MarketInfo(Symbol6(),MODE_LOTSIZE);
   double TradeSize = getLotsOnTable(magic);
   if (TradeSize==0) {
      TradeSize = lots;
   }  

   /*
   maldaLog("lotSize:"+lotSize);
   maldaLog("pip:"+pip);
   maldaLog("tradeSize(lots):"+TradeSize);
   */

   double currentQuote = ((Bid+Ask)/2);

   // COPPIE xxxUSD
   if (StringSubstr(Symbol6(),3,3)=="USD") {   
      pipValueInDollars = lotSize * pip * TradeSize;   
      // maldaLog("lotSize*pip*TradeSize="+lotSize+"*"+pip+"*"+TradeSize);         
   // COPPIE USDxxx
   } else if (StringSubstr(Symbol6(),0,3)=="USD") {
      pipValueInDollars = lotSize * pip * TradeSize / currentQuote; 
   } else { // COPPIE xxxyyy
      string baseCurr = StringSubstr(Symbol6(),0,3)+"USD";
      double baseQuote= (MarketInfo(baseCurr,MODE_ASK)+MarketInfo(baseCurr,MODE_BID))/2; 
      // maldaLog("baseQuote:"+baseQuote);
      pipValueInDollars = lotSize * pip * TradeSize * baseQuote / currentQuote;  
   }

   // maldaLog("pipValueInDollars:"+pipValueInDollars);

   double MaximumCapitalInDollars = ACCOUNT_EURO * EURUSD / 100;   
   
   double StopPips = MaximumCapitalInDollars / pipValueInDollars;
   return (StopPips);
}

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
      stop("checkBreakOut");
   }  
   
   go(dir);
   
}

void defaults(){

   IS_ECN_BROKER = true; // different market order procedure when resuming after pause

   if (RISK_STOPDISTANCE_DIVISOR>0) {
      stop_distance = STOP_FOR_1_PERCENT_RISK()/RISK_STOPDISTANCE_DIVISOR;
   }
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

   points_per_pip = pointsPerPip();
   pip = Point * points_per_pip;

   defaults();
   
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
   
   checkDailyCycle();
   
   if (stopped) {
      checkButtons();
      info();
      return(0);
   }

   recordEquity(name+Symbol6(), PERIOD_H1, magic);
   //checkOanda(magic, oanda_factor);
   checkLines();
   checkButtons();
   checkBreakout();
   trade();
   tradeRenko();
   info(); // calcola lastFloating
   checkAutoTP();
   checkStopToBreakEven();
   checkBreakEven2();
   checkProfitTarget(); // usa lastFloating
   checkExitBars();
   checkMA();
   
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
   
   if (!BREAKEVEN) {
      ObjectDelete("BE2");
      return;
   }
   
   double stopLine=-1;
   
   bool doCycle = true;
   while (doCycle) {
      int total = OrdersTotal();
      doCycle = false;
      for (int cnt = 0; cnt < total; cnt++) {      
         OrderSelect(cnt, SELECT_BY_POS, MODE_TRADES);
         if (isMyOrder(magic)) {
               int type = OrderType();
               int clr;
               
               bool armed = false;
               double armPrice;
               
               if (type == OP_BUY){
                  armPrice = OrderOpenPrice()+ pip * (BREAKEVEN_ARM_PIPS);
                  clr = CLR_SELL_ARROW;
                  if (armPrice<=maxPrice) armed = true;
               }
        
               if (type == OP_SELL){
                  armPrice = OrderOpenPrice()- pip * (BREAKEVEN_ARM_PIPS);
                  clr = CLR_BUY_ARROW;
                  if (armPrice>=minPrice) armed = true;
               }
               // if (armed) maldaLog("BreakEven armed..."); 
   
               double orderPrice; // lo calcolo in base allo stoploss perché dopo un resume 
                                  // i prezzi sono tutti uguali mentre gli stop loss sono diversi  
        
               bool isToClose = false;
               
               if (armed) {     
                  if (type == OP_BUY){
                     orderPrice = OrderOpenPrice()+ pip * (BREAKEVEN_EXECUTE_PIPS);
                     clr = CLR_SELL_ARROW;
                     if (orderPrice>=Bid) isToClose = true;
                     if (stopLine<0 || stopLine<orderPrice) stopLine = orderPrice;
                  }
        
                  if (type == OP_SELL){
                     orderPrice = OrderOpenPrice()- pip * (BREAKEVEN_EXECUTE_PIPS);
                     clr = CLR_BUY_ARROW;
                     if (orderPrice<=Ask) isToClose = true;
                     if (stopLine<0 || stopLine>orderPrice) stopLine = orderPrice;
                  }
               }
            
               if (isToClose) {
                  double SL = getOrderStopLoss(type,OrderStopLoss()); //OK
               
                  maldaLog("BE2: Close order "+OrderTicket()+" at BreakEven: "+orderPrice);
                  orderCloseReliable(OrderTicket(), OrderLots(), 0, 999, clr);
                  
                  closeOpenOrders(OP_SELLSTOP, magic);
                  closeOpenOrders(OP_BUYSTOP, magic);
                  
                  // quando si esegue una chiusura per breakeven,
                  // il massimo/minimo prezzo raggiunto si imposta=al prezzo corrente
                  maxPrice=Bid;
                  minPrice=Ask;
                  
                  placeLine(SL);
                  
                  doCycle=true;
                  break; // cycle again starting from 0 (HELLO FIFO!)
               }
            }
         }
   }
   
   if (stopLine>0) {
      place_SL_Line(stopLine,"BE2","BreakEven2");
   } else {
      ObjectDelete("BE2");
   }
   ifLevel0_disableMAEntry("checkBreakEven2");
   
}

void ifLevel0_disableMAEntry(string who) {
   // calculate global variable level here // FIXME: global variable side-effect hell.
   int newLevel = getNumOpenOrders(OP_BUY, magic) - getNumOpenOrders(OP_SELL, magic);
   if (newLevel == 0 && useMAEntry) {
      useMAEntry = false;
      maldaLog("Warning: "+who+" disabled MA Entry!");  
      setCountDownToReenableEntry(MA_NumBarsToReenableEntry);
   }   
}

int countDownToReenableMAEntry=0;
void onOpen(){
   if (countDownToReenableMAEntry>0) {
      countDownToReenableMAEntry--;
      if (countDownToReenableMAEntry==0) {
         useMAEntry = true;
      }
   }
   
   calcStopped();
   
}

void calcStopped() {
   int minutesStart = START_HOUR * 60 + START_MINUTES;
   int minutesEnd = END_HOUR * 60 + END_MINUTES;
   
   int currentMinute = TimeHour(TimeLocal()) * 60 + TimeMinute(TimeLocal());
   
   if (currentMinute >= minutesStart && currentMinute < minutesEnd) {
      stopped = false;
   } else {
      stopped = true;
   }
}

void checkDailyCycle() {
   static bool justRestarted;
      
   if (!useDailyCycle) return(0);
   
   if (Hour()==0) {
      if (!justRestarted) {
         if (running) stop("checkDailyCycle");
         maldaLog("checkDailyCycle goes BIDIR");
         go(BIDIR);
         justRestarted = true;
      }         
   } else {
      justRestarted = false;
   }
   
   
}

void setCountDownToReenableEntry(int nBars) {
   maldaLog("MA Entry will be enabled after "+nBars+" bars");
   countDownToReenableMAEntry = nBars;       
}

void checkMA() {
   if (!(useMAEntry || useMAExit)) {
      ObjectDelete("exitMA");
      return;
   }
   
   int Current = 0; // 0 per ogni tick, 1 per penultima bar
   double close = iClose(NULL, 0, Current+0);
   
   double maValue = iMA(NULL,0,useMA_Period,3,MODE_LWMA,PRICE_TYPICAL,0);
   
   if (level>0 && useMAExit) {
      if (close<maValue) {
         maldaLog("MA ("+useMA_Period+") STOP! (profit= "+lastFloating+")");
         stop("checkMA");
      }
      place_SL_Line(maValue,"exitMA","Exit MA");
   } else if (level<0 && useMAExit) {
      if (close>maValue) {
         maldaLog("MA ("+useMA_Period+") STOP! (profit= "+lastFloating+")");
         stop("checkMA");
      }
      place_SL_Line(maValue,"exitMA","Exit MA");
   } else if (level==0 && useMAEntry) {
      // ENTRY ?
      if (close>maValue+pip*10) { // LONG 
         if (running) stop("checkMA");
         start_immediately = true;
         maldaLog("MA("+useMA_Period+") LONG entry!");
         go(LONG);      
      } else if (close<maValue-pip*10) { // SHORT 
         if (running) stop("checkMA");
         start_immediately = true;
         maldaLog("MA ("+useMA_Period+")SHORT entry!");
         go(SHORT);   
      }
   }
   if (level==0) ObjectDelete("exitMA");
   
}

void checkExitBars() {
   static int maxAbsLevel=0;

   if (!running || level==0 || exitBars==0) {
      ObjectDelete("exitBars");
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
            place_SL_Line(Range_low,"exitBars","Exit Bars");
         } if (level<0) {
            double Range_high = High[iHighest(NULL,0,MODE_HIGH,exitBars,1)];
            if (close>Range_high) shouldStop=true; 
            place_SL_Line(Range_high,"exitBars","Exit Bars");
         }
      } else { // HEIKENASHI
         shouldStop = checkExitBars_HeikenAshi(close);
      }
   }
   
   if (shouldStop) {
      maldaLog("ExitBars STOP!");
      stop("checkExitBars");
   }
}



bool heikenAshiHasNearOpenWiggle(int candleIndex) {
   
   getHeikenAshiValues(candleIndex);
   
   // maldaLog("HAClose:"+HAClose+" HAOpen:"+HAOpen+" HALow:"+HALow+" HAHigh:"+HAHigh);
   if ((HAClose>HAOpen) && (HALow<HAOpen)) {
      return (true);
   }
   
   if ((HAClose<HAOpen) && (HAHigh>HAOpen)) {
      return(true);
   }
   
   return (false);
}

double RenkoRSI() {
   int shift = 0;
   int period = 10;
   double rsi = iRSI(NULL,0,period,PRICE_CLOSE,shift);
   return (rsi);
}

double MACD_Colored_v105(int bufferIndex,int candleIndex) {

   // questi devono corrispondere nell'ordine e tipo ai parametri dell'indicatore, e vanno passati alla funzione iCustom 
   string Alert_On="";
   bool EMail_Alert=false;
   int Max_Alerts=1;
   int Alert_Before_Minutes=15;
   int Alert_Every_Minutes=5;
   bool ShowSignal=false;
   int FastEMA=12;
   int SlowEMA=26;
   int SignalSMA=9;
   int FontSize=0;
   color FontColor=Black;

   // SetIndexBuffer(0,MacdBufferUp);
   // SetIndexBuffer(1,MacdBufferDn);
   // SetIndexBuffer(2,SignalBuffer);

   double value = iCustom(NULL,0,"MACD_Colored_v105", Alert_On,EMail_Alert,Max_Alerts,
                           Alert_Before_Minutes, Alert_Every_Minutes,ShowSignal,FastEMA,SlowEMA,SignalSMA,FontSize,FontColor,
                           bufferIndex, candleIndex);
                           
   return (value);
}

bool checkExitBars_HeikenAshi(double close) {

   bool shouldStop = false;   

   int i;
   if (level>0) {
   
      // double Heiken_op = iCustom(NULL,0,"Heiken Ashi",Red,White,Red,White,2,0);
      // double Heiken_cl = iCustom(NULL,0,"Heiken Ashi",Red,White,Red,White,3,0);
      double Range_low = 10000000;
      for (i=1;i<=exitBars;i++) {
         getHeikenAshiValues(i);
         if (HALow < Range_low) Range_low = HALow;
      }
      if (close<Range_low) shouldStop=true;
      place_SL_Line(Range_low,"exitBars","Exit Bars HA");
   } if (level<0) {
      double Range_high = 0;
      for (i=1;i<=exitBars;i++) {
         getHeikenAshiValues(i);
         if (HAHigh > Range_high) Range_high = HAHigh;
      }
      if (close>Range_high) shouldStop=true; 
      place_SL_Line(Range_high,"exitBars","Exit Bars HA");
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
   ObjectDelete("toggle_MA");
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

void stop(string who){
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
   ifLevel0_disableMAEntry(who+"->stop");
}

void closeTrades(string who) {
   closeOpenOrders(OP_BUY,-1);
   closeOpenOrders(OP_SELL,-1);
   ifLevel0_disableMAEntry(who+"->closeTrades");
}

void go(int mode){
   startArrow();
   deleteStartButtons();
   running = true;
   direction = mode;
   // maldaLog("go ==> FOLLOW_PRICE_minutePriceMoved=-1");
   FOLLOW_PRICE_minutePriceMoved=-1;
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
         buy(lots, sl, 0, magic, comment, "resume");
      }
   }
   
   if (level < 0){
      // maldaLog("RESUMING SHORT from level:"+(-level));
      for (i=1; i<=-level; i++){
         sl = line + pip * i * stop_distance;
         // maldaLog(" selling at "+NormalizeDouble(Bid,5)+" with stop loss="+sl);
         sell(lots, sl, 0, magic, comment, "resume");
      }
   }
      
   ObjectDelete("paused_level");
}

void checkLines(){
   if (crossedLine("stop")){
      maldaLog("Crossed line 'stop'");
      stop("checkLines");
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
      if (running) stop("checkLines");
      start_immediately = true;
      go(LONG);
   }
   
   if (crossedLine("short")) {
      maldaLog("Crossed line 'short'");
      if (running) stop("checkLines");
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
         stop("checkButtons");
      }
      if (labelButton("pause", 15, 15*2, 1, "pause", Yellow)){
         pause();
      }
      if (labelButton("close", 15, 15*3, 1, "close", White)) {
         closeTrades("checkButtons");
      }
      
      if (labelButton("toggle_breakout2", 15, 15*4, 1, getBreakOutButtonDescription(), getBreakOutButtonColor())) {
         toggleBreakOut();
      }
   }
   
   bool reButton = true; bool needRedraw=false;
   while (reButton) {
      reButton = false;
      if (labelButton("toggle_MA", 15, 16*8,1, getToggleMAButtonDescription(), getToggleMAButtonColor())) {
         if (!useMAEntry && !useMAExit) { 
            useMAEntry = true;
            useMAExit = false; 
         } else if (useMAEntry && !useMAExit) {
            useMAEntry = true;
            useMAExit = true;
         } else if (useMAEntry && useMAExit) {
            useMAEntry = false;
            useMAExit = true;
         } else {
            useMAEntry = false;
            useMAExit = false;
         }
         deleteMAButtons();
         reButton=true;
         needRedraw=true;
      }
   }
   if (needRedraw) WindowRedraw();
   
}

string getToggleMAButtonDescription() {
   string description = "Trade MA("+useMA_Period+"):";
   string OFF = " OFF";
   if (useMAEntry) {
      description = description + "Entry ";
      OFF = "";
   } else if (countDownToReenableMAEntry>0) {
      description = description+ "Entry sleep for "+countDownToReenableMAEntry+" bars.";  
      OFF = "";
   }
   if (useMAExit) {
      description = description + "Exit";
      OFF = ""; 
   }
   return (description+OFF);
} 

color getToggleMAButtonColor() {
   if (useMAEntry || useMAExit) return (Green);
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
            stop("checkAutoTP");
         } else {
            closeTrades("checkAutoTP");
            auto_tp_price = 0;
         }
      }
      if (level < 0 && Close[0] <= auto_tp_price){
         if (stopWhenAutoTP) {
            stop("checkAutoTP");
         } else {
            closeTrades("checkAutoTP");
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
                  orderPrice = getOrderStopLoss(type,OrderStopLoss())+ pip * (stop_distance+breakEvenOffset); //OK
                  clr = CLR_SELL_ARROW;
                  if (orderPrice>=Bid) isToClose = true;
                  // isToClose = true;
               }
        
               if (type == OP_SELL){
                  orderPrice = getOrderStopLoss(type,OrderStopLoss())- pip * (stop_distance+breakEvenOffset); //OK
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
      closeTrades("checkProfitTarget");
   }
   if (ACCOUNT_PROFIT_TARGET>0.1 && AccountProfit()>ACCOUNT_PROFIT_TARGET) {
      closeTrades("checkProfitTarget(AccountProfit)");
   } 
}

void placeLine(double price){
   horizLine("last_order", price, clr_gridline, SP + "grid position");
   last_line = price;
   WindowRedraw();
}

void place_SL_Line(double price,string name,string description) {
   horizLine(name,price,LightSalmon, description);
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

bool checkSpread() {
   double spread = MarketInfo(Symbol6(),MODE_SPREAD)/points_per_pip;
   
   string text = "Spread: "+DoubleToStr(spread,1);
   label("lblSpread", 50, 20, 2, text, Gray); 
   ObjectSet("lblSpread", OBJPROP_FONTSIZE, 20);
   bool spreadTooBig = false;
   
   if (spread>MAX_SPREAD_PIPS) {
      closeOpenOrders(OP_SELLSTOP,magic);
      closeOpenOrders(OP_BUYSTOP,magic);
      spreadTooBig = true;
      ObjectSet("lblSpread",OBJPROP_COLOR,Red);
   }
   
   return (spreadTooBig);
}

double highLimit,lowLimit;

/**
* manage all the entry order placement
*/
void trade(){
   double start;
   static int last_level;
   
   bool bigSpread = checkSpread();
   
   if (lineMoved()){
      maldaLog("Closing open orders because line moved...");
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
            stop("trade");
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
            // maldaLog("SHORT and Ask>start ==> FOLLOW_PRICE_minutePriceMoved =-1");
            FOLLOW_PRICE_minutePriceMoved = -1;
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
            // maldaLog("LONG and Bid<start ==> FOLLOW_PRICE_minutePriceMoved =-1");
            FOLLOW_PRICE_minutePriceMoved = -1;
         }
         
         if (!bigSpread) {
            // make sure first long orders are in place
            if (direction == BIDIR || direction == LONG){
               longOrders(start,"trade.1");
            }
         
            // make sure first short orders are in place
            if (direction == BIDIR || direction == SHORT){
               shortOrders(start,"trade.1");
            }
         }
         
         if (direction == BIDIR) {
            followPrice(start,NormalizeDouble((Bid+Ask)/2,Digits));
            // int FOLLOW_PRICE_minutePriceMoved=-1;
            // double FOLLOW_PRICE_minutePriceValue=0;
         } else if (direction == SHORT) {
            followPrice(start, Ask);
         } else if (direction == LONG) {
            followPrice(start, Bid);   
         }
      }
      
      if (!bigSpread) {
         // are we already long?
         if (level > 0){
            // make sure the next long orders are in place
            longOrders(start,"trade.2");
         }

         // are we short?
         if (level < 0){
            // make sure the next short orders are in place
            shortOrders(start,"trade.2");
         }
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
         // maldaLog("level!=0 ==> FOLLOW_PRICE_minutePriceMoved =-1");
         FOLLOW_PRICE_minutePriceMoved=-1;
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
      // maldaLog("Not running ===> minutePriceMoved=-1");
      FOLLOW_PRICE_minutePriceMoved=-1;
      placeLine(Bid);
   }
   
   deleteDuplicatedOrders(magic,start);
}

void deleteDuplicatedOrders(int magic,double start) {
   
   int numOpenOrders = getNumOpenOrders(-1,magic);
   if (numOpenOrders<=0) return(0);
     
   int tickets[];
   double prices[];
   
   ArrayResize(tickets, numOpenOrders);
   ArrayResize(prices, numOpenOrders);
   
   int total = OrdersTotal();
   
   // collect order tickets and prices
   int idx=0;
   for (int cnt = 0; cnt < total; cnt++) {
      OrderSelect(cnt, SELECT_BY_POS, MODE_TRADES);
      if (isMyOrder(magic)) {
         int order_type = OrderType();
         if (order_type == OP_BUYSTOP || order_type == OP_SELLSTOP || order_type == OP_BUYLIMIT || order_type == OP_SELLLIMIT) {
            tickets[idx] = OrderTicket();
            prices[idx] = OrderOpenPrice();
            idx++;
         }
      }
   }
   
   for (int i=0;i<idx;i++) {
      bool deleted = false;
      
      // delete out-of-grid orders 
      double distanceFromExactGrid = MathMod((prices[i]-start)/pip,stop_distance);
      if (MathAbs(distanceFromExactGrid)>1 && (stop_distance-MathAbs(distanceFromExactGrid))>1) {
         // maldaLog("Deleting out-of-grid order..."+distanceFromExactGrid);
         double d = -distanceFromExactGrid;
         maldaLog("Snap out-of-grid order to grid..."+tickets[i]+" d="+d);
         // orderDeleteReliable(tickets[i]);
         if (OrderSelect(tickets[i],SELECT_BY_TICKET,MODE_TRADES)) {
            orderModifyReliable(
                  OrderTicket(),
                  OrderOpenPrice() + d,
                  OrderStopLoss()  + d, //OK
                  0,
                  0,
                  CLR_NONE
               );
            }
         // deleted = true;
      }
      
      // delete duplicate orders
      for (int j=i+1;j<idx && !deleted;j++) {
         double delta = MathAbs(NormalizeDouble(prices[i],Digits)-NormalizeDouble(prices[j],Digits));
         // maldaLog("Delta:"+delta+" pip:"+pip);
         if (delta<=pip) {
            maldaLog("Deleting duplicated order..."+tickets[j]);
            orderDeleteReliable(tickets[j]);
         }
      }   
   }

}

#define highLimitName "followPriceLimitHigh"
#define lowLimitName "followPriceLimitLow"

void followPrice(double start, double currentPrice) {
   if (FOLLOW_PRICE_PIPS_X_MINUTE<=0) {
      ObjectDelete(highLimitName);
      ObjectDelete(lowLimitName);
      return;
   }
    
   int minute = TimeMinute(TimeLocal());
   int seconds = TimeSeconds(TimeLocal());
   if (minute!=FOLLOW_PRICE_minutePriceMoved) {
      maldaLog("Changed FOLLOW_PRICE_minutePriceValue at minute:"+minute+"!="+FOLLOW_PRICE_minutePriceMoved);
      
      FOLLOW_PRICE_minutePriceValue=currentPrice;
      if (FOLLOW_PRICE_minutePriceMoved!=-1) {
         if (FOLLOW_PRICE_minutePriceValue>highLimit) FOLLOW_PRICE_minutePriceValue = highLimit;
         if (FOLLOW_PRICE_minutePriceValue<lowLimit) FOLLOW_PRICE_minutePriceValue = lowLimit;
      }
      FOLLOW_PRICE_minutePriceMoved = minute;
      FOLLOW_PRICE_secondsCenterMoved=-1;
   } else {
      // maldaLog("FOLLOW_PRICE_minutePriceValue not changed."+minute);
   }
   
   highLimit = NormalizeDouble(FOLLOW_PRICE_minutePriceValue+FOLLOW_PRICE_PIPS_X_MINUTE*pip,Digits);
   lowLimit = NormalizeDouble(FOLLOW_PRICE_minutePriceValue-FOLLOW_PRICE_PIPS_X_MINUTE*pip,Digits);
   
   if (seconds!=FOLLOW_PRICE_secondsCenterMoved) {
      FOLLOW_PRICE_secondsCenterMoved=seconds;
   
      double delta = currentPrice-FOLLOW_PRICE_minutePriceValue;
      
      if (MathAbs(delta)>0) {
      
         double desiredPrice = FOLLOW_PRICE_minutePriceValue+delta;
         
         if (desiredPrice>highLimit) desiredPrice = highLimit;
         if (desiredPrice<lowLimit) desiredPrice = lowLimit;
         
         double deltaFromStart = NormalizeDouble(desiredPrice-start,Digits);
      
         if (deltaFromStart!=0) {
            moveOrders(deltaFromStart);
            start+=deltaFromStart;
            placeLine(start);
            maldaLog("Moved orders, delta="+DoubleToStr(deltaFromStart,Digits)+" secs="+seconds);
         }
         
      }
   }
   
   place_SL_Line(highLimit,highLimitName,"Follow price high limit");
   place_SL_Line(lowLimit, lowLimitName,"Follow price low limit");
   
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
   
   double minDelta = 1000000;
   double delta;
   
   string confrontati = "";
   
   // search for a stoploss at exactly one grid distance away from price
   for (i=0; i<total; i++){
      OrderSelect(i, SELECT_BY_POS, MODE_TRADES);
      type = OrderType();
      if (where < 0){ // look only for buy orders (stop below)
         if (isMyOrder(magic) && (type == OP_BUY || type == OP_BUYSTOP)){
            delta = MathAbs(OrderStopLoss()- calcStopLossByPrice(type,price));         
            if (delta<minDelta) minDelta = delta;
            if (isEqualPrice(OrderStopLoss(), calcStopLossByPrice(type,price))){ //OK
               // return(false);
            }
            confrontati=confrontati+","+OrderTicket()+"(SL="+OrderStopLoss()+")";
         }
      }
      if (where > 0){ // look only for sell orders (stop above)
         if (isMyOrder(magic) && (type == OP_SELL || type == OP_SELLSTOP)){
            delta = MathAbs(OrderStopLoss()- calcStopLossByPrice(type,price));
            if (delta<minDelta) minDelta = delta;
            if (isEqualPrice(OrderStopLoss(), calcStopLossByPrice(type,price))){ //OK
              // return(false);
            }
            confrontati=confrontati+","+OrderTicket()+"(SL="+OrderStopLoss()+")";
         }
      }
   }
   
   if (minDelta<=(pip/3)) {
      return(false);
   } else {
      Print("NeedsOrder: "+price+" minDelta="+minDelta+" Confrontati:"+confrontati);
      return(true);
   }
}

/**
* Make sure there are the next two long orders above start in place.
* If they are already there do nothing, else replace the missing ones.
*/
void longOrders(double start, string caller){
   double a = start + stop_distance * pip;
   double b = start + 2 * stop_distance * pip;
   
   if (needsOrder(a, -1)){
      buyStop(lots, a, calcStopLossByPrice(OP_BUY, a), 0, magic, comment, caller+".longOrders.1");
   }
   if (needsOrder(b, -1)){
      buyStop(lots, b, calcStopLossByPrice(OP_BUY, b), 0, magic, comment, caller+".longOrders.2");
   }
}

/**
* Make sure there are the next two short orders below start in place.
* If they are already there do nothing, else replace the missing ones.
*/
void shortOrders(double start, string caller){
   double a = start - stop_distance * pip;
   double b = start - 2 * stop_distance * pip;
   
   if (needsOrder(a, 1)){
      sellStop(lots, a, calcStopLossByPrice(OP_SELL, a), 0, magic, comment, caller+".shortOrders.1");
   }
   if (needsOrder(b, 1)){
      sellStop(lots, b, calcStopLossByPrice(OP_SELL, b), 0, magic, comment, caller+".shortOrders.2");
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
               OrderStopLoss() + d, //OK
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
   
   string stoppedInfo ="";
   if (stopped) stoppedInfo = " (STOPPED)";
   
   Comment("\n" + SP + name + magic + ", " + dir +
           "\n" + SP + Symbol() + " IsTesting:" + IsTesting() + 
           "\n" + SP + "1 pip is " + DoubleToStr(pip, Digits) + " " + Symbol6() +
           "\n" + SP + "stop distance: " + stop_distance + " pip, lot-size: " + DoubleToStr(lots, 2) +
           "\n" + SP + "every stop equals " + DoubleToStr(stop_value, 2) + " " + AccountCurrency() +
           "\n" + SP + "realized: " + DoubleToStr(realized - getGlobal("realized"), 2) + "  floating: " + DoubleToStr(floating, 2) +
           "\n" + SP + "profit: " + DoubleToStr(cycle_total_profit, 2) + " " + AccountCurrency() + "  current level: " + level_abs +
           "\n" + SP + "auto-tp: " + auto_tp + " levels (" + DoubleToStr(auto_tp_price, Digits) + ", " + DoubleToStr(auto_tp_profit, 2) + " " + AccountCurrency() + ")" +
           "\n" + SP + "profit target: "+ profit_target + " AccountProfit target: "+DoubleToStr(ACCOUNT_PROFIT_TARGET,Digits) +
           "\n" + SP + "Trading enabled from " + START_HOUR + ":" + START_MINUTES + " to " + END_HOUR + ":" + END_MINUTES + " local time"+stoppedInfo+
           "\n" + SP + "Stop for 1 percent risk: " + DoubleToStr(STOP_FOR_1_PERCENT_RISK(),3) + " / "+ DoubleToStr(RISK_STOPDISTANCE_DIVISOR,1) + 
           "\n" + SP + "IS RENKO CHART: " + IS_RENKO_CHART +
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
         d = MathAbs(Close[0] - OrderStopLoss()); //OK
         if (d > max_d){
            max_d = d;
            sl = OrderStopLoss(); //OK
            type = OrderType();
         }
      }
   }
   
   if (type==OP_BUY || type==OP_SELL) {
      return (calcPriceByStopLoss(type,sl));
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