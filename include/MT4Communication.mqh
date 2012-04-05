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

bool setBalance_NAV_UsedMargin(int isMaster,double balance, double NAV,double usedMargin);   

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



