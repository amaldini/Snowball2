//+------------------------------------------------------------------+
//|                                             MT4Communication.mqh |
//|                      Copyright © 2012, Andrea Maldini            |
//|                                                                  |
//+------------------------------------------------------------------+
#import "MT4Library.dll"

bool ClearSymbolStatus(string symbolName);   
string PostSymbolStatus(string symbolName,double lots,int isLong, int isShort,double pyramidBase, double renkoPyramidPips);
bool GetSymbolStatus(string symbolName,int& longOrShort[],double& lotsPyramidBaseAndPips[]); 

string getGridMode(string symbolName,int isMaster); 
bool   setGridMode(string symbolName,int isMaster,string gridMode);

bool   getGridOptions(string symbolName,int isMaster,int& distant[]); 
int    getMultiplierForMicroLot(string symbolName);

bool   setProfits(string symbolName,int isMaster,double profits);

bool setBalance_NAV_UsedMargin(int isMaster,double balance, double NAV,double usedMargin);   

bool setExposure(string symbolName,int isMaster,double exposureLots);
double getExposure(string symbolName,int isMaster);  

#include <common_functions.mqh>

double pip;
double points_per_pip;
string comment;
int magic;
string stringToAppendToInfo;

extern bool GRID_TRADING = true;
extern double GRID_TRADING_STEP = 10; // pips
extern int GRID_TRADING_PENDINGORDERS = 2;
extern double GRID_TAKEPROFIT = 200; // pips
extern double GRID_STOP_PIPS = 200; // pips

extern double maxExposureLots = 0.08;

/**
* move all entry orders by the amount of d
*/
void moveOrders_GRID(double d){
   int i;
   for(i=0; i<OrdersTotal(); i++){
      OrderSelect(i, SELECT_BY_POS, MODE_TRADES);
      int otype = OrderType();
      if ((otype!=OP_SELL) && (otype!=OP_BUY)) { 
         if (isMyOrder(magic)){
            if (MathAbs(OrderOpenPrice() - ((Bid+Ask)/2)) > (1+GRID_TRADING_PENDINGORDERS) * GRID_TRADING_STEP * pip){
               orderDeleteReliable(OrderTicket());
            }else{
               maldaLog("GRID: moving order "+OrderTicket()+" by "+DoubleToStr(d,Digits));
               orderModifyReliable(
                  OrderTicket(),
                  NormalizeDouble(OrderOpenPrice() + d,Digits),
                  NormalizeDouble(OrderStopLoss() + d,Digits), //OK
                  NormalizeDouble(OrderTakeProfit() + d, Digits),
                  0,
                  CLR_NONE
               );
            }
         }
      }
   }
}

double calcAdjustedLotSize(double exposureDelta) {
   double numLots=0.01;
   
   maldaLog("exposureDelta="+DoubleToStr(exposureDelta,4));
   
   exposureDelta = 0; // disabilito hedging perche voglio provare 
                      //a sfruttare lo sbilanciamento a mio favore
   
   if (exposureDelta>0.0001) {
      numLots = exposureDelta;
   } else {
      int multiplier = getMultiplierForMicroLot(Symbol6());
      if (multiplier>=1 && multiplier<=5) {
         numLots = 0.01*multiplier;
      }
   }
   return (numLots);
}

double lastExposure=0;

