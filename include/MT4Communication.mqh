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

bool setBalance_NAV_UsedMargin(int isMaster,double balance, double NAV,double usedMargin);   


#include <common_functions.mqh>

double pip;
double points_per_pip;
string comment;
int magic;
string stringToAppendToInfo;

extern bool GRID_TRADING = true;
extern double GRID_TRADING_STEP = 10; // pips
extern int GRID_TRADING_PENDINGORDERS = 2;
extern double GRID_TAKEPROFIT = 60; // pips
extern double GRID_STOP_PIPS = 30; // pips

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
            if (MathAbs(OrderOpenPrice() - getLine()) > (1+GRID_TRADING_PENDINGORDERS) * GRID_TRADING_STEP * pip){
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

void tradeGrid_Slave() {
   
   double GRID_BreakEven = GRID_TRADING_STEP;
   double GRID_LockGainPips = 2;
   double GRID_BreakEven2 = GRID_TRADING_STEP /2 * 3;
   double GRID_LockGainPips2 = GRID_TRADING_STEP;
   GRID_TrailStops(pip,GRID_BreakEven, GRID_LockGainPips,GRID_BreakEven2,GRID_LockGainPips2);
   
   int tickets[],orderTypes[];
   double openPrices[];
   int numOrders = getOpenOrderPrices(magic,tickets,openPrices,orderTypes);
   
   int i;
   int danglers=0;
   double max=0;
   for (i=0;i<numOrders;i++) {
      if (orderTypes[i]==OP_SELL && openPrices[i]<Ask) danglers++;
      if (openPrices[i]>max) max=openPrices[i];
   }
   int distant[2];
   distant[0]=0;
   if (getGridOptions(Symbol6(),0,distant)) {
      if (distant[0]!=0 && numOrders>0 && danglers==0 && (max<Bid-GRID_TRADING_STEP*pip)) {
          double delta = (Bid-GRID_TRADING_STEP*pip)-max;
          moveOrders_GRID(delta); 
          for (i=0;i<numOrders;i++) openPrices[i]+=delta;
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
   if (danglers<1) {
      for (i = -20;i<20 && nLevels<GRID_TRADING_PENDINGORDERS;i++) {
         double price = NormalizeDouble(gridStart-GRID_TRADING_STEP*i*pip,Digits);
         
         bool condition1 = (price<Bid && distant[0]==0); 
         bool condition2 = (price<(Bid-GRID_TRADING_STEP*pip/2) && distant[0]!=0);
         
         if (condition1 || condition2) {
            // verifico di non avere giï¿½ un ordine a questo livello
            bool found = false;
            for (int j=0;j<numOrders;j++) {
               if (MathAbs(openPrices[j]-price)<GRID_TRADING_STEP*pip*4/5) {
                  found=true;
                  nLevels++;
               }
            }
            if (!found) {
               nLevels++;
               gridSell(price);
               maldaLog("pending sell at:"+DoubleToStr(price,Digits));           
            }
         }
      }
   }
   
   maldaLog("tradeGrid_Slave("+ danglers +") danglers");
}

void tradeGrid_Master() {

   double GRID_BreakEven = GRID_TRADING_STEP;
   double GRID_LockGainPips = 2;
   double GRID_BreakEven2 = GRID_TRADING_STEP /2 * 3;
   double GRID_LockGainPips2 = GRID_TRADING_STEP;
   GRID_TrailStops(pip,GRID_BreakEven, GRID_LockGainPips,GRID_BreakEven2,GRID_LockGainPips2);

   int tickets[],orderTypes[];
   double openPrices[];
   int numOrders = getOpenOrderPrices(magic,tickets,openPrices,orderTypes); 
   
   int i;
   int danglers=0;
   double min=10000000;
   for (i=0;i<numOrders;i++) {
      if (orderTypes[i]==OP_BUY && openPrices[i]>Bid) danglers++;
      if (openPrices[i]<min) min=openPrices[i];
   }
   
   int distant[2];
   distant[0]=0;
   if (getGridOptions(Symbol6(),1,distant)) {
      if (distant[0]!=0 && numOrders>0 && danglers==0 && (min>Ask+GRID_TRADING_STEP*pip)) {
         double delta = -(min-(Ask+GRID_TRADING_STEP*pip));
         moveOrders_GRID(delta);   
         for (i=0;i<numOrders;i++) openPrices[i]+=delta;
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
   if (danglers<1) {
      for (i = -20;i<20 && nLevels<GRID_TRADING_PENDINGORDERS;i++) {
         double price = NormalizeDouble(gridStart+GRID_TRADING_STEP*i*pip,Digits);
         
         bool condition1 = (price>Ask && distant[0]==0); 
         bool condition2 = (price>(Ask+GRID_TRADING_STEP*pip/2) && distant[0]!=0);
         
         if (condition1 || condition2) {
            // verifico di non avere giï¿½ un ordine a questo livello
            bool found = false;
            for (int j=0;j<numOrders;j++) {
               if (MathAbs(openPrices[j]-price)<GRID_TRADING_STEP*pip*4/5) {
                  found=true;
                  nLevels++;
               }
            }
            if (!found) {
               nLevels++;
               gridBuy(price);
               maldaLog("pending buy at:"+DoubleToStr(price,Digits));           
            }
         }
      }
   }

   maldaLog("tradeGrid_Master (" + danglers +") danglers");
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


void gridBuy(double price) {
   double sl=0,tp=0;
   sl = NormalizeDouble(price - pip * GRID_STOP_PIPS,Digits);
   tp = price + pip * GRID_TAKEPROFIT;
   int multiplier = getMultiplierForMicroLot(Symbol6());
   if (multiplier>=1 && multiplier<=5) {
      double numLots = 0.01*multiplier;
      buyStop(numLots, price, sl, tp, magic, comment, "gridBuy");
   } else {
      maldaLog("MULTIPLIER OUT OF RANGE!!!");
   }
}

void gridSell(double price) {
   double sl=0,tp=0;
   sl = NormalizeDouble(price + pip * GRID_STOP_PIPS,Digits);
   tp = price - pip * GRID_TAKEPROFIT;
   
   int multiplier = getMultiplierForMicroLot(Symbol6());
   if (multiplier>=1 && multiplier<=5) {
      double numLots = 0.01*multiplier;
      sellStop(numLots, price, sl, tp, magic, comment, "gridSell");
   } else {
      maldaLog("MULTIPLIER OUT OF RANGE!!!");
   }
}

int getOpenOrderPrices(int magic, int &tickets[], double& prices[],int &orderTypes[]) {
   
   // int numOpenOrders = getNumOpenOrders(-1,magic);
   // if (numOpenOrders<=0) return(0);
     
   // int tickets[];
   // double prices[];
   
   int total = OrdersTotal();

   if (total<=0) return(0);

   ArrayResize(tickets, total);
   ArrayResize(prices, total);
   ArrayResize(orderTypes,total);
   
   // collect order tickets and prices
   int idx=0;
   for (int cnt = 0; cnt < total; cnt++) {
      OrderSelect(cnt, SELECT_BY_POS, MODE_TRADES);
      if (isMyOrder(magic)) {
         orderTypes[idx] = OrderType();
         tickets[idx] = OrderTicket();
         prices[idx] = OrderOpenPrice();
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

double getLine(){
   return(ObjectGet("last_order", OBJPROP_PRICE1));
}