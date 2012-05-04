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

bool   getAntiGridOptions(string symbolName,int isMaster,int& distant[]); 
int    getMultiplierForMicroLot(string symbolName);

bool getGridOptions(string symbolName,int& enable[],double& bottomAndTop[]);  

bool   setProfits(string symbolName,int isMaster,double profits);

bool setBalance_NAV_UsedMargin(int isMaster,double balance, double NAV,double usedMargin);   

bool setExposure(string symbolName,int isMaster,int isGrid,double exposureLots);
double getExposure(string symbolName,int isMaster,int isGrid);  

bool setCloseOpenTrades(string symbolName,int isMaster,int isClose);
bool getCloseOpenTrades(string symbolName,int isMaster);  

#include <common_functions.mqh>

double pip;
double points_per_pip;
string comment;
int magic;
string stringToAppendToInfo;


bool distant=true;
bool allowReenter=false;

extern bool GRID_TRADING = true;


double GRID_STEP;
int GRID_PENDINGORDERS;
double GRID_TP;
double GRID_STOP;

double GRID_CENTER;
double GRID_HEIGHT_PIPS;
bool GRID_ENABLE=false;

bool isGrid;

extern double GRID_TRADING_STEP = 10; // pips
extern int GRID_TRADING_PENDINGORDERS = 3;
extern double GRID_TAKEPROFIT = 200; // pips
extern double GRID_STOP_PIPS = 200; // pips

extern double maxExposureLots = 0.08;

extern double ANTIGRID_TRADING_STEP = 10; // pips
extern double ANTIGRID_TRADING_PENDINGORDERS = 3;
extern double ANTIGRID_TAKEPROFIT = 200; // pips
extern double ANTIGRID_STOP_PIPS = 200; // pips

double prevGridStep = 0;

void tradeGridAndAntiGrid(int isMaster) {
   readDistantAndAllowReenter(isMaster);
   
   GRID_STEP = ANTIGRID_TRADING_STEP;
   GRID_PENDINGORDERS = ANTIGRID_TRADING_PENDINGORDERS;
   GRID_TP = ANTIGRID_TAKEPROFIT;
   GRID_STOP = ANTIGRID_STOP_PIPS;
   
   isGrid = false; // ANTIGRID
   tradeGrid(isMaster);
   
   distant = false;
   allowReenter = false; 
   
   readGridOptions(isMaster);
   
   isGrid = true; // GRID
   
   if (GRID_ENABLE) {
   
      double exposureDelta = getExposure(Symbol6(),isMaster,1)-getExposure(Symbol6(),1-isMaster,1);
   
      GRID_STEP = 8; // 8 pips   
      GRID_STEP = GRID_STEP*(1+MathMax(0,exposureDelta/0.01));
   
      if (MathAbs(GRID_STEP-prevGridStep)>0.0001) {
         maldaLog("deleting grid pending orders because grid step changed");
         deleteGridPendingOrders();
      };
   
      prevGridStep = GRID_STEP;
      
      maldaLog("GRID_STEP="+GRID_STEP);
      
      GRID_PENDINGORDERS = GRID_TRADING_PENDINGORDERS;
      GRID_TP = GRID_STEP-2;
      if (GRID_TP<6) GRID_TP=6;
      GRID_STOP = GRID_STOP_PIPS;
      
      tradeGrid(isMaster);
   } else {
      deleteGridPendingOrders();
   }
   
   setProfits(Symbol6(),isMaster,getCurrentProfit());
}

bool isAntiGridTrade() {
   if (MathAbs(OrderOpenPrice()-OrderTakeProfit())>pip*120) {
      return(true);
   } else { 
      return(false);
   }
}

bool isMyOrderGrid(int magic) {
   if (!isMyOrder(magic)) return (false);
   
   if ((!isGrid) && isAntiGridTrade()) return (true);
   if (isGrid && (!isAntiGridTrade())) return (true);
   
   return (false);
}

