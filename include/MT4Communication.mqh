//+------------------------------------------------------------------+
//|                                             MT4Communication.mqh |
//|                      Copyright ï¿½ 2012, Andrea Maldini            |
//|                                                                  |
//+------------------------------------------------------------------+
#import "MT4Library.dll"

bool ClearSymbolStatus(string symbolName);   
string PostSymbolStatus(string symbolName,double lots,int isLong, int isShort,double pyramidBase, double renkoPyramidPips);
bool GetSymbolStatus(string symbolName,int& longOrShort[],double& lotsPyramidBaseAndPips[]); 

string getGridMode(string symbolName,int isMaster); 
bool   setGridMode(string symbolName,int isMaster,string gridMode);

bool   getAntiGridOptions(string symbolName,int isMaster,int& distant[]); 
int    getMultiplierForMicroLot(string symbolName);

bool getGridOptions(string symbolName,int& enable[],double& bottomAndTop[]); 
bool getBurstGridOptions(string symbolName,int& enable[]); 

bool   setProfits(string symbolName,int isMaster,double profits);

bool setBalance_NAV_UsedMargin(int isMaster,double balance, double NAV,double usedMargin);   

bool setExposure(string symbolName,int isMaster,int isGrid,double exposureLots);
double getExposure(string symbolName,int isMaster,int isGrid);  

bool setCloseOpenTrades(string symbolName,int isMaster,int isClose);
bool getCloseOpenTrades(string symbolName,int isMaster);  

bool setCmd(string symbolName,int isMaster,string cmd);
string getCmd(string symbolName,int isMaster);  

#include <common_functions.mqh>

double pip;
double points_per_pip;
string comment;
int magic;
string stringToAppendToInfo;

bool allowReenter=false;

extern bool GRID_TRADING = true;


double GRID_STEP;
int GRID_PENDINGORDERS;
double GRID_TP;
double GRID_STOP;

double GRID_CENTER;
double GRID_HEIGHT_PIPS;
bool GRID_ENABLE=false;
bool BURST_GRID_ENABLE=false;

bool isGrid;
bool isBurstGrid;

double GRID_TRADING_STEP = 10; // pips
int GRID_TRADING_PENDINGORDERS = 3;
double GRID_TAKEPROFIT = 8; // pips
double GRID_STOP_PIPS = 200; // pips

extern double maxExposureLots = 0.16;

double ANTIGRID_TRADING_STEP = 10; // pips
double ANTIGRID_TRADING_PENDINGORDERS = 3;
double ANTIGRID_TAKEPROFIT = 200; // pips
double ANTIGRID_STOP_PIPS = 200; // pips

double BURSTGRID_TRADING_STEP = 1; // pips
double BURSTGRID_TRADING_PENDINGORDERS = 5;
double BURSTGRID_TAKEPROFIT = 20; // pips 
double BURSTGRID_STOP_PIPS = 20; // pips

double prevGridStep_Grid = 0;
double prevGridStep_AntiGrid = 0;


#include <calcOrderDistance.mqh>

double adjustGridStepByExposure(int isMaster,double baseGridStep) {
   int isGridInt = 0;
   double pgs;
   if (isGrid) {
      isGridInt = 1;
      pgs = prevGridStep_Grid;
   } else {
      pgs = prevGridStep_AntiGrid;
   }
   // double myExposure = getExposure(Symbol6(),isMaster,isGridInt);
   
   
   double GRID_STEP = baseGridStep;
   /*
   if (myExposure / 0.01 <= 1.001) {
      GRID_STEP = baseGridStep;
   } else {
      double exposureDelta = myExposure -getExposure(Symbol6(),1-isMaster,isGridInt);
      GRID_STEP = baseGridStep*(1+MathMax(0,exposureDelta/0.01));
   }
   */
   
   /*
   if (MathAbs(GRID_STEP-pgs)>0.0001) {
      maldaLog("deleting grid pending orders because grid step changed");
      deleteGridPendingOrders();
   }
   */
   
   if (isGrid) {
      prevGridStep_Grid = GRID_STEP;
   } else {
      prevGridStep_AntiGrid = GRID_STEP;
   }
   
   return (GRID_STEP);
}

