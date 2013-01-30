//+-------------------------------------------------------------------+
//|                                           RangeTrader.mq4     |
//|                                  Copyright � 2012, Andrea Maldini |
//|                                                                   |                                      
//+-------------------------------------------------------------------+
#property copyright "Copyright � 2013, Andrea Maldini"
// #property link      ""

#include <common_functions.mqh>

//---- input parameters

extern double     BreakEven       = 25;    // Profit Lock in pips  
extern double     LockGainPips        = 5; 

extern double     BreakEven2    = 50;
extern double     LockGainPips2 = 10;

extern double     autoSLPips = 8;
extern double     autoTPPips = 10;

extern double     scalpPips = 10;

extern double     pipsFromPivot = 1;
extern double     MAX_SPREAD_PIPS = 2.5;

extern double     lots = 0.5;

extern bool       autoActivateTrendLines = false;

bool pivotON = false;
extern bool trailPivot = false;

extern bool channelBreakout = true;
extern int channelBreakoutMinutes = 5;
extern bool forcePivotInsideChannel = true;


double            currentPivot = 0;

int      digit=0;
int      pointsPerPip=0;
double   pip=0;
int magic = 0;

int direction = 0;

bool maON = false;

double profit = 0;

double basePrice=0;
int pipTouches[1000];
int pipTimeStamp[1000];
int currentTimeStamp=0;
datetime tickTime[100000];

int hoursInTickHistory = 4;

datetime last_t;

//+------------------------------------------------------------------+
//| expert initialization function                                   |
//+------------------------------------------------------------------+
int init()
  {
   IS_ECN_BROKER = true; // different market order procedure
//----
   return(0);
  }

// ---- Trailing Stops
void TrailStops()
{        

    Comment("Equity:"+AccountEquity());

    int total=OrdersTotal();
    for (int cnt=0;cnt<total;cnt++)
    { 
     OrderSelect(cnt, SELECT_BY_POS);   
     int mode=OrderType();    
        if ( OrderSymbol()==Symbol() ) 
        {
            if ( mode==OP_BUY )
            {  
               double BuyStop = OrderOpenPrice()-pip*autoSLPips;
               /*
               Comment("Digit: "+digit+" Point: "+Point+ " PointsPerPip:"+pointsPerPip+"\n"+
               "OrderOpenPrice:"+OrderOpenPrice()+"\n"+
               "Stop loss will be at: "+(OrderOpenPrice()+pip*LockGainPips)+
               "BreakEven trigger will be at: "+(OrderOpenPrice()+pip*BreakEven));
               */
               if ( Bid-OrderOpenPrice()>pip*BreakEven ) 
               {
                  BuyStop = OrderOpenPrice()+pip*LockGainPips;
               }
               if ( BreakEven2>BreakEven && ((Bid-OrderOpenPrice())>pip*BreakEven2)) {
                  BuyStop = OrderOpenPrice()+pip*LockGainPips2;
               }
               
               if (OrderStopLoss()<BuyStop || OrderStopLoss()==0) {
                  OrderModify(OrderTicket(),OrderOpenPrice(),
                              NormalizeDouble(BuyStop, digit),
                              OrderTakeProfit(),0,LightGreen);
               }
			      
			   }
            if ( mode==OP_SELL )
            {
               double SellStop = OrderOpenPrice()+pip*autoSLPips;
               /*Comment("Digit: "+digit+" Point: "+Point+ " PointsPerPip:"+pointsPerPip+"\n"+
               "OrderOpenPrice:"+OrderOpenPrice()+"\n"+
               "Stop loss will be at: "+(OrderOpenPrice()-pip*LockGainPips)+
               "BreakEven trigger will be at: "+(OrderOpenPrice()-pip*BreakEven));
               */
               if ( OrderOpenPrice()-Ask>pip*BreakEven ) 
               {
                  SellStop = OrderOpenPrice()-pip*LockGainPips;
               }
               if ( BreakEven2>BreakEven && ((OrderOpenPrice()-Ask)>pip*BreakEven2)) {
                  SellStop = OrderOpenPrice()-pip*LockGainPips2;
               }
               if (OrderStopLoss()>SellStop || OrderStopLoss()==0) {
                  OrderModify(OrderTicket(),OrderOpenPrice(),
   		                  NormalizeDouble(SellStop, digit),
   		                  OrderTakeProfit(),0,Yellow);	 
   		      }   
                 
            }
         }   
      } 
}

