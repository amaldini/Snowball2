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
extern double fixedRiskInEuro       = 1         ;
extern double rewardToRisk        = 20          ;

extern string ________TAKE_PROFIT               ;
extern int    default_tp_level      = 120       ;
extern color  tp_color              = DarkGray  ;
extern int    tp_style              = STYLE_DASH;

extern bool avoidRanges = true;

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

double getTippingPoint_SELL(double price) {
   int potentialTippingPoint = 0;
   double tippingPoint = 0;
   for (int i=2;i<Bars;i++) {
      if (High[i]>High[i-1]) potentialTippingPoint = i;
      if (High[i]>High[i+1] && potentialTippingPoint>0) {
         tippingPoint = High[potentialTippingPoint];
         break;
      } 
   }
   if (tippingPoint<price) tippingPoint = price;
   return (tippingPoint);
} 

double getTippingPoint_BUY(double price) {
   int potentialTippingPoint = 0;
   double tippingPoint = 0;
   for (int i=2;i<Bars;i++) {
      if (Low[i]<Low[i-1]) potentialTippingPoint = i;
      if (Low[i]<Low[i+1] && potentialTippingPoint>0) {
         tippingPoint = Low[potentialTippingPoint];
         break;
      } 
   }
   if (tippingPoint>price) tippingPoint = price;
   return (tippingPoint);
} 

int getPriceTouches(double price) {
   int touches = 0;
   for (int i=1;i<60;i++) {
      if (High[i]>=price && Low[i]<=price) {
         touches++;
      }
   }
   return (touches);
}

bool isBullishHammer() {
   double HighCloseDelta = High[1]-Close[1]; // always >=0
   double HighOpenDelta = High[1]-Open[1];   // always >=0
   double HighLowDelta = High[1]-Low[1];     // always >=0
   
   bool cond1 = true;
   if (HighCloseDelta>0) {
      cond1 = ((HighLowDelta / HighCloseDelta) >=3);
   } 
   bool cond2 = true;
   if (HighOpenDelta>0) {
      cond2 = ((HighLowDelta / HighOpenDelta) >=3);
   }
   
   return (cond1 && cond2);
}

bool isBearishHammer() {
   double LowCloseDelta = Close[1]-Low[1];   // always >=0
   double LowOpenDelta = Open[1]-Low[1];     // always >=0
   double HighLowDelta = High[1]-Low[1];     // always >=0
   
   bool cond1 = true;
   if (LowCloseDelta>0) {
      cond1 = ((HighLowDelta / LowCloseDelta) >=3);
   } 
   bool cond2 = true;
   if (LowOpenDelta>0) {
      cond2 = ((HighLowDelta / LowOpenDelta) >=3);
   }
   
   return (cond1 && cond2);
}

int lastPriceTouches = 0;
int lastStopTouches = 0;
string lastPASignal = "";

