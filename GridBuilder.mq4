//+------------------------------------------------------------------+
//|                                 Copyright © 2013, Andrea Maldini |
//|                                                                  |
//+------------------------------------------------------------------+
#property copyright "© Andrea Maldini 2013"
#property link      ""

#include <lotSizeCalculator.mqh>

extern bool is_ecn_broker = false; // different market order procedure when resuming after pause

extern int step = 10;
extern int SL = 10;
extern int TP = 20;
extern int numOrders = 20;
extern double lots = 0.01;


void defaults(){

   IS_ECN_BROKER = true; // different market order procedure when resuming after pause
}


int init(){
   if (!IsDllsAllowed()){
      MessageBox("DLL imports must be allowed!", "Snowball");
      return(-1);
   }
      
   IS_ECN_BROKER = is_ecn_broker;
   
   defaults();

   calculatePointsPerPip();
   
}

int deinit(){
   deleteButtons();
   
   if (UninitializeReason() == REASON_PARAMETERS){
      Comment("Parameters changed, pending orders deleted, will be replaced with the next tick");
      closeOpenOrders(OP_SELLSTOP, -1);
      closeOpenOrders(OP_BUYSTOP, -1);
   }else{
      Comment("EA removed, open orders, trades and status untouched!");
   }
}

void onTick(){
   checkButtons();
}




void onOpen(){
}



void deleteButtons(){
   ObjectDelete("build_grid");
   ObjectDelete("close");
}

void closeTrades() {
   closeOpenOrders(OP_BUY,-1);
   closeOpenOrders(OP_SELL,-1);
}

void checkButtons(){
   
   if (labelButton("build_grid", 15, 15, 1, "build grid", Lime)){
      buildGrid();
   }

   if (labelButton("close", 15, 45, 1, "close", White)) {
      closeTrades();
   }
   
}

void buildGrid() {
   closeOpenOrders(-1,-1);
   
   double base = (Bid+Ask)/2;
   
   for (int i=0;i<numOrders;i++) {
      
      double buyPrice = NormalizeDouble(base+pip*step*i,Digits);
      double SLPrice = NormalizeDouble(buyPrice - pip*SL,Digits);
      double TPPrice = NormalizeDouble(buyPrice + pip*TP,Digits); 
      buyStop (lots, buyPrice,  SLPrice, TPPrice);
      
      double sellPrice = NormalizeDouble(base-pip*step*i,Digits);
      SLPrice = NormalizeDouble(sellPrice+pip*SL,Digits);
      TPPrice = NormalizeDouble(sellPrice-pip*TP,Digits);
      sellStop(lots, sellPrice, SLPrice, TPPrice);
   
   }   
   
   return(0);
}

int start(){
   static int numbars;
   onTick();
   if (Bars == numbars){
      return(0);
   }
   numbars = Bars;
   onOpen();
   return(0);
}