// ---- Scan Trades
int ScanTrades()
{   
   int total = OrdersTotal();
   int numords = 0;
   
   direction = 0;
   profit = 0;
   for(int cnt=0; cnt<total; cnt++) 
   {        
   OrderSelect(cnt, SELECT_BY_POS);            
   if(OrderSymbol() == Symbol() && OrderType()<=OP_SELL) 
      numords++;
      if (OrderType()==OP_SELL) direction = -1;
      if (OrderType()==OP_BUY) direction = 1;
      profit+=OrderProfit();
   }
   
   return(numords);
}

         	                    
//+------------------------------------------------------------------+
//| expert deinitialization function                                 |
//+------------------------------------------------------------------+
int deinit()
  {
//---- 
   
//----
   return(0);
  }
//+------------------------------------------------------------------+
//| expert start function                                            |
//+------------------------------------------------------------------+
int start()
{
   if (pointsPerPip==0) {
      pointsPerPip = pointsPerPip();
      pip = Point*pointsPerPip;
      basePrice = Bid-pip*500;
      for (int i=0;i<1000;i++) {
         pipTouches[i]=0;
         pipTimeStamp[i]=-1;
      }
   }
   digit  = MarketInfo(Symbol(),MODE_DIGITS);
   Comment("Digit: "+digit+" Point: "+Point+ " PointsPerPip:"+pointsPerPip+"/n"+
   "Andrea Maldini - Range Trader - Trend Line Trader with breakeven protection - for 1 minute charts trading \nSupported trend line descriptions: bb,ss,stop"+
   "\nCurrent Pivot:"+currentPivot+" pivotON:"+pivotON);
   
   /*RefreshRates();
   int MinStopDist = MarketInfo(Symbol(),MODE_STOPLEVEL);
   Comment("MinStopDist: "+MinStopDist);
   */
   
   currentTimeStamp++;
   tickTime[currentTimeStamp] = TimeLocal();
   
   if (checkSpread()) return;
   
   if (ScanTrades()>0 && BreakEven>0) TrailStops(); 
   
   // double sl = NormalizeDouble(Ask + pip * autoSLPips,digit);
   // Comment("SL example for sell: "+sl);
   
   checkLines();
   
   onTick((Ask+Bid)/2);
   
   checkPivot();
   
   if (currentTimeStamp % 100==0) {
	garbageCollect();
   }

 return(0);
}//int start
//+------------------------------------------------------------------+

private void garbageCollect() {
	// cancella la history troppo vecchia
	// ricentra se necessario
	// manda indietro il currenttick...
}

bool shortTriggered = false;
bool longTriggered = false;

int lastPriceIndex=0;
int breakOutDirection=0;
void onTick(double price) {
   int priceIndex = (price-basePrice)/pip;
   if (priceIndex!=lastPriceIndex) {
   
      if ((currentTimeStamp-pipTimeStamp[priceIndex])>1000) {
         pipTouches[priceIndex]=0;
      }
   
      pipTouches[priceIndex]++;
   }
   pipTimeStamp[priceIndex]=currentTimeStamp;
   lastPriceIndex = priceIndex;
   
   if (pipTouches[priceIndex]<=1 && !pivotON) {
      setPivot(price);
      pivotON=true;
      if (priceIndex>lastPriceIndex) {
         breakOutDirection = 1;
      } else {
         breakOutDirection = -1;
      }
   } else {
      
      bool cond1 = (shortTriggered && longTriggered);
      bool cond2 = (MathAbs(price-currentPivot)>pipsFromPivot*pip*2);
      bool cond3 = pipTouches[priceIndex]>3;
      
      if (cond1 || cond2 || cond3) {
         shortTriggered = false;
         longTriggered = false;
         pivotON = false;
         updatePivotLines();
      }
   }
   
   Comment("PriceIndex:"+priceIndex+" pipTouches:"+pipTouches[priceIndex]);
}

