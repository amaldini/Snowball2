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

extern double     MAX_SPREAD_PIPS = 2.5;

int      digit=0;
int      pointsPerPip=0;
double   pip=0;
int magic = 0;

int direction = 0;

bool maON = false;
double profit = 0;

extern double riskmultiplier = 1; // per testare sabato e domenica

extern double lots = 2;

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
   Comment("Digit: "+digit+" Point: "+Point+ " PointsPerPip:"+pointsPerPip);
   Comment("Andrea Maldini - Trend Line Trader with breakeven protection - for 1 minute charts trading \nSupported trend line descriptions: buy,sell,stop");
   
   /*RefreshRates();
   int MinStopDist = MarketInfo(Symbol(),MODE_STOPLEVEL);
   Comment("MinStopDist: "+MinStopDist);
   */
   
   if (ScanTrades()>0 && BreakEven>0) TrailStops(); 
   
   // double sl = NormalizeDouble(Ask + pip * autoSLPips,digit);
   // Comment("SL example for sell: "+sl);
   
   checkLines();
   
   checkMA();
   
 return(0);
}//int start
//+------------------------------------------------------------------+

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

   double sl;

   if (checkSpread()) return;

   if (crossedLine("stop")){
      maON = false;
      closeOpenOrders(OP_BUY,magic);
      closeOpenOrders(OP_SELL,magic);
   }
   if (crossedLine("sell")){
      closeOpenOrders(OP_BUY,magic);
      sl = NormalizeDouble(Ask + pip * autoSLPips,digit);
      sell(lots, sl, 0, magic, "");
   }
   if (crossedLine("buy")){
      closeOpenOrders(OP_SELL,magic);
      sl = NormalizeDouble(Bid - pip * autoSLPips,digit);
      buy(lots, sl, 0, magic, "");
   }   
   if (crossedLine("MA")){
      Comment("MA not yet implemented!");
      maON = true;
   }
   
}

void checkMA() {

  if (!maON) return(0);
   
   double ma=iMA(NULL,0,14,0,MODE_EMA,PRICE_MEDIAN,0);
   double ma1=iMA(NULL,0,14,0,MODE_EMA,PRICE_MEDIAN,1);
   double ma2=iMA(NULL,0,14,0,MODE_EMA,PRICE_MEDIAN,2);
   
   int dir = 0;
   
   if (ma>ma1 && ma1>ma2) dir =  1;
   if (ma<ma1 && ma1<ma2) dir = -1;
   
   // se attuale trade in perdita, aspetto SL
   if (direction!=0) {
      if (direction!=0 && dir!=0 && direction!=dir) {
            if (profit<0) return;
      }
   }
   
   
   // se non c'e' attuale trade , apro posizione
   // se attuale trade in profitto, con direzione opposta,chiudo
}



