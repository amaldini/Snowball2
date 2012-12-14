//+------------------------------------------------------------------+
//|                                   luktom visual order editor.mq4 |
//|                                   luktom :: £ukasz Tomaszkiewicz |
//|                                               http://luktom.biz/ |
//+------------------------------------------------------------------+
//|                                                                  |
//| EA dostêpne na licencji Creative Commons BY-SA                   |
//| Wiêcej szczegó³ow: http://go.luktom.biz/ccbysa                   |
//|                                                                  |
//+------------------------------------------------------------------+

#property copyright "£ukasz Tomaszkiewicz :: luktom"
#property link      "http://luktom.biz/"

#include <stderror.mqh>
#include <stdlib.mqh>
#include <lotSizeCalculator.mqh>

extern bool   use_timer             = true      ;
extern bool   delete_on_deinit      = true      ;

extern string ________STOP_LOSS                 ;
extern int    default_sl_level      = 150       ;
extern int    default_trailing_stop = 0         ;
extern color  sl_color              = Orange    ;
extern int    sl_style              = STYLE_DASH;

extern string _________FIXED_RISK_EURO          ;
extern double fixedRiskInEuro       = 20        ;
extern bool useFixedRiskInEuro    = true        ;
extern double rewardToRisk        = 2           ;

extern string ________TAKE_PROFIT               ;
extern int    default_tp_level      = 120       ;
extern color  tp_color              = DarkGray  ;
extern int    tp_style              = STYLE_DASH;

extern string ________BREAK_EVEN                ;
extern bool   use_be                = false     ;
extern int    default_be_level      = 15        ;
extern int    be_offset             = 3         ;
extern color  be_color              = Brown     ;
extern int    be_style              = STYLE_DASH;

extern string ________CANCEL_LEVEL              ;
extern bool   use_cl                = false     ;
extern int    default_cl_level      = 100       ;
extern color  cl_color              = Purple    ;
extern int    cl_style              = STYLE_DASH;

extern string ________CLOSE_PART                ;
extern bool   use_cp                = false     ;
extern bool   cp_size_or_percent    = false     ;
extern string cp_levels             = "10,15,20";
extern string cp_lots               = "25,50,90";
extern color  cp_color              = Pink      ;
extern int    cp_style              = STYLE_DASH;
double cp_lvl[]   ;
double cp_lts[]   ;
int    cp_size = 0;

extern string ________OPEN_LEVEL                ;
extern color  ol_sell_color         = Red       ;
extern int    ol_sell_style         = STYLE_DASH;
extern color  ol_buy_color          = Blue      ;
extern int    ol_buy_style          = STYLE_DASH;

void init()
{
   if(use_cp)
      cp_size = MathMin(listToTab(cp_levels,cp_lvl),listToTab(cp_lots,cp_lts));
   
   if(use_timer)  
      timer();
}