int lastDirection = 0;
void checkPivot() {
   
   if (!pivotON) return (0);

   if (pipsFromPivot<1) {
      Print("pipsFromPivot<1!!! INVALID!!!");
      return (0);
   }

   double price=(Ask+Bid)/2;

   if (direction==0) {
     
      // TODO: determinare se livello tradabile
     
      if ((MathAbs(price-currentPivot)/pip)>pipsFromPivot) {

            if (price<currentPivot) {
               go(-1);
               shortTriggered = true;
               // setPivot(price+pipsFromPivot*pip);
            }
            if (price>currentPivot) {
               go(1);
               longTriggered = true;
               // setPivot( price-pipsFromPivot*pip);
            }

      }
      
   } 
   
   lastDirection = direction;

   updatePivotLines();
}

double getPivotLine(){
   double price = ObjectGet("madoxPivot", OBJPROP_PRICE1);
   return(price);
}

void setPivot(double price) {
   currentPivot = price;
   last_t = TimeLocal();
   updatePivotLines();
}

void updatePivotLines() {
   if (pivotON) {
      horizLine("madoxPivot", currentPivot, Red, "current pivot");
      horizLine("madoxPivotUp", currentPivot + pipsFromPivot*pip, Green);
      horizLine("madoxPivotDown", currentPivot - pipsFromPivot*pip, Green);
   } else {
      ObjectDelete("madoxPivot");
      ObjectDelete("madoxPivotUp");
      ObjectDelete("madoxPivotDown");
   }
}

bool checkSpread() {
   double spread = MarketInfo(Symbol6(),MODE_SPREAD)/pointsPerPip;
   
   string text = "Spread: "+DoubleToStr(spread,1);
   label("lblSpread", 50, 20, 2, text, Gray); 
   ObjectSet("lblSpread", OBJPROP_FONTSIZE, 20);
   bool spreadTooBig = false;
   
   if (spread>MAX_SPREAD_PIPS) {
      // closeOpenOrders(OP_SELLSTOP,magic);
      // closeOpenOrders(OP_BUYSTOP,magic);
      spreadTooBig = true;
      ObjectSet("lblSpread",OBJPROP_COLOR,Red);
   }
   
   return (spreadTooBig);
}

void checkLines(){

   if (crossedLine("stop")){
      maON = false;
      closeOpenOrders(OP_BUY,magic);
      closeOpenOrders(OP_SELL,magic);
   }
   if (crossedLine("ss") && (direction!=-1)){
      go(-1);
   }
   if (crossedLine("bb") && (direction!=1)){
      go(1);
   }   
   if (crossedLine("MA")){
      maON = true;
   }

   checkLines2();
   
}

void checkLines2() {

   if (!autoActivateTrendLines) return(0);
   
   int i;
   double price;
   string name;
   string command_line;
   string command_argument;
   int type;

   for (i = 0; i < ObjectsTotal(); i++) {
      name = ObjectName(i);

      // is this an object without description (newly created by the user)?
      if (ObjectDescription(name) == "" && ObjectType(name)==OBJ_TREND ) {
         
         double price1 = ObjectGet(name, OBJPROP_PRICE1);
         double price2 = ObjectGet(name, OBJPROP_PRICE2);
         
         datetime t2 = ObjectGet(name,OBJPROP_TIME2);
         
         if (t2>TimeCurrent()) { 
            if (pivotON) {
               ObjectSetText(name,"stop");
            } else if (price1>price2) {
               ObjectSetText(name, "bb");
            } else if (price1<price2) {
               ObjectSetText(name, "ss");
            }
         
         }
         
      }

   }
}

void go(int dir) {
   double sl,tp;
   
   double TP = autoTPPips;
   if (dir==breakOutDirection) {
      TP = TP*3;
   } 
   
   if (dir>0) {
      closeOpenOrders(OP_SELL,magic);
      sl = NormalizeDouble(Bid - pip * autoSLPips,digit);
      tp = NormalizeDouble(Bid + pip * TP,digit); 
      buy(lots, sl, tp, magic, "");        
   }
   if (dir<0) {
      closeOpenOrders(OP_BUY,magic);
      sl = NormalizeDouble(Ask + pip * autoSLPips,digit);
      tp = NormalizeDouble(Ask - pip * TP,digit); 
      sell(lots, sl, tp, magic, "");
   }
}