void tradeGridAndAntiGrid(int isMaster) {
   readDistantAndAllowReenter(isMaster);
   
   isGrid = false; // ANTIGRID
   isBurstGrid = false;
   
   GRID_STEP = adjustGridStepByExposure(isMaster,ANTIGRID_TRADING_STEP);
   GRID_PENDINGORDERS = ANTIGRID_TRADING_PENDINGORDERS;
   GRID_TP = ANTIGRID_TAKEPROFIT;
   GRID_STOP = ANTIGRID_STOP_PIPS;
   maldaLog("ANTIGRID_STEP="+GRID_STEP);
   
   tradeGrid(isMaster);
   
   allowReenter = false; 
   
   readGridOptions(isMaster);
   
   isGrid = true; // GRID
   
   if (GRID_ENABLE) {
      
      GRID_STEP = adjustGridStepByExposure(isMaster,GRID_TRADING_STEP);
      
      maldaLog("GRID_STEP="+GRID_STEP);
      
      GRID_PENDINGORDERS = GRID_TRADING_PENDINGORDERS;
      // GRID_TP = GRID_STEP-2;
      GRID_TP = GRID_TAKEPROFIT;
      if (GRID_TP<6) GRID_TP=6;
      GRID_STOP = GRID_STOP_PIPS;
      
      tradeGrid(isMaster);
   } else {
      deleteGridPendingOrders();
   }
   
   isGrid=false;
   isBurstGrid=true;
   
   if (BURST_GRID_ENABLE) {
      GRID_STEP = adjustGridStepByExposure(isMaster,BURSTGRID_TRADING_STEP);
      GRID_PENDINGORDERS = BURSTGRID_TRADING_PENDINGORDERS;
      GRID_TP = BURSTGRID_TAKEPROFIT;
      if (GRID_TP<6) GRID_TP = 6; 
      GRID_STOP = BURSTGRID_STOP_PIPS;
      
      tradeGrid(isMaster);
   } else {
      deleteGridPendingOrders();
   }
   
   isBurstGrid=false;
   
   setProfits(Symbol6(),isMaster,getCurrentProfit());
   
   
   if (getCmd(Symbol6(),isMaster)=="rebalance") {
      setCmd(Symbol6(),isMaster,"");
      doRebalance(isMaster);
   }
}

void doRebalance(int isMaster) {
   
}

bool isAntiGridTrade() {
   if (MathAbs(OrderOpenPrice()-OrderTakeProfit())>pip*170) {
      return(true);
   } else { 
      return(false);
   }
}

bool isBurstGridTrade() {
   double delta = MathAbs(OrderOpenPrice()-OrderTakeProfit())/pip;
   if (MathAbs(delta-BURSTGRID_TAKEPROFIT)<5) {
      return(true);
   } else { 
      return(false);
   }
}

bool isMyOrderGrid(int magic) {
   if (!isMyOrder(magic)) return (false);
   
   if (isBurstGrid){
      if (isBurstGridTrade()) return (true);
      return (false);
   }
   
   if (!isBurstGridTrade()) {
      if ((!isGrid) && isAntiGridTrade()) return (true);
      if (isGrid && (!isAntiGridTrade())) return (true);
   }
   
   return (false);
}

double getLotSize() {
   double numLots=0.01;
 
   int multiplier = getMultiplierForMicroLot(Symbol6());
   if (multiplier>=1 && multiplier<=5) {
      numLots = 0.01*multiplier;
   }
   
   return (numLots);
}

double lastExposureGrid=-1; // perché se metto 0 non si aggiorna in caso sia realmente 0
double lastExposureAntiGrid=-1;