/**
* move all entry orders by the amount of d
*/
void moveOrders_GRID(double d){
   int i;
   
   double maxOffset = (1+GRID_PENDINGORDERS) * GRID_STEP * pip;
   
   if (distant) maxOffset += GRID_STEP*pip*GRID_PENDINGORDERS;
   
   for(i=0; i<OrdersTotal(); i++){
      OrderSelect(i, SELECT_BY_POS, MODE_TRADES);
      int otype = OrderType();
      if ((otype!=OP_SELL) && (otype!=OP_BUY)) { 
         if (isMyOrderGrid(magic)){
            if (MathAbs(OrderOpenPrice() - ((Bid+Ask)/2)) > maxOffset){
               maldaLog("Deleting too distant order");
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
   double orderTP[];
   int numOrders = getOpenOrderPrices(magic,tickets,openPrices,orderTypes,orderLots,orderProfits,orderTP);
   
   int i;
   int danglers=0;
   double min=1000000;
   double max=0;
   double exposure = 0;
   
   double profit = 0;
   double gridStart = -1;
   
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
      
      if (gridStart<0 || (MathAbs(openPrices[i]-Bid)<MathAbs(Bid-gridStart))) gridStart = openPrices[i];
      
   }
   if (lastExposure!=exposure) {
      if (isGrid) {
         setExposure(Symbol6(),isMaster,1,exposure);
      } else {
         setExposure(Symbol6(),isMaster,0,exposure);
      }
      lastExposure=exposure;
   }
   
   maldaLog("exposure="+DoubleToStr(exposure,4));
   double exposureDelta;
   if (isGrid) {
      exposureDelta = getExposure(Symbol6(),1-isMaster,1)-exposure;
   } else {
      exposureDelta = getExposure(Symbol6(),1-isMaster,0)-exposure;
   }
   double adjustedLotSize = calcAdjustedLotSize(exposureDelta);
   
   
   if (distant && (numOrders>0) && (exposure<0.0001)) {
       double delta;
       if (isMaster==0 && (max<Bid-GRID_STEP*pip*GRID_PENDINGORDERS)) {
         delta = (Bid-GRID_STEP*pip*GRID_PENDINGORDERS)-max;
         moveOrders_GRID(delta); 
         for (i=0;i<numOrders;i++) openPrices[i]+=delta;
       }
       if (isMaster==1 && (min>Ask+GRID_STEP*pip*GRID_PENDINGORDERS)) {
         delta = -(min-(Ask+GRID_STEP*pip*GRID_PENDINGORDERS));
         moveOrders_GRID(delta);   
         for (i=0;i<numOrders;i++) openPrices[i]+=delta;
       }   
   }

   
   if (numOrders == 0) {
      gridStart = NormalizeDouble((Ask+Bid)/2,Digits);
   } 
   
   if (isGrid) gridStart = GRID_CENTER;
   
   int addedOrders = 0;
   int nLevels=0;
   
   if (exposure>=maxExposureLots) {
      adjustedLotSize = 0;
      maldaLog("exposure>maxExposureLots!");
   }
   
   for (i = -20;i<20 && nLevels<GRID_PENDINGORDERS;i++) {
      double price;
      bool condition1;
      bool condition2;
      
      if (isMaster==0) { // SHORT
         price = NormalizeDouble(gridStart-GRID_STEP*i*pip,Digits);
         condition1 = (price<Bid && !distant); 
         condition2 = (price<(Bid-GRID_STEP*pip*GRID_PENDINGORDERS) && distant);
      } else {           // LONG
         price = NormalizeDouble(gridStart+GRID_STEP*i*pip,Digits);
         condition1 = (price>Ask && !distant); 
         condition2 = (price>(Ask+GRID_STEP*pip*GRID_PENDINGORDERS) && distant);
      }
      if (isGrid) {
         condition1 = condition1 && (MathAbs(price-GRID_CENTER)<=(pip*(GRID_HEIGHT_PIPS+GRID_STEP)/2));
      }
      
      if (condition1 || condition2) {
         // verifico di non avere già un ordine a questo livello
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
               maldaLog("pending sell at:"+DoubleToStr(price,Digits));  
            } else {
               gridBuy(price,lotsForOrder);
               maldaLog("pending buy at:"+DoubleToStr(price,Digits));   
            }         
         }
         nLevels++; // o c'era già o l'ho creato
      }
   }
   
   if (getCloseOpenTrades(Symbol6(),isMaster)) {
      closeOpenOrders(OP_BUY,magic,"command issued by controlpanel");
      closeOpenOrders(OP_SELL,magic,"command issued by controlpanel");
      setCloseOpenTrades(Symbol6(),isMaster,0);
   }
   
   maldaLog("tradeGrid("+ danglers +") danglers");
}


void readDistantAndAllowReenter(int isMaster) {
   int i[2];
   i[0]=0;
   allowReenter = false;
   distant = true;
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
}

void GR_TrailStops() {
   /*
   double GRID_BreakEven = GRID_STEP*3;
   double GRID_LockGainPips = GRID_STEP;
   double GRID_BreakEven2 = GRID_STEP * 6;
   double GRID_LockGainPips2 = GRID_STEP * 3;
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