void tradeGrid(int isMaster) {
   GR_TrailStops();
   
   int tickets[],orderTypes[];
   double openPrices[];
   double orderLots[];
   double orderProfits[];
   int numOrders = getOpenOrderPrices(magic,tickets,openPrices,orderTypes,orderLots,orderProfits);
   
   int i;
   int danglers=0;
   double min=1000000;
   double max=0;
   double exposure = 0;
   
   double profit = 0;
   
   for (i=0;i<numOrders;i++) {
      if ((orderTypes[i]==OP_SELL && openPrices[i]<Ask) ||
          (orderTypes[i]==OP_BUY  && openPrices[i]>Bid)) { 
         danglers++;
         exposure+=orderLots[i];
      }
      
      if (orderTypes[i]==OP_SELL || orderTypes[i]==OP_BUY) {
         profit += orderProfits[i];
      }
      
      if (openPrices[i]>max) max=openPrices[i];
      if (openPrices[i]<min) min=openPrices[i];
   }
   if (lastExposure!=exposure) {
      setExposure(Symbol6(),isMaster,exposure);
      lastExposure=exposure;
   }
   
   setProfits(Symbol6(),isMaster,profit);
   
   maldaLog("exposure="+DoubleToStr(exposure,4));
   double exposureDelta = getExposure(Symbol6(),1-isMaster)-exposure;
   
   double adjustedLotSize = calcAdjustedLotSize(exposureDelta);
   
   int distant[2];
   distant[0]=0;
   if (getGridOptions(Symbol6(),isMaster,distant)) {
      if (distant[0]!=0 && numOrders>0 && danglers==0) {
          double delta;
          if (isMaster==0 && (max<Bid-GRID_TRADING_STEP*pip)) {
            delta = (Bid-GRID_TRADING_STEP*pip)-max;
            moveOrders_GRID(delta); 
            for (i=0;i<numOrders;i++) openPrices[i]+=delta;
          }
          if (isMaster==1 && (min>Ask+GRID_TRADING_STEP*pip)) {
            delta = -(min-(Ask+GRID_TRADING_STEP*pip));
            moveOrders_GRID(delta);   
            for (i=0;i<numOrders;i++) openPrices[i]+=delta;
          }   
      }
   }  
   
   double gridStart;
   if (numOrders == 0) {
      gridStart = NormalizeDouble((Ask+Bid)/2,Digits);
   } else {
      gridStart = openPrices[0];
   } 
   
   int addedOrders = 0;
   int nLevels=0;
   
   if (exposure>=maxExposureLots) {
      adjustedLotSize = 0;
      maldaLog("exposure>maxExposureLots!");
   }
   
   for (i = -20;i<20 && nLevels<GRID_TRADING_PENDINGORDERS;i++) {
      double price;
      bool condition1;
      bool condition2;
      
      if (isMaster==0) {
         price = NormalizeDouble(gridStart-GRID_TRADING_STEP*i*pip,Digits);
         condition1 = (price<Bid && distant[0]==0); 
         condition2 = (price<(Bid-GRID_TRADING_STEP*pip) && distant[0]!=0);
      } else {
         price = NormalizeDouble(gridStart+GRID_TRADING_STEP*i*pip,Digits);
         condition1 = (price>Ask && distant[0]==0); 
         condition2 = (price>(Ask+GRID_TRADING_STEP*pip) && distant[0]!=0);
      }
      
      if (condition1 || condition2) {
         // verifico di non avere già un ordine a questo livello
         double currentLots = 0;
         for (int j=0;j<numOrders;j++) {
            if (MathAbs(openPrices[j]-price)<GRID_TRADING_STEP*pip*4/5) {
               if ((currentLots+orderLots[j])>adjustedLotSize && (orderTypes[j]==OP_BUYSTOP || orderTypes[j]==OP_SELLSTOP)) {
                  orderDeleteReliable(tickets[j]);
                  orderLots[j]=0;
               } else {
                  currentLots+=orderLots[j]; 
               }
            }
         }
         if (currentLots<adjustedLotSize) {
            if (isMaster==0) {
               gridSell(price,adjustedLotSize-currentLots);
               maldaLog("pending sell at:"+DoubleToStr(price,Digits));  
            } else {
               gridBuy(price,adjustedLotSize-currentLots);
               maldaLog("pending buy at:"+DoubleToStr(price,Digits));   
            }         
         }
         nLevels++; // o c'era già o l'ho creato
      }
   }
   
   
   maldaLog("tradeGrid("+ danglers +") danglers");
}

void tradeGrid_Slave() {
   tradeGrid(0);
}

void tradeGrid_Master() {
   tradeGrid(1);
}