void tradeGrid(int isMaster) {
   GR_TrailStops();
   
   int tickets[],orderTypes[];
   double openPrices[];
   double orderLots[];
   double orderProfits[];
   double orderTP[];
   int numOrders = getOpenOrderPrices(magic,tickets,openPrices,orderTypes,orderLots,orderProfits,orderTP);
   
   int i;
   int danglers=0;
   double min=1000000;
   double max=0;
   double exposure = 0;
   
   double profit = 0;
   double gridStart = -1;
   
   int openTrades = 0;
   
   for (i=0;i<numOrders;i++) {
      if ((orderTypes[i]==OP_SELL && openPrices[i]<Ask) ||
          (orderTypes[i]==OP_BUY  && openPrices[i]>Bid)) { 
         danglers++;
         exposure+=orderLots[i]; // considero exposure solo se sono in perdita, importante per bilanciamento di adjustGridStepByExposure
      }
      
      if (orderTypes[i]==OP_SELL || orderTypes[i]==OP_BUY) {
         profit += orderProfits[i];
         openTrades++;
      }
      
      if (openPrices[i]>max) max=openPrices[i];
      if (openPrices[i]<min) min=openPrices[i];
      
      if (gridStart<0 || (MathAbs(openPrices[i]-Bid)<MathAbs(Bid-gridStart))) gridStart = openPrices[i];
      
   }
   
   if (isGrid) {
      maldaLog("GRID ORDERS: "+numOrders);
   } else {
      maldaLog("ANTIGRID ORDERS: "+numOrders);
   }
   
   if (isGrid && (lastExposureGrid!=exposure)) {
      setExposure(Symbol6(),isMaster,1,exposure);
      lastExposureGrid = exposure;
   }
   if ((!isGrid) && (lastExposureAntiGrid!=exposure)) {
      setExposure(Symbol6(),isMaster,0,exposure);
      lastExposureAntiGrid = exposure;
   }
     
   maldaLog("exposure="+DoubleToStr(exposure,4));
   
   if (numOrders == 0) {
      gridStart = NormalizeDouble((Ask+Bid)/2,Digits);
   } 
   
   if (isGrid) gridStart = GRID_CENTER;
   
   int addedOrders = 0;
   int nLevels=0;
   
   double adjustedLotSize = getLotSize();
   
   /*
   if (exposure>=maxExposureLots) {
      adjustedLotSize = 0;
      maldaLog("exposure>maxExposureLots!");
   }
   */
   
   double orderDistance = calcOrderDistance(danglers, openTrades);
   
   for (i = -20;
      (i<20) && 
      (nLevels<GRID_PENDINGORDERS) && 
      (GRID_STEP>=1); 
      i++) {
      
      double price;
      bool condition1;
      
      if (isMaster==0) { // SHORT
         price = NormalizeDouble(gridStart-GRID_STEP*i*pip,Digits);
         condition1 = (price<(Bid-orderDistance)); 
      } else {           // LONG
         price = NormalizeDouble(gridStart+GRID_STEP*i*pip,Digits);
         condition1 = (price>(Ask+orderDistance)); 
      }
      if (isGrid) {
         condition1 = condition1 && (MathAbs(price-GRID_CENTER)<=(pip*(GRID_HEIGHT_PIPS+GRID_STEP)/2));
         if (isMaster==0) condition1=condition1 && (price>=GRID_CENTER);
         if (isMaster!=0) condition1=condition1 && (price<=GRID_CENTER);
      } else {
         if (GRID_ENABLE) {
            condition1 = condition1 && (MathAbs(price-GRID_CENTER)>(pip*GRID_HEIGHT_PIPS/2)); 
         }
      }
      
      if (condition1) {
         // verifico di non avere giï¿½ un ordine a questo livello
         double currentLots = 0;
         double pendingLots = 0;
         for (int j=0;j<numOrders;j++) {
            if (MathAbs(openPrices[j]-price)<GRID_STEP*pip*4/5) {
               bool isPendingOrder = (orderTypes[j]==OP_BUYSTOP || orderTypes[j]==OP_SELLSTOP);
               if ((currentLots+orderLots[j])>adjustedLotSize && isPendingOrder && (!allowReenter)) {
                  orderDeleteReliable(tickets[j]);
                  orderLots[j]=0;
               } else {
                  currentLots+=orderLots[j];
                  if (isPendingOrder) {
                     pendingLots+=orderLots[j];
                  }
               }
            }
         }
         double lotsForOrder = adjustedLotSize-currentLots;
         if (allowReenter && (pendingLots<0.0001)) lotsForOrder = 0.01;
         if (lotsForOrder>0.0001) {
            if (isMaster==0) {
               gridSell(price,lotsForOrder);
               if (isGrid!=0) {
                  maldaLog("GRID pending sell at:"+DoubleToStr(price,Digits));  
               } else {
                  maldaLog("ANTIGRID pending sell at:"+DoubleToStr(price,Digits));    
               }
            } else {
               gridBuy(price,lotsForOrder);
               if (isGrid!=0) {
                  maldaLog("GRID pending buy at:"+DoubleToStr(price,Digits)); 
               } else {
                  maldaLog("ANTIGRID pending buy at:"+DoubleToStr(price,Digits));
               }  
            }         
         }
         nLevels++; // o c'era giï¿½ o l'ho creato
      }
   }
   
   ExitConditions(isMaster);
   
   maldaLog("tradeGrid("+ danglers +") danglers");
}


void readDistantAndAllowReenter(int isMaster) {
   int i[2];
   i[0]=0;
   allowReenter = false;
   bool distant = true; // UNUSED
   if (getAntiGridOptions(Symbol6(),isMaster,i)) {
      if (i[0]==0) distant = false;
      if (i[1]!=0) allowReenter = true;
   }
}

void readGridOptions(int isMaster) {
   int enable[2];
   double bottomAndTop[3];
   if (getGridOptions(Symbol6(),enable,bottomAndTop)) {
      GRID_ENABLE = (enable[0]!=0);
      GRID_CENTER = (bottomAndTop[0]+bottomAndTop[1])/2;
      GRID_HEIGHT_PIPS = MathAbs(bottomAndTop[0]-bottomAndTop[1])/pip;
      
      place_SL_Line(bottomAndTop[1],"GridTop","Grid TOP");
      place_SL_Line(bottomAndTop[0],"GridBottom","Grid BOTTOM");
   } 
   if (getBurstGridOptions(Symbol6(),enable))  {
      BURST_GRID_ENABLE = (enable[0]!=0);
   }
   maldaLog("BurstGridEnable:"+BURST_GRID_ENABLE);
      
   
}

