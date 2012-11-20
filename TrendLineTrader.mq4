//+-------------------------------------------------------------------+
//|                                           TrendLineTrader.mq4     |
//|                                  Copyright © 2012, Andrea Maldini |
//|                                                                   |                                      
//+-------------------------------------------------------------------+
#property copyright "Copyright © 2012, Andrea Maldini"
// #property link      ""

#include <common_functions.mqh>

//---- input parameters

extern double     BreakEven       = 6;    // Profit Lock in pips  
extern double     LockGainPips        = 0.1; 
extern double     autoSLPips = 6;

extern double     BreakEven2    = 12;
extern double     LockGainPips2 = 6;

extern bool       autoActivateTrendLines = false;

double            currentPivot = 0;

extern double     pipsFromPivot = 6;

extern double     MAX_SPREAD_PIPS = 2.5;

int      digit=0;
int      pointsPerPip=0;
double   pip=0;
int magic = 0;

int direction = 0;

bool maON = false;
extern bool pivotON = false;
double profit = 0;

extern double riskmultiplier = 1; // per testare sabato e domenica

extern double lots = 0.1;

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
               Comment("Digit: "+digit+" Point: "+Point+ " PointsPerPip:"+pointsPerPip+"\n"+
               "OrderOpenPrice:"+OrderOpenPrice()+"\n"+
               "Stop loss will be at: "+(OrderOpenPrice()+pip*LockGainPips)+
               "BreakEven trigger will be at: "+(OrderOpenPrice()+pip*BreakEven));
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
               Comment("Digit: "+digit+" Point: "+Point+ " PointsPerPip:"+pointsPerPip+"\n"+
               "OrderOpenPrice:"+OrderOpenPrice()+"\n"+
               "Stop loss will be at: "+(OrderOpenPrice()-pip*LockGainPips)+
               "BreakEven trigger will be at: "+(OrderOpenPrice()-pip*BreakEven));
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
   
   if (currentPivot==0) setPivot((Ask+Bid)/2);
   
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
      pip = Point*pointsPerPip*riskmultiplier;
   }
   digit  = MarketInfo(Symbol(),MODE_DIGITS);
   Comment("Digit: "+digit+" Point: "+Point+ " PointsPerPip:"+pointsPerPip+"/n"+
   "Andrea Maldini - Trend Line Trader with breakeven protection - for 1 minute charts trading \nSupported trend line descriptions: bb,ss,stop"+
   "\nCurrent Pivot:"+currentPivot+" pivotON:"+pivotON);
   
   /*RefreshRates();
   int MinStopDist = MarketInfo(Symbol(),MODE_STOPLEVEL);
   Comment("MinStopDist: "+MinStopDist);
   */
   
   if (checkSpread()) return;
   
   if (ScanTrades()>0 && BreakEven>0) TrailStops(); 
   
   // double sl = NormalizeDouble(Ask + pip * autoSLPips,digit);
   // Comment("SL example for sell: "+sl);
   
   checkLines();
   
   checkMA();
   
   checkPivot();
   
 return(0);
}//int start
//+------------------------------------------------------------------+
int lastDirection = 0;
void checkPivot() {
   
   if (!pivotON) return (0);

   if (pipsFromPivot<2) {
      Print("pipsFromPivot<2!!! INVALID!!!");
      return (0);
   }

   if (direction==0) {
      
      // currentPivot = (Ask+Bid)/2;
      double price=(Ask+Bid)/2;
      if (lastDirection!=0 || (currentPivot==0) ) {
         setPivot(price);
         lastDirection = 0;
      }
      if ((MathAbs(price-currentPivot)/pip)>pipsFromPivot) {
         if (price<currentPivot) {
            go(-1);
            setPivot(price+pipsFromPivot*pip);
         }
         if (price>currentPivot) {
            go(1);
            setPivot( price-pipsFromPivot*pip);
         }
      }
   } else {
      lastDirection = direction;
   }
}

void setPivot(double price) {
   currentPivot = price;
   horizLine("madoxPivot", price, Red, "current pivot");
   horizLine("madoxPivotUp", price + pipsFromPivot*pip, Green);
   horizLine("madoxPivotDown", price - pipsFromPivot*pip, Green);
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
         
            if (price1>price2) {
               ObjectSetText(name, "bb");
            }
            if (price1<price2) {
               ObjectSetText(name, "ss");
            }
         
         }
         
      }

   }
}

void go(int dir) {
   double sl;
   if (dir>0) {
      closeOpenOrders(OP_SELL,magic);
      sl = NormalizeDouble(Bid - pip * autoSLPips,digit);
      buy(lots, sl, 0, magic, "");        
   }
   if (dir<0) {
      closeOpenOrders(OP_BUY,magic);
      sl = NormalizeDouble(Ask + pip * autoSLPips,digit);
      sell(lots, sl, 0, magic, "");
   }
}

void checkMA() {

   if (!maON) return(0);
   
   double ma=iMA(NULL,0,14,0,MODE_EMA,PRICE_MEDIAN,1);
   double ma1=iMA(NULL,0,14,0,MODE_EMA,PRICE_MEDIAN,2);
   double ma2=iMA(NULL,0,14,0,MODE_EMA,PRICE_MEDIAN,3);
   
   int dir = 0;
   
   if (ma>ma1 && ma1>ma2) dir =  1;
   if (ma<ma1 && ma1<ma2) dir = -1;
   
   if (direction!=0) {
      if (dir!=0) { 
         if (direction!=dir) {
            if (profit<0) return; // se attuale trade in perdita, aspetto SL
            // if (profit>0) {
            // go(dir);
            // }
            closeOpenOrders(OP_SELL,magic);
            closeOpenOrders(OP_BUY,magic);
         }
      }
   } // else if (dir!=0) go(dir);
   
}



