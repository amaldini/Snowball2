//+------------------------------------------------------------------+
//|                                               CandleBreakout.mq4 |
//|                                               Andrea Maldini     |
//|                                                                  |
//+------------------------------------------------------------------+
//|                                                                  |
//|                                                                  |
//|                                                                  |
//|                                                                  |
//+------------------------------------------------------------------+

#property copyright "Andrea Maldini"
// #property link      ""

#include <stderror.mqh>
#include <stdlib.mqh>
#include <lotSizeCalculator.mqh>

extern bool   delete_on_deinit      = true      ;

extern string _________FIXED_RISK_EURO          ;
extern double fixedRiskInEuro       = 3         ;
extern double rewardToRisk        = 20          ;

extern string ________TAKE_PROFIT               ;
extern int    default_tp_level      = 120       ;
extern color  tp_color              = DarkGray  ;
extern int    tp_style              = STYLE_DASH;

extern int multiOrder  = 0; 

int dgts=0;

int direction=0;
double profit=0;


void init()
{

   IS_ECN_BROKER = true;
   
}

void deinit()
{
   if(delete_on_deinit)
   {
      for(int x=0; x<10; x++) for(int i=0; i<ObjectsTotal(); i++)
      {
         string name=ObjectName(i);
         
         if(StringSubstr(name,0,4)=="lvoe")
            ObjectDelete(name);
      }
   }
}

int waitCounter = 0;

double calcTP(double openPrice,double stopLossPrice,int dgts) {
   return (NormalizeDouble(openPrice+(openPrice-stopLossPrice)*rewardToRisk,dgts));
}

void start()
{
   RefreshRates();
   
   if (dgts==0) {
      
      dgts    = MarketInfo(Symbol(),MODE_DIGITS);
      
      calculatePointsPerPip();
   }
   
   double stopPrice=0;
   double stopPips=0;
   
   if (ScanTrades()==0) { // we are flat
   
      bool previousBarIsDoji = ((High[1]-Low[1])/pip) < 2;

      bool BearEngulfing =  (Close[0]  <=  (Low[1]-pip))  && (High[0]>= High[1]); 
      bool BullEngulfing  = (Close[0]  >=  (High[1]+pip)) && (Low[0] <= Low[1] );
      
      bool previousIsInsideBar = (High[1]<=High[2]) && (Low[1]>=Low[2]);
   
      if (previousBarIsDoji || BearEngulfing || BullEngulfing || previousIsInsideBar) {
         if (Close[0]>(High[1]+pip)) {
      
            // double low = MathMin(Low[1],Low[0]);
            double low = Low[1];
      
            stopPips = (Close[0]-low) / pip + pip;
      
            // if (stopPips < 5) stopPips = 5;   
      
            stopPrice = Bid - stopPips * pip;   
         } else if (Close[0]<(Low[1]-pip)) {
      
            // double high = MathMax(High[1],High[0]);
            double high = High[1];
      
            stopPips = (high-Close[0]) / pip + pip;
         
            // if (stopPips <5) stopPips = 5;     
         
            stopPrice = Ask + stopPips * pip;      
         }
      }
      
      if (stopPips>0 && stopPrice>0) {
         goWithStopPrice(stopPrice);
      }
   }
   
   WindowRedraw(); 
}

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
   
   Comment("Profit: "+profit);
   
   return(numords);
}


void goWithStopPrice(double marketOrderStop) {
      double riskEuro = fixedRiskInEuro / (multiOrder+1);
      double step = MathAbs(marketOrderStop - (Bid+Ask)/2);
      if (marketOrderStop<Bid) { // buy
         for (int k=0;k<=multiOrder;k++) {
            double calculatedLotsB = calculateLotSize(Bid,marketOrderStop,riskEuro);
            double calculatedTPB = calcTP(Ask,marketOrderStop,dgts); 
            buy(calculatedLotsB, marketOrderStop, calculatedTPB, 0, "");
            marketOrderStop-=step;
         }        
      } else if (marketOrderStop>Ask) { // sell
         for (int w=0;w<=multiOrder;w++) {
            double calculatedLotsS = calculateLotSize(Ask,marketOrderStop,riskEuro);
            double calculatedTPS = calcTP(Bid,marketOrderStop,dgts); 
            sell(calculatedLotsS, marketOrderStop, calculatedTPS, 0, "");
            marketOrderStop+=step;
         }
      }    
}

void clean(string name)
{
   if(-1 != ObjectFind(name))  ObjectDelete(name);
}

void errorPrint(string type, int err)
{  
   Print(type," ERROR(",err,") = ",ErrorDescription(err));
}