void GR_TrailStops() {
   if (isBurstGrid) {
      double GRID_BreakEven = GRID_STEP*3;
      double GRID_LockGainPips = GRID_STEP;
      double GRID_BreakEven2 = GRID_STEP * 6;
      double GRID_LockGainPips2 = GRID_STEP * 3;
      GRID_TrailStops(pip,GRID_BreakEven, GRID_LockGainPips,GRID_BreakEven2,GRID_LockGainPips2);   
   }
   /*
   double GRID_BreakEven = GRID_STEP*3;
   double GRID_LockGainPips = GRID_STEP;
   double GRID_BreakEven2 = GRID_STEP * 6;
   double GRID_LockGainPips2 = GRID_STEP * 3;
   GRID_TrailStops(pip,GRID_BreakEven, GRID_LockGainPips,GRID_BreakEven2,GRID_LockGainPips2);
   */
   
   
   // GRID_TrailStopsATRdiv2();
}

void GRID_TrailStopsATRdiv2() {
   if ((ATRdiv2/pip)<10) return;
   
   int total=OrdersTotal();
   for (int cnt=0;cnt<total;cnt++)
    { 
     OrderSelect(cnt, SELECT_BY_POS);   
     int mode=OrderType();    
        if ( OrderSymbol()==Symbol() ) 
        {
            if ( mode==OP_BUY )
            {  
               double BuyStop = Bid - ATRdiv2;
               
               if (OrderStopLoss()<BuyStop) {
                  OrderModify(OrderTicket(),OrderOpenPrice(),
                              NormalizeDouble(BuyStop, Digits),
                              OrderTakeProfit(),0,LightGreen);
               }
			      
			   }
            if ( mode==OP_SELL )
            {
               double SellStop = Ask + ATRdiv2;
               
               if (OrderStopLoss()>SellStop || (OrderStopLoss()<pip)) {
                  OrderModify(OrderTicket(),OrderOpenPrice(),
   		                  NormalizeDouble(SellStop, Digits),
   		                  OrderTakeProfit(),0,Yellow);	 
   		      }   
                 
            }
         }   
      } 
}

// ---- Trailing Stops
void GRID_TrailStops(double pip,double BreakEven, double LockGainPips,double BreakEven2,double LockGainPips2)
{        
    int total=OrdersTotal();
    for (int cnt=0;cnt<total;cnt++)
    { 
        OrderSelect(cnt, SELECT_BY_POS);   
        int mode=OrderType();    
        if (isMyOrderGrid(magic)) {
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
}


void gridBuy(double price,double numLots) {
   double sl=0,tp=0;
   sl = NormalizeDouble(price - pip * GRID_STOP,Digits);
   tp = price + pip * GRID_TP;  
   buyStop(numLots, price, sl, tp, magic, comment, "gridBuy");
}

void gridSell(double price,double numLots) {
   double sl=0,tp=0;
   sl = NormalizeDouble(price + pip * GRID_STOP,Digits);
   tp = price - pip * GRID_TP;
   sellStop(numLots, price, sl, tp, magic, comment, "gridSell");
}

int getOpenOrderPrices(int magic, int &tickets[], double& prices[],int &orderTypes[],double& orderLots[],double& orderProfits[],double& orderTP[]) {
   
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
   ArrayResize(orderTP,total);
   
   // collect order tickets and prices
   int idx=0;
   for (int cnt = 0; cnt < total; cnt++) {
      OrderSelect(cnt, SELECT_BY_POS, MODE_TRADES);
      if (isMyOrderGrid(magic)) {
         orderTypes[idx] = OrderType();
         tickets[idx] = OrderTicket();
         prices[idx] = OrderOpenPrice();
         orderLots[idx] = OrderLots();
         orderTP[idx] = OrderTakeProfit();
         if (orderTypes[idx]==OP_BUY || orderTypes[idx]==OP_SELL) orderProfits[idx]=OrderProfit();
         idx++;
      }
   }
   
   return (idx);
}

double getCurrentProfit() {
   double profit=0;
   int total = OrdersTotal();
   for (int i=0;i<total;i++) {
      OrderSelect(i,SELECT_BY_POS,MODE_TRADES);
      if (isMyOrder(magic)) {
         if (OrderType()==OP_BUY || OrderType()==OP_SELL) {
            profit+=OrderProfit();
         }
      }
   }
   return (profit);
} 

void deleteGridPendingOrders() {
   int total = OrdersTotal();
   for (int i=0;i<total;i++) {
      OrderSelect(i,SELECT_BY_POS,MODE_TRADES);
      if (isMyOrderGrid(magic)) {
         if (OrderType()==OP_BUYSTOP || OrderType()==OP_SELLSTOP) {
            orderDeleteReliable(OrderTicket());
         }
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