void GR_TrailStops() {
   /*
   double GRID_BreakEven = GRID_TRADING_STEP*3;
   double GRID_LockGainPips = GRID_TRADING_STEP;
   double GRID_BreakEven2 = GRID_TRADING_STEP * 6;
   double GRID_LockGainPips2 = GRID_TRADING_STEP * 3;
   GRID_TrailStops(pip,GRID_BreakEven, GRID_LockGainPips,GRID_BreakEven2,GRID_LockGainPips2);
   */
}

// ---- Trailing Stops
void GRID_TrailStops(double pip,double BreakEven, double LockGainPips,double BreakEven2,double LockGainPips2)
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
               double BuyStop = OrderStopLoss();
               if ( Bid-OrderOpenPrice()>pip*BreakEven ) 
               {
                  BuyStop = OrderOpenPrice()+pip*LockGainPips;
               }
               if ( BreakEven2>BreakEven && LockGainPips2>LockGainPips && ((Bid-OrderOpenPrice())>pip*BreakEven2)) {
                  BuyStop = OrderOpenPrice()+pip*LockGainPips2;
               }
               
               if (OrderStopLoss()<BuyStop) {
                  OrderModify(OrderTicket(),OrderOpenPrice(),
                              NormalizeDouble(BuyStop, Digits),
                              OrderTakeProfit(),0,LightGreen);
               }
			      
			   }
            if ( mode==OP_SELL )
            {
               double SellStop = OrderStopLoss();
               if ( OrderOpenPrice()-Ask>pip*BreakEven ) 
               {
                  SellStop = OrderOpenPrice()-pip*LockGainPips;
               }
               if ( BreakEven2>BreakEven && LockGainPips2>LockGainPips && ((OrderOpenPrice()-Ask)>pip*BreakEven2)) {
                  SellStop = OrderOpenPrice()-pip*LockGainPips2;
               }
               if (OrderStopLoss()>SellStop) {
                  OrderModify(OrderTicket(),OrderOpenPrice(),
   		                  NormalizeDouble(SellStop, Digits),
   		                  OrderTakeProfit(),0,Yellow);	 
   		      }   
                 
            }
         }   
      } 
}


void gridBuy(double price,double numLots) {
   double sl=0,tp=0;
   sl = NormalizeDouble(price - pip * GRID_STOP_PIPS,Digits);
   tp = price + pip * GRID_TAKEPROFIT;  
   buyStop(numLots, price, sl, tp, magic, comment, "gridBuy");
}

void gridSell(double price,double numLots) {
   double sl=0,tp=0;
   sl = NormalizeDouble(price + pip * GRID_STOP_PIPS,Digits);
   tp = price - pip * GRID_TAKEPROFIT;
   sellStop(numLots, price, sl, tp, magic, comment, "gridSell");
}

int getOpenOrderPrices(int magic, int &tickets[], double& prices[],int &orderTypes[],double& orderLots[],double& orderProfits[]) {
   
   // int numOpenOrders = getNumOpenOrders(-1,magic);
   // if (numOpenOrders<=0) return(0);
     
   // int tickets[];
   // double prices[];
   
   int total = OrdersTotal();

   if (total<=0) return(0);

   ArrayResize(tickets, total);
   ArrayResize(prices, total);
   ArrayResize(orderTypes,total);
   ArrayResize(orderLots,total);
   ArrayResize(orderProfits,total);
   
   // collect order tickets and prices
   int idx=0;
   for (int cnt = 0; cnt < total; cnt++) {
      OrderSelect(cnt, SELECT_BY_POS, MODE_TRADES);
      if (isMyOrder(magic)) {
         orderTypes[idx] = OrderType();
         tickets[idx] = OrderTicket();
         prices[idx] = OrderOpenPrice();
         orderLots[idx] = OrderLots();
         if (orderTypes[idx]==OP_BUY || orderTypes[idx]==OP_SELL) orderProfits[idx]=OrderProfit();
         idx++;
      }
   }
   
   return (idx);
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