void start()
{
   RefreshRates();
   
   if (dgts==0) {
      
      dgts    = MarketInfo(Symbol(),MODE_DIGITS);
      
      calculatePointsPerPip();
   }
   
   double stopPrice=0;
   double stopPips=0;
   
   string cmts = "";
   int numTrades = ScanTrades();
   bool onlyTippingPoint = true;
   
   if ((!onlyTippingPoint) && numTrades==0) { // we are flat
   
      bool previousBarIsDoji = ((High[1]-Low[1])/pip) < 2;

      bool BearEngulfing =  (Close[0]  <=  (Low[1]-pip))  && (High[0]>= High[1]); 
      bool BullEngulfing  = (Close[0]  >=  (High[1]+pip)) && (Low[0] <= Low[1] );
      
      bool previousIsInsideBar = (High[1]<=High[2]) && (Low[1]>=Low[2]);
      
      if (previousBarIsDoji) {
         cmts = "Doji breakout";
      } else if (previousIsInsideBar) {
         cmts = "Inside bar breakout";
      } else if (BearEngulfing) {
         cmts = "Bearish engulfing";
      } else if (BullEngulfing) {
         cmts = "Bullish engulfing";
      }
   
      if (previousBarIsDoji || BearEngulfing || BullEngulfing || previousIsInsideBar) {
         if (Close[0]>(High[1]+pip)) { // BULLISH
      
            // double low = MathMin(Low[1],Low[0]);
            double low = Low[1];
      
            stopPips = (Bid-low) / pip + 1;
      
            // if (stopPips < 5) stopPips = 5;   
      
            stopPrice = Bid - stopPips * pip;   
            
         } else if (Close[0]<(Low[1]-pip)) {  // BEARISH
      
            // double high = MathMax(High[1],High[0]);
            double high = High[1];
      
            stopPips = (high-Ask) / pip + 1;
         
            // if (stopPips <5) stopPips = 5;     
         
            stopPrice = Ask + stopPips * pip;    
             
         }
      } else {
         
         if (isBullishHammer()) {
            stopPips = (Bid-Low[1]) / pip + 1;
            if (stopPips<0) {
               stopPips = 0;
            } else {
               stopPrice = Bid - stopPips * pip;
               cmts = "Bullish hammer";
            }  
         } else if (isBearishHammer()) {
            stopPips = (High[1]-Ask) / pip + 1;
            if (stopPips<0) {
               stopPips = 0;
            } else {
               stopPrice = Ask + stopPips * pip;
               cmts = "Bearish hammer";
            }
         }
      } 
     
      if (stopPips>0 && stopPrice>0) {
      
         cmts = StringConcatenate(cmts," ("+DoubleToStr(stopPips,2)+" pips stop)"); 
      
         lastPASignal = cmts;
      
         lastPriceTouches = getPriceTouches(Close[0]);
         lastStopTouches = getPriceTouches(stopPrice);
      
         bool touchesOk;
         if (avoidRanges) {
            touchesOk = !IsInCluster();
         } else {
            touchesOk = true;
         }
         if (touchesOk) {
            Comment("Going with stop price:"+DoubleToStr(stopPrice,Digits));
            goWithStopPrice(stopPrice, cmts);
         } else {
            lastPASignal = StringConcatenate(lastPASignal," (skipped)");
         }
      }
   }
   
   Comment("Symbol:"+Symbol()+"\n"+
           "Profit: "+DoubleToStr(profit,2)+"\n"+
           "Last price touches: "+lastPriceTouches+"\n"+
           "Last stop touches: "+lastStopTouches+"\n"+
           "IsInCluster:" + IsInCluster()+"\n"+
           "Last PA signal:" + lastPASignal+"\n"+
           "High[1]:"+DoubleToStr(High[1],Digits)+"\n"+
           "Low[1]:"+DoubleToStr(Low[1],Digits)+"\n"+
           "Close[0]:"+DoubleToStr(Close[0],Digits)+"\n"+
           "pip:"+DoubleToStr(pip,Digits));
   
   
   WindowRedraw(); 
}

bool IsInCluster() {
   bool res = !(
         (lastPriceTouches<3) || 
         (lastStopTouches<3)
      );
   return (res);
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
      
      EnforceTippingPointOnThisTrade();
      
   }
   
   return(numords);
}

// ---- Trailing Stops
void EnforceTippingPointOnThisTrade()
{        
   int mode=OrderType();    
   if ( mode==OP_BUY )
   {  
      double BuyStop = getTippingPoint_BUY(Bid);

      if (OrderStopLoss()<BuyStop || OrderStopLoss()==0) {
         OrderModify(OrderTicket(),OrderOpenPrice(),
                     NormalizeDouble(BuyStop, Digits),
                     OrderTakeProfit(),0,LightGreen);
      }

   }
   if ( mode==OP_SELL )
   {
      double SellStop = getTippingPoint_SELL(Ask);
      
      if (OrderStopLoss()>SellStop || OrderStopLoss()==0) {
         OrderModify(OrderTicket(),OrderOpenPrice(),
                  NormalizeDouble(SellStop, Digits),
                  OrderTakeProfit(),0,Yellow);	 
      }   

   }
     
}


void goWithStopPrice(double marketOrderStop,string cmts) {
      double riskEuro = fixedRiskInEuro / (multiOrder+1);
      double step = MathAbs(marketOrderStop - (Bid+Ask)/2);
      if (marketOrderStop<Bid) { // buy
         for (int k=0;k<=multiOrder;k++) {
            double calculatedLotsB = calculateLotSize(Bid,marketOrderStop,riskEuro);
            double calculatedTPB = calcTP(Ask,marketOrderStop,dgts); 
            buy(calculatedLotsB, marketOrderStop, calculatedTPB, 0, cmts);
            marketOrderStop-=step;
         }        
      } else if (marketOrderStop>Ask) { // sell
         for (int w=0;w<=multiOrder;w++) {
            double calculatedLotsS = calculateLotSize(Ask,marketOrderStop,riskEuro);
            double calculatedTPS = calcTP(Bid,marketOrderStop,dgts); 
            sell(calculatedLotsS, marketOrderStop, calculatedTPS, 0, cmts);
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