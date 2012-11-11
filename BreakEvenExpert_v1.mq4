//+------------------------------------------------------------------+
//|                                           BreakEvenExpert_v1.mq4 |
//|                                  Copyright © 2006, Forex-TSD.com |
//|                         Written by IgorAD,igorad2003@yahoo.co.uk |   
//|            http://finance.groups.yahoo.com/group/TrendLaboratory |                                      
//+------------------------------------------------------------------+
#property copyright "Copyright © 2012, Andrea Maldini"
// #property link      ""

#include <common_functions.mqh>

//---- input parameters

extern double     BreakEven       = 6;    // Profit Lock in pips  
extern double     LockGainPips        = 0.1; 
extern double     autoSLPips = 6;

extern double     BreakEven2    = 12;
extern double     LockGainPips2 = 6;

int      digit=0;
int      pointsPerPip=0;
double   pip=0;
int magic = 0;

extern double riskmultiplier = 1; // per testare sabato e domenica

extern double lots = 2;

//+------------------------------------------------------------------+
//| expert initialization function                                   |
//+------------------------------------------------------------------+
int init()
  {

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
      
   for(int cnt=0; cnt<total; cnt++) 
   {        
   OrderSelect(cnt, SELECT_BY_POS);            
   if(OrderSymbol() == Symbol() && OrderType()<=OP_SELL) 
   numords++;
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
   
   if (ScanTrades()>0 && BreakEven>0) TrailStops(); 
   
   checkLines();
   
 return(0);
}//int start
//+------------------------------------------------------------------+

void checkLines(){

   double sl;

   if (crossedLine("stop")){
      closeOpenOrders(OP_BUY,magic);
      closeOpenOrders(OP_SELL,magic);
   }
   if (crossedLine("sell")){
      closeOpenOrders(OP_BUY,magic);
      sl = Ask + pip * autoSLPips;
      sell(lots, sl, 0, magic, "");
   }
   if (crossedLine("buy")){
      closeOpenOrders(OP_SELL,magic);
      sl = Bid - pip * autoSLPips;
      buy(lots, sl, 0, magic, "");
   }   
   
}