void timer()
{
   while(!IsStopped())
   {
      Sleep(500);
      
      if(IsExpertEnabled())
         start();
   }
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

void start()
{
   RefreshRates();
   
   for(int i=0; i<OrdersTotal(); i++)
   {
      if(OrderSelect(i,SELECT_BY_POS))
      {
         if(OrderSymbol()==Symbol())
         {
            double point   = MarketInfo(Symbol(),MODE_POINT );
            int    dgts    = MarketInfo(Symbol(),MODE_DIGITS);
            int    oDir;
            double BidAsk;
            
            int oType   = OrderType();
            int oTicket = OrderTicket();
            
            double oOpenPrice    = OrderOpenPrice();
            double oStopLoss     = OrderStopLoss();
            double oTakeProfit   = OrderTakeProfit();
            double oLots         = OrderLots();
            int magicNumber      = OrderMagicNumber();
            
            datetime oExpiration = OrderExpiration();
            
            string oComment      = OrderComment();
            
            if(oType%2) //sell
            {
               oDir   = -1;
               BidAsk = MarketInfo(Symbol(),MODE_ASK);
            }
            else              //buy
            {
               oDir   =  1;
               BidAsk = MarketInfo(Symbol(),MODE_BID);            
            }
            
            if (oType == OP_BUYSTOP || oType==OP_SELLLIMIT || oType==OP_SELLSTOP || oType==OP_BUYLIMIT) {
               if (useFixedRiskInEuro && (oStopLoss>0)) {
                  double calculatedLots = calculateLotSize(oOpenPrice,oStopLoss,fixedRiskInEuro);
                  double calculatedTP = NormalizeDouble(oOpenPrice+(oOpenPrice-oStopLoss)*rewardToRisk,dgts);
                  if (MathAbs(calculatedLots-oLots)>0.001) {
                     if (waitCounter<5) {
                        waitCounter++;
                     } else {
                        waitCounter = 0;
                        if (calculatedLots<0.01) calculatedLots = 0.01;
                        oLots = calculatedLots;
                        ObjectDelete("lvoe_ol_" + oTicket);
                        ObjectDelete("lvoe_sl_" + oTicket);
                        ObjectDelete("lvoe_tp_" + oTicket);
                        ObjectDelete("lvoe_be_" + oTicket);
                        OrderDelete(oTicket);
                        orderSendReliable(Symbol(), oType, oLots, oOpenPrice, 1, oStopLoss, calculatedTP, "", magicNumber, oExpiration, CLR_NONE, "changeLots");
                        return(0);
                     }
                  }
                  /*
                  if (calculatedTP!=NormalizeDouble(oTakeProfit,dgts)) {
                     ObjectDelete("lvoe_tp_" + oTicket);
                     if(!OrderModify(oTicket,oOpenPrice,oStopLoss,calculatedTP,oExpiration,CLR_NONE)) 
                     {
                        errorPrint(StringConcatenate("Modify OL #",oTicket),GetLastError());
                     }
                     continue;
                  }
                  */
               }
            }
            
            if(-1 == ObjectFind("lvoe_ol_" + oTicket))
            {
               if(oType==OP_SELLLIMIT || oType==OP_SELLSTOP)
               {
                  ObjectCreate("lvoe_ol_" + oTicket,OBJ_HLINE,0,Time[0],oOpenPrice);
                  ObjectSet("lvoe_ol_" + oTicket,OBJPROP_COLOR,ol_sell_color);
                  ObjectSet("lvoe_ol_" + oTicket,OBJPROP_STYLE,ol_sell_style);
               }
               else if(oType==OP_BUYLIMIT || oType==OP_BUYSTOP)
               {
                  ObjectCreate("lvoe_ol_" + oTicket,OBJ_HLINE,0,Time[0],oOpenPrice);
                  ObjectSet("lvoe_ol_" + oTicket,OBJPROP_COLOR,ol_buy_color);
                  ObjectSet("lvoe_ol_" + oTicket,OBJPROP_STYLE,ol_buy_style);
               }
            }
            else
            {
               if(oType < 2)
                  ObjectDelete("lvoe_ol_" + oTicket);
               
               double setOL = NormalizeDouble(ObjectGet("lvoe_ol_" + oTicket,OBJPROP_PRICE1),dgts);
               ObjectSet("lvoe_ol_" + oTicket,OBJPROP_PRICE1,setOL);
               if(NormalizeDouble(oOpenPrice,dgts) != setOL)
               {
                  if(!OrderModify(oTicket,setOL,oStopLoss,oTakeProfit,oExpiration,CLR_NONE)) 
                  {
                     errorPrint(StringConcatenate("Modify OL #",oTicket),GetLastError());
                  }
                  continue;
               }
            }

            if(oStopLoss>0 || default_sl_level>0)
            {
               if(-1 == ObjectFind("lvoe_sl_" + oTicket))
               {
                  if(0 == oStopLoss)
                     ObjectCreate("lvoe_sl_" + oTicket,OBJ_HLINE,0,Time[0],oOpenPrice-oDir*default_sl_level*point);
                  else
                     ObjectCreate("lvoe_sl_" + oTicket,OBJ_HLINE,0,Time[0],oStopLoss);
                     
                  ObjectSet("lvoe_sl_" + oTicket,OBJPROP_COLOR,sl_color);
                  ObjectSet("lvoe_sl_" + oTicket,OBJPROP_STYLE,sl_style);
                  
                  if(default_trailing_stop>0)
                     ObjectSetText("lvoe_sl_" + oTicket,"#"+oTicket+" stop loss, ts="+default_trailing_stop,11);
                  else
                     ObjectSetText("lvoe_sl_" + oTicket,"#"+oTicket+" stop loss",11);
               }
               else
               {
                  int tspos = StringFind(ObjectDescription("lvoe_sl_"+oTicket),"ts=");

                  if(-1 != tspos && oType < 2)
                  {
                     int ts = StrToInteger(StringSubstr(ObjectDescription("lvoe_sl_"+oTicket),tspos+3));

                     if(oDir*(BidAsk - oStopLoss) > ts*point )
                        ObjectSet("lvoe_sl_"+oTicket,OBJPROP_PRICE1,BidAsk - oDir*ts*point);
                  }

                  double setSL = NormalizeDouble(ObjectGet("lvoe_sl_" + oTicket,OBJPROP_PRICE1),dgts); 
                  ObjectSet("lvoe_sl_" + oTicket,OBJPROP_PRICE1,setSL);
                  if(NormalizeDouble(oStopLoss,dgts) != setSL)
                  {
                     if(!OrderModify(oTicket,oOpenPrice,setSL,oTakeProfit,oExpiration,CLR_NONE))
                     {
                        errorPrint(StringConcatenate("Modify SL #",oTicket),GetLastError());
                     }
                     continue;
                  }
               }
            }
            else
               clean("lvoe_sl_" + oTicket);

            if(oTakeProfit>0 || default_tp_level>0)
            {
               if(-1 == ObjectFind("lvoe_tp_" + oTicket))
               {
                  if(0 == oTakeProfit)
                     ObjectCreate("lvoe_tp_" + oTicket,OBJ_HLINE,0,Time[0],oOpenPrice+oDir*default_tp_level*point);
                  else
                     ObjectCreate("lvoe_tp_" + oTicket,OBJ_HLINE,0,Time[0],oTakeProfit);
                     
                  ObjectSet("lvoe_tp_" + oTicket,OBJPROP_COLOR,tp_color);
                  ObjectSet("lvoe_tp_" + oTicket,OBJPROP_STYLE,tp_style);
               }
               else
               {
                  double setTP = NormalizeDouble(ObjectGet("lvoe_tp_" + oTicket,OBJPROP_PRICE1),dgts);
                  ObjectSet("lvoe_tp_" + oTicket,OBJPROP_PRICE1,setTP);                  
                  if(NormalizeDouble(oTakeProfit,dgts)!=setTP)
                  {
                     if(!OrderModify(oTicket,oOpenPrice,oStopLoss,setTP,oExpiration,CLR_NONE))
                     {
                        errorPrint(StringConcatenate("Modify TP #",oTicket),GetLastError());
                     }
                     continue;
                  }
               }
            }
            else
               clean("lvoe_tp_" + oTicket);

            if(use_cp && cp_size > 0)
            {              
               if(-1 == ObjectFind("lvoe_cp_" + oTicket))
               {
                  if( StringLen(oComment) < 5 || (-1 == StringFind(oComment,"from") && -1 == StringFind(oComment,"split")))
                  {
                     //if(oDir*(oStopLoss - oOpenPrice) < 0) 
                     {
                        ObjectCreate("lvoe_cp_" + oTicket,OBJ_HLINE,0,Time[0],oOpenPrice+oDir*cp_lvl[0]*point);
                        ObjectSet("lvoe_cp_" + oTicket,OBJPROP_COLOR,cp_color);
                        ObjectSet("lvoe_cp_" + oTicket,OBJPROP_STYLE,cp_style);
                     }
                  }
               }
               else if (oType<2)
               {
                  if(oDir*(BidAsk - ObjectGet("lvoe_cp_" + oTicket,OBJPROP_PRICE1)) >= 0) 
                  {
                     int    deep        = 0;
                     double firstLot    = oLots;                     
                     string description = ObjectDescription("lvoe_cp_" + oTicket);
                     
                     if(StringLen(description) > 0)
                     {
                        int temp = StringFind(description,"_");
                        deep    = StrToInteger(StringSubstr(description,0,temp));
                        firstLot = StrToDouble (StringSubstr(description,temp+1));
                     }
                                                               
                     if(OrderClose(oTicket,cpCountLots(oLots, firstLot, deep),BidAsk,0))
                     {   
                        deep++;
                        if(deep < cp_size)
                        {
                           int newTicket = searchNewTicket(oTicket);
                           if( newTicket > 0 ) 
                           {                                               
                              ObjectCreate ("lvoe_cp_" + newTicket,OBJ_HLINE,0,Time[0],oOpenPrice+oDir*cp_lvl[deep]*point);
                              ObjectSet("lvoe_cp_" + newTicket,OBJPROP_COLOR,cp_color);
                              ObjectSet("lvoe_cp_" + newTicket,OBJPROP_STYLE,cp_style);
                              ObjectSetText("lvoe_cp_" + newTicket,StringConcatenate(deep,"_",DoubleToStr(firstLot,dgts)),11);
                           }  
                        }
                        ObjectDelete("lvoe_cp_"+oTicket);
                     }
                     else
                        errorPrint(StringConcatenate("Close Part #",oTicket),GetLastError());

                     continue;
                  }
               }
            }

            if(use_be)
            {
               if(-1 == ObjectFind("lvoe_be_" + oTicket))
               {
                  if(oDir*(oStopLoss-oOpenPrice)<0)
                  {
                     ObjectCreate("lvoe_be_" + oTicket,OBJ_HLINE,0,Time[0],oOpenPrice+oDir*default_be_level*point);
                     ObjectSet("lvoe_be_" + oTicket,OBJPROP_COLOR,be_color);
                     ObjectSet("lvoe_be_" + oTicket,OBJPROP_STYLE,be_style);
                  }
               }
               else if(oType < 2 && oDir*(BidAsk-ObjectGet("lvoe_be_" + oTicket,OBJPROP_PRICE1))>=0) 
               {
                  ObjectSet("lvoe_sl_" + oTicket,OBJPROP_PRICE1,oOpenPrice+oDir*be_offset*point);
                  ObjectDelete("lvoe_be_" + oTicket);
                  continue;
               }
            }

            if(use_cl)
            {
               if(-1 == ObjectFind("lvoe_cl_" + oTicket))
               {
                  if(oType > 1)
                  {
                     if(oType==OP_BUYSTOP || oType==OP_SELLLIMIT)
                        ObjectCreate("lvoe_cl_" + oTicket,OBJ_HLINE,0,Time[0],oOpenPrice-default_cl_level*point);
                     else
                        ObjectCreate("lvoe_cl_" + oTicket,OBJ_HLINE,0,Time[0],oOpenPrice+default_cl_level*point);
                     
                     ObjectSet("lvoe_cl_" + oTicket,OBJPROP_COLOR,cl_color);
                     ObjectSet("lvoe_cl_" + oTicket,OBJPROP_STYLE,cl_style);
                  }
               }
               else
               {
                  if(     (oType==OP_BUYSTOP  || oType==OP_SELLLIMIT) && BidAsk <= ObjectGet("lvoe_cl_" + oTicket,OBJPROP_PRICE1)) 
                     OrderDelete(oTicket);
                  else if((oType==OP_BUYLIMIT || oType==OP_SELLSTOP ) && BidAsk >= ObjectGet("lvoe_cl_" + oTicket,OBJPROP_PRICE1))
                     OrderDelete(oTicket);                  
                  else
                     ObjectDelete("lvoe_cl_" + oTicket);
               }
            }
            
         }
      }
   }

   for(i=0; i<OrdersHistoryTotal(); i++)
   {
      if(OrderSelect(i,SELECT_BY_POS,MODE_HISTORY))
      {
         clean("lvoe_ol_" + OrderTicket());
         clean("lvoe_tp_" + OrderTicket());
         clean("lvoe_sl_" + OrderTicket());
         clean("lvoe_be_" + OrderTicket());
         clean("lvoe_cl_" + OrderTicket());
         clean("lvoe_cp_" + OrderTicket());
      }
   }
   
   WindowRedraw(); 
}
void clean(string name)
{
   if(-1 != ObjectFind(name))  ObjectDelete(name);
}
double cpCountLots(double lots, double orygLots, int deep)
{
   double loty;
   
   if(cp_size_or_percent) loty = cp_lts[deep];
   else                   loty = lots - (100-cp_lts[deep])*orygLots*0.01;
      
   if(loty > lots)        loty = lots;
      
   return (normalizeLots(loty));
}
double normalizeLots(double value) 
{
   double minLots=MarketInfo(Symbol(),MODE_MINLOT);
   double maxLots=MarketInfo(Symbol(),MODE_MAXLOT);
   
   if     (value < minLots)
      value = minLots;
   else if(value > maxLots)
      value = maxLots;
    
   if(minLots < 0.1) 
      return(NormalizeDouble(value,2));
   else
      return(NormalizeDouble(value,1));
}
int listToTab(string list, double &tab[]) //zwraca rozmiar tablicy
{
   if(StringLen(list) > 0)
   {
      ArrayResize(tab,1);
      int i     = 0;
      int start = 0;
      int end   = StringFind(list,",");
      
      while( end != -1 )
      {
         tab[i] = StrToDouble( StringSubstr(list,start,end-start) );
         start = end+1;
         end = StringFind(list,",",start);
         i++;
         ArrayResize(tab,i+1);
      }
      
      tab[i] = StrToDouble( StringSubstr(list,start) );
      
      return (i+1);
   }
   else
      return (0);
}
int searchNewTicket(int oldTicket)
{
   for(int i=OrdersTotal()-1; i>=0; i--)
      if(OrderSelect(i,SELECT_BY_POS) && StrToInteger(StringSubstr(OrderComment(),StringFind(OrderComment(),"#")+1)) == oldTicket )
         return (OrderTicket());
   return (-1);
}
void errorPrint(string type, int err)
{  
   Print(type," ERROR(",err,") = ",ErrorDescription(err));
}