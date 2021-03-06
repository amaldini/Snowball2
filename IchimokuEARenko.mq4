// ------------------------------------------------------------------------------------------------
// Copyright � 2011, www.lifesdream.org
// http://www.lifesdream.org
// ------------------------------------------------------------------------------------------------
#include <stdlib.mqh>
#include <stderror.mqh> 
#include <common_functions.mqh>
#property copyright "Copyright � 2011, www.lifesdream.org"
#property link "http://www.lifesdream.org"

// ------------------------------------------------------------------------------------------------
// VARIABLES EXTERNAS
// ------------------------------------------------------------------------------------------------


// Configuration
extern string www.lifesdream.org = "Ichimoku EA v1.3";
extern string CommonSettings = "---------------------------------------------";
extern int user_slippage = 2; 

extern int signal_strength = 1; // 1=strong | 2: neutral | 3: weak
extern string MoneyManagementSettings = "---------------------------------------------";
// Money Management
//extern int money_management = 1;
//extern int risk=1;
// extern int progression = 2; // 0=none | 1:ascending | 2:martingale
// Indicator
extern string IndicatorSettings = "---------------------------------------------";
extern int tenkan_sen=9;
extern int kijun_sen=26;
extern int senkou_span = 52;
extern int shift = 1;

// ------------------------------------------------------------------------------------------------
// VARIABLES GLOBALES
// ------------------------------------------------------------------------------------------------
string key1 = "Ichimoku EA v1.3 (strategy 1)";
string key2 = "Ichimoku EA v1.3 (strategy 2)";
string key3 = "Ichimoku EA v1.3 (strategy 3)";
double points_per_pip;
double pip;
// Definimos 1 variable para guardar los tickets
int order_ticket1;
// Definimos 1 variable para guardar los lotes
double order_lots1;
// Definimos 1 variable para guardar las valores de apertura de las ordenes
double order_price1;
// Definimos 1 variable para guardar los beneficios
double order_profit1;
// Definimos 1 variable para guardar los tiempos
int order_time1;
// indicadores
double signal1=0;

int CHINKOU_VS_KUMO=0;  // -1 below, 0 inside, 1 above
int PRICE_VS_KUMO=0;    // -1 below, 0 inside, 1 above
int TENKAN_VS_KIJOUN=0; // -1 below, 0 neutral, 1 above
int CHINKOU_VS_PRICE=0; // -1 below, 0 neutral, 1 above
int PRICE_VS_KIJOUN = 0; // -1 below, 0 neutral, 1 above
int PRICE_VS_TENKAN = 0; // -1 below, 0 neutral, 1 above

bool touchedAboveKumo=false;
bool touchedBelowKumo=false;
bool touchedInsideKumo=false;

bool touchedAboveKijoun=false;
bool touchedBelowKijoun=false;

bool touchedAboveTenkan=false;
bool touchedBelowTenkan=false;

bool touchedAbovePA = false;
bool touchedBelowPA = false;

// Cantidad de ordenes;
int orders1 = 0;
int direction1= 0;
double last_order_profit=0, last_order_lots=0;

int nLastConsecutiveLosses = 0;
int numCycles=0;

// Colores
color c=Black;
// Cuenta
double balance, equity;
int slippage=0;
// OrderReliable
int retry_attempts = 10; 
double sleep_time = 4.0;
double sleep_maximum	= 25.0;  // in seconds
string OrderReliable_Fname = "OrderReliable fname unset";
static int _OR_err = 0;
string OrderReliableVersion = "V1_1_1"; 

double resistance=0;
double support=0;

double TRAILSTOP_PIPS = 4;

// ---- Trailing Stops
void TrailStops()
{        
   int digit  = MarketInfo(Symbol(),MODE_DIGITS);
   
   double spread = MathAbs(Bid-Ask);
   double lastCandleClose= iClose(NULL,0,1);

    int total=OrdersTotal();
    for (int cnt=0;cnt<total;cnt++)
    { 
     OrderSelect(cnt, SELECT_BY_POS);   
     int mode=OrderType();    
        if ( OrderSymbol()==Symbol() ) 
        {
            if ( mode==OP_BUY )
            {  
               double BuyStop = lastCandleClose-(spread+pip*TRAILSTOP_PIPS);
               
               if (OrderStopLoss()<BuyStop || OrderStopLoss()==0) {
                  OrderModify(OrderTicket(),OrderOpenPrice(),
                              NormalizeDouble(BuyStop, digit),
                              OrderTakeProfit(),0,LightGreen);
               }
			      
			   }
            if ( mode==OP_SELL )
            {
               double SellStop = lastCandleClose+(spread+pip*TRAILSTOP_PIPS);
               if (OrderStopLoss()>SellStop || OrderStopLoss()==0) {
                  OrderModify(OrderTicket(),OrderOpenPrice(),
   		                  NormalizeDouble(SellStop, digit),
   		                  OrderTakeProfit(),0,Yellow);	 
   		      }   
                 
            }
         }   
      } 
}


// ------------------------------------------------------------------------------------------------
// START
// ------------------------------------------------------------------------------------------------
int start()
{  

  if (MarketInfo(Symbol(),MODE_DIGITS)==4)
  {
    slippage = user_slippage;
  }
  else if (MarketInfo(Symbol(),MODE_DIGITS)==5)
  {
    slippage = 10*user_slippage;
  }
  
  if(IsTradeAllowed() == false) 
  {
    Comment("Trade not allowed.");
    return;  
  }
  
  
    Comment(StringConcatenate("\nRenko Price Action EA running.",
                              "\nNext order lots (: ",CalcularVolumen(),
                              "\nLast consecutive losses:"+nLastConsecutiveLosses,
                              "\nNumCycles:"+numCycles,
                              "\ntouchedAbovePA:"+touchedAbovePA,
                              "\ntouchedBelowPA:"+touchedBelowPA
                             )
           );
  
  
  // Actualizamos el estado actual
  InicializarVariables();
  ActualizarOrdenes();
  
  double spread = MathAbs(Ask-Bid)/pip;
  if (spread>1.21) {
      Comment("Spread: "+DoubleToStr(spread,2)+" too big!!!");
  } else {
      Robot3();    
  }
  
  // TrailStops();
  
  
  return(0);
}


// ------------------------------------------------------------------------------------------------
// INICIALIZAR VARIABLES
// ------------------------------------------------------------------------------------------------
void InicializarVariables()
{
  orders1=0;
  direction1=0;
  order_ticket1 = 0;
  order_lots1 = 0;
  order_price1 = 0;
  order_time1 = 0;
  order_profit1 = 0;
  last_order_profit = 0;
  last_order_lots = 0;
  
}

// ------------------------------------------------------------------------------------------------
// ACTUALIZAR ORDENES
// ------------------------------------------------------------------------------------------------
void ActualizarOrdenes()
{
  int ordenes1=0;
  
  // Lo que hacemos es introducir los tickets, los lotes, y los valores de apertura en las matrices. 
  // Adem�s guardaremos el n�mero de ordenes en una variables.
  
  // Ordenes de compra
  for(int i=0; i<OrdersTotal(); i++)
  {
    if(OrderSelect(i,SELECT_BY_POS,MODE_TRADES) == true)
    {
      if(OrderSymbol() == Symbol())
      {
        order_ticket1 = OrderTicket();
        order_lots1 = OrderLots();
        order_price1 = OrderOpenPrice();
        order_time1 = OrderOpenTime();
        order_profit1 = OrderProfit();
        ordenes1++;
        if (OrderType()==OP_BUY) direction1=1;
        if (OrderType()==OP_SELL) direction1=2;
      }
      
    }
  }
  
  // Actualizamos variables globales
  orders1 = ordenes1;
  
}

// ------------------------------------------------------------------------------------------------
// ESCRIBE
// ------------------------------------------------------------------------------------------------
void Escribe(string nombre, string s, int x, int y, string font, int size, color c)
{
  if (ObjectFind(nombre)!=-1)
  {
    ObjectSetText(nombre,s,size,font,c);
  }
  else
  {
    ObjectCreate(nombre,OBJ_LABEL,0,0,0);
    ObjectSetText(nombre,s,size,font,c);
    ObjectSet(nombre,OBJPROP_XDISTANCE, x);
    ObjectSet(nombre,OBJPROP_YDISTANCE, y);
  }
}

int fib(int i) {
   if (i==0) return (1);
   return (i+fib(i-1));
}


// ------------------------------------------------------------------------------------------------
// CALCULA VALOR PIP
// ------------------------------------------------------------------------------------------------
double CalculaValorPip(double lotes)
{ 
   double aux_mm_valor=0;
   
   double aux_mm_tick_value = MarketInfo(Symbol(), MODE_TICKVALUE);
   double aux_mm_tick_size = MarketInfo(Symbol(), MODE_TICKSIZE);
   int aux_mm_digits = MarketInfo(Symbol(),MODE_DIGITS);   
   double aux_mm_veces_lots = 1/lotes;
      
   if (aux_mm_digits==5)
   {
     aux_mm_valor=aux_mm_tick_value*10;
   }
   else if (aux_mm_digits==4)
   {
     aux_mm_valor = aux_mm_tick_value;
   }
   
   if (aux_mm_digits==3)
   {
     aux_mm_valor=aux_mm_tick_value*10;
   }
   else if (aux_mm_digits==2)
   {
     aux_mm_valor = aux_mm_tick_value;
   }
   
   aux_mm_valor = aux_mm_valor/aux_mm_veces_lots;
   
   return(aux_mm_valor);
}


double LOWER_MA(int shift, int period) {
   return (iMA(NULL,0,period,0,MODE_SMA, PRICE_LOW, shift));
}

double HIGHER_MA(int shift, int period) {
   return (iMA(NULL,0,period,0,MODE_SMA, PRICE_HIGH, shift));
}

double CLOSE_MA(int shift, int period) {
   return (iMA(NULL,0,period,0,MODE_SMA, PRICE_CLOSE, shift));
}

double close1;

int CalculateSignal() {
   int aux=0;

   double hMA = HIGHER_MA(2,6);
   double lMA = LOWER_MA(2,6);
   double cMA = CLOSE_MA(2,6);
   close1 = iClose(NULL,0,1);
   
   if (close1>cMA && touchedBelowPA) aux = 1;
   if (close1<cMA && touchedAbovePA) aux = 2;
   
   if (close1>cMA) touchedAbovePA=true;
   if (close1<cMA) touchedBelowPA=true;
   
   // if (aux == 1) touchedBelowPA = false;
   // if (aux == 2) touchedAbovePA = false;
   
   return (aux);
}

// ------------------------------------------------------------------------------------------------
// CALCULA SIGNAL 
// ------------------------------------------------------------------------------------------------
int CalculaSignal(int strategy,int aux_tenkan_sen, double aux_kijun_sen, double aux_senkou_span, int aux_shift)
{
  int aux=0;
  double kt1=0, kb1=0, kt2=0, kb2=0;  
  double ts1,ts2,ks1,ks2,ssA1,ssA2,ssB1,ssB2,close1,close2; 
  double chinkou1;
  
  ts1 = iIchimoku(Symbol(), 0, aux_tenkan_sen, aux_kijun_sen, aux_senkou_span, MODE_TENKANSEN, aux_shift);
  ks1 = iIchimoku(Symbol(), 0, aux_tenkan_sen, aux_kijun_sen, aux_senkou_span, MODE_KIJUNSEN, aux_shift);
  ssA1 = iIchimoku(Symbol(), 0, aux_tenkan_sen, aux_kijun_sen, aux_senkou_span, MODE_SENKOUSPANA, aux_shift);
  ssB1 = iIchimoku(Symbol(), 0, aux_tenkan_sen, aux_kijun_sen, aux_senkou_span, MODE_SENKOUSPANB, aux_shift);
  close1 = iClose(Symbol(), 0, aux_shift);
  ts2 = iIchimoku(Symbol(), 0, aux_tenkan_sen, aux_kijun_sen, aux_senkou_span, MODE_TENKANSEN, aux_shift+1);
  ks2 = iIchimoku(Symbol(), 0, aux_tenkan_sen, aux_kijun_sen, aux_senkou_span, MODE_KIJUNSEN, aux_shift+1);
  ssA2 = iIchimoku(Symbol(), 0, aux_tenkan_sen, aux_kijun_sen, aux_senkou_span, MODE_SENKOUSPANA, aux_shift+1);
  ssB2 = iIchimoku(Symbol(), 0, aux_tenkan_sen, aux_kijun_sen, aux_senkou_span, MODE_SENKOUSPANB, aux_shift+1);
  close2 = iClose(Symbol(), 0, aux_shift+1);
  
  kt1 = MathMax(ssA1,ssB1);
  kb1 = MathMin(ssA1,ssB1);
  
  kt2 = MathMax(ssA2,ssB2);
  kb2 = MathMin(ssA2,ssB2);
  
  int chinkouShift = aux_kijun_sen;
  chinkou1 = iIchimoku(Symbol(), 0, aux_tenkan_sen, aux_kijun_sen, aux_senkou_span, MODE_CHINKOUSPAN, chinkouShift+aux_shift);
  double priceAtChinkou = iClose(Symbol(),0,chinkouShift+aux_shift);
  double ssA3 = iIchimoku(Symbol(), 0, aux_tenkan_sen, aux_kijun_sen, aux_senkou_span, MODE_SENKOUSPANA, chinkouShift+aux_shift);
  double ssB3 = iIchimoku(Symbol(), 0, aux_tenkan_sen, aux_kijun_sen, aux_senkou_span, MODE_SENKOUSPANB, chinkouShift+aux_shift);
  
  double kt3 = MathMax(ssA3,ssB3);
  double kb3 = MathMin(ssA3,ssB3);
  
  CHINKOU_VS_KUMO = 0;
  if (chinkou1>kt3) CHINKOU_VS_KUMO = 1;
  if (chinkou1<kb3) CHINKOU_VS_KUMO = -1;
  
  CHINKOU_VS_PRICE = 0;
  if (chinkou1>priceAtChinkou) CHINKOU_VS_PRICE = 1;
  if (chinkou1<priceAtChinkou) CHINKOU_VS_PRICE = -1;
  
  PRICE_VS_KUMO = 0;
  if (close1>kt1) PRICE_VS_KUMO = 1;
  if (close1<kb1) PRICE_VS_KUMO = -1;
  
  TENKAN_VS_KIJOUN = 0;
  if (ts1>ks1) TENKAN_VS_KIJOUN = 1;
  if (ts1<ks1) TENKAN_VS_KIJOUN = -1;
  
  PRICE_VS_KIJOUN = 0;
  if (close1 > ks1) PRICE_VS_KIJOUN = 1;
  if (close1 < ks1) PRICE_VS_KIJOUN = -1;
  
  PRICE_VS_TENKAN = 0;
  if (close1 > ts1) PRICE_VS_TENKAN = 1;
  if (close1 < ts1) PRICE_VS_TENKAN = -1;
  
   // int CHINKOU_VS_KUMO=0;  // -1 below, 0 inside 1 above
   // int PRICE_VS_KUMO=0;    // -1 below, 0 inside, 1 above
   // int TENKAN_VS_KIJOUN=0; // -1 below, 0 inside, 1 above
  
  
  // Valores de retorno
  // 1. Compra
  // 2. Venta
  // if (touchedBelowKumo || touchedInsideKumo) {
  //    if (PRICE_VS_KUMO==1 && CHINKOU_VS_KUMO==1 && CHINKOU_VS_PRICE==1) aux=1;
  // }
  // if (touchedAboveKumo || touchedInsideKumo) {
      // if (PRICE_VS_KUMO==-1 && CHINKOU_VS_KUMO==-1 && CHINKOU_VS_PRICE==-1) aux=2;
  // }
  
  if (touchedBelowKijoun) {
      if (PRICE_VS_KIJOUN==1) aux = 1;
  }
  
  if (touchedAboveKijoun) {
      if (PRICE_VS_KIJOUN==-1) aux = 2;
  } 
  /*
  if (touchedBelowTenkan) {
      if (PRICE_VS_TENKAN==1) aux = 1;
  }
  
  if (touchedAboveTenkan) {
      if (PRICE_VS_TENKAN==-1) aux = 2;
  }
  */
   if (PRICE_VS_KUMO==1) touchedAboveKumo=true;
   if (PRICE_VS_KUMO==-1) touchedBelowKumo=true;
   if (PRICE_VS_KUMO==0) touchedInsideKumo=true;
   
   if (PRICE_VS_KIJOUN==1) touchedAboveKijoun = true;
   if (PRICE_VS_KIJOUN==-1) touchedBelowKijoun = true;
   
   if (PRICE_VS_TENKAN==1) touchedAboveTenkan = true;
   if (PRICE_VS_TENKAN==-1) touchedBelowTenkan = true;
   // bool touchedAboveKumo=false;
   // bool touchedBelowKumo=false;
   // bool touchedInsideKumo=false;
  if (aux!=0) {
      touchedAboveKumo=false;
      touchedBelowKumo=false;
      touchedInsideKumo=false;  
      
      // touchedAboveKijoun = false;
      // touchedBelowKijoun = false;  
  }
  
  return(aux);  
}



int init() {
   points_per_pip = pointsPerPip();
   pip = Point * points_per_pip;
}

// ------------------------------------------------------------------------------------------------
// CALCULAR VOLUMEN
// ------------------------------------------------------------------------------------------------
double CalcularVolumen()
{ 
   double availableVolume = AccountEquity()*AccountLeverage()/4*1 / Ask / 100000;
   double lots = MathFloor(availableVolume*100)/100;
   return (lots);

   // int myfib = fib(nLastConsecutiveLosses);
   // if (myfib==0) myfib = 1;
   // return (min_lots);
   // return (min_lots*myfib);    
}
// ------------------------------------------------------------------------------------------------
// ROBOT 3
// ------------------------------------------------------------------------------------------------
void Robot3()
{
  int ticket=-1, i;
  bool cerrada=FALSE;  
  
  // signal1 = CalculaSignal(3,tenkan_sen,kijun_sen,senkou_span,shift);
  
  signal1 = CalculateSignal();
  
  bool bToClose=FALSE;
  if (orders1>0) {
      switch (signal1) {
         case 3:
            bToClose=TRUE;
            Comment("Close!!!");
            break;
         case 1:
            if (direction1==2) bToClose=TRUE;
            break;
         case 2:
            if (direction1==1) bToClose=TRUE;
            break;
      }
      
      if (!bToClose) {
         // VALUTARE QUI EVENTUALI TP E SL
      }
      
  }
  
  if (bToClose) {
      if (direction1==1) {
         cerrada=OrderCloseReliable(order_ticket1,order_lots1,MarketInfo(Symbol(),MODE_BID),slippage,Blue);
      } else if (direction1==2) {
         cerrada=OrderCloseReliable(order_ticket1,order_lots1,MarketInfo(Symbol(),MODE_ASK),slippage,Red); 
      }
      orders1=0;
      direction1=0; 
      if (order_profit1<0) nLastConsecutiveLosses++;
      if (order_profit1>10) { nLastConsecutiveLosses=0; numCycles++; }   
  } 
  
  calcSupportAndResistance();
  
  if (orders1==0 && direction1==0)
  {     
    
    // ----------
    // COMPRA
    // ----------
    if (signal1==1) {
      if (close1>resistance || resistance==0) { 
         ticket = OrderSendReliable(Symbol(),OP_BUY,CalcularVolumen(),MarketInfo(Symbol(),MODE_ASK),slippage,0,0,key3,"",0,Blue); 
         touchedBelowPA = false;
      }
    }
    // En este punto hemos ejecutado correctamente la orden de compra
    // Los arrays se actualizar�n en la siguiente ejecuci�n de start() con ActualizarOrdenes()
     
    // ----------
    // VENTA
    // ----------
    if (signal1==2) {
      if (close1<support || support==0) {
         ticket = OrderSendReliable(Symbol(),OP_SELL,CalcularVolumen(),MarketInfo(Symbol(),MODE_BID),slippage,0,0,key3,"",0,Red);         
         touchedAbovePA = false;
      }
    }
    // En este punto hemos ejecutado correctamente la orden de venta
    // Los arrays se actualizar�n en la siguiente ejecuci�n de start() con ActualizarOrdenes()       
  }  
    
}

void calcSupportAndResistance() {
  bool encontrada=FALSE;
  if (OrdersHistoryTotal()>0)
  {
    int i=1;
    
    while (i<=100 && encontrada==FALSE)
    { 
      int n = OrdersHistoryTotal()-i;
      
      if(OrderSelect(n,SELECT_BY_POS,MODE_HISTORY)==TRUE)
      {
         if (Symbol()==OrderSymbol()) {
          encontrada=TRUE;
          last_order_profit=OrderProfit();
          last_order_lots=OrderLots();
  
          
          double midPoint=0;
          double r,s;
          if (last_order_profit<0) {        
            midPoint = (OrderOpenPrice()+OrderClosePrice())/2;
            r = midPoint+MathAbs(OrderOpenPrice()-OrderClosePrice());
            s = midPoint-MathAbs(OrderOpenPrice()-OrderClosePrice());
            
            if (resistance>0) {
               // resistance = MathMax(resistance,r);
               resistance = r;
            } else { resistance = r; }
            
            if (support>0) {
               //   support = MathMin(support,s);
               support = s;
            } else { support = s; }
            
            if (resistance>0) {
               horizLine("resistance",resistance,LightSalmon,"resistance");   
            }  
            
            if (support>0) {
               horizLine("support",support,LightSalmon, "support");
            } 
            
          } else {
            
            resistance=0;
            support=0;  
            
            ObjectDelete("resistance");
            ObjectDelete("support");
          }
        }
      }
      i++;
    } 
}
}


//=============================================================================
//							 OrderSendReliable()
//
//	This is intended to be a drop-in replacement for OrderSend() which, 
//	one hopes, is more resistant to various forms of errors prevalent 
//	with MetaTrader.
//			  
//	RETURN VALUE: 
//
//	Ticket number or -1 under some error conditions.  Check
// final error returned by Metatrader with OrderReliableLastErr().
// This will reset the value from GetLastError(), so in that sense it cannot
// be a total drop-in replacement due to Metatrader flaw. 
//
//	FEATURES:
//
//		 * Re-trying under some error conditions, sleeping a random 
//		   time defined by an exponential probability distribution.
//
//		 * Automatic normalization of Digits
//
//		 * Automatically makes sure that stop levels are more than
//		   the minimum stop distance, as given by the server. If they
//		   are too close, they are adjusted.
//
//		 * Automatically converts stop orders to market orders 
//		   when the stop orders are rejected by the server for 
//		   being to close to market.  NOTE: This intentionally
//       applies only to OP_BUYSTOP and OP_SELLSTOP, 
//       OP_BUYLIMIT and OP_SELLLIMIT are not converted to market
//       orders and so for prices which are too close to current
//       this function is likely to loop a few times and return
//       with the "invalid stops" error message. 
//       Note, the commentary in previous versions erroneously said
//       that limit orders would be converted.  Note also
//       that entering a BUYSTOP or SELLSTOP new order is distinct
//       from setting a stoploss on an outstanding order; use
//       OrderModifyReliable() for that. 
//
//		 * Displays various error messages on the log for debugging.
//
//
//	Matt Kennel, 2006-05-28 and following
//
//=============================================================================
int OrderSendReliable(string symbol, int cmd, double volume, double price,
					  int slippage, double stoploss, double takeprofit,
					  string comment, int magic, datetime expiration = 0, 
					  color arrow_color = CLR_NONE) 
{

	// ------------------------------------------------
	// Check basic conditions see if trade is possible. 
	// ------------------------------------------------
	OrderReliable_Fname = "OrderSendReliable";
	OrderReliablePrint(" attempted " + OrderReliable_CommandString(cmd) + " " + volume + 
						" lots @" + price + " sl:" + stoploss + " tp:" + takeprofit); 
						
	//if (!IsConnected()) 
	//{
	//	OrderReliablePrint("error: IsConnected() == false");
	//	_OR_err = ERR_NO_CONNECTION; 
	//	return(-1);
	//}
	
	if (IsStopped()) 
	{
		OrderReliablePrint("error: IsStopped() == true");
		_OR_err = ERR_COMMON_ERROR; 
		return(-1);
	}
	
	int cnt = 0;
	while(!IsTradeAllowed() && cnt < retry_attempts) 
	{
		OrderReliable_SleepRandomTime(sleep_time, sleep_maximum); 
		cnt++;
	}
	
	if (!IsTradeAllowed()) 
	{
		OrderReliablePrint("error: no operation possible because IsTradeAllowed()==false, even after retries.");
		_OR_err = ERR_TRADE_CONTEXT_BUSY; 

		return(-1);  
	}

	// Normalize all price / stoploss / takeprofit to the proper # of digits.
	int digits = MarketInfo(symbol, MODE_DIGITS);
	if (digits > 0) 
	{
		price = NormalizeDouble(price, digits);
		stoploss = NormalizeDouble(stoploss, digits);
		takeprofit = NormalizeDouble(takeprofit, digits); 
	}
	
	if (stoploss != 0) 
		OrderReliable_EnsureValidStop(symbol, price, stoploss); 

	int err = GetLastError(); // clear the global variable.  
	err = 0; 
	_OR_err = 0; 
	bool exit_loop = false;
	bool limit_to_market = false; 
	
	// limit/stop order. 
	int ticket=-1;

	if ((cmd == OP_BUYSTOP) || (cmd == OP_SELLSTOP) || (cmd == OP_BUYLIMIT) || (cmd == OP_SELLLIMIT)) 
	{
		cnt = 0;
		while (!exit_loop) 
		{
			if (IsTradeAllowed()) 
			{
				ticket = OrderSend(symbol, cmd, volume, price, slippage, stoploss, 
									takeprofit, comment, magic, expiration, arrow_color);
				err = GetLastError();
				_OR_err = err; 
			} 
			else 
			{
				cnt++;
			} 
			
			switch (err) 
			{
				case ERR_NO_ERROR:
					exit_loop = true;
					break;
				
				// retryable errors
				case ERR_SERVER_BUSY:
				case ERR_NO_CONNECTION:
				case ERR_INVALID_PRICE:
				case ERR_OFF_QUOTES:
				case ERR_BROKER_BUSY:
				case ERR_TRADE_CONTEXT_BUSY: 
					cnt++; 
					break;
					
				case ERR_PRICE_CHANGED:
				case ERR_REQUOTE:
					RefreshRates();
					continue;	// we can apparently retry immediately according to MT docs.
					
				case ERR_INVALID_STOPS:
					double servers_min_stop = MarketInfo(symbol, MODE_STOPLEVEL) * MarketInfo(symbol, MODE_POINT); 
					if (cmd == OP_BUYSTOP) 
					{
						// If we are too close to put in a limit/stop order so go to market.
						if (MathAbs(MarketInfo(symbol,MODE_ASK) - price) <= servers_min_stop)	
							limit_to_market = true; 
							
					} 
					else if (cmd == OP_SELLSTOP) 
					{
						// If we are too close to put in a limit/stop order so go to market.
						if (MathAbs(MarketInfo(symbol,MODE_BID) - price) <= servers_min_stop)
							limit_to_market = true; 
					}
					exit_loop = true; 
					break; 
					
				default:
					// an apparently serious error.
					exit_loop = true;
					break; 
					
			}  // end switch 

			if (cnt > retry_attempts) 
				exit_loop = true; 
			 	
			if (exit_loop) 
			{
				if (err != ERR_NO_ERROR) 
				{
					OrderReliablePrint("non-retryable error: " + OrderReliableErrTxt(err)); 
				}
				if (cnt > retry_attempts) 
				{
					OrderReliablePrint("retry attempts maxed at " + retry_attempts); 
				}
			}
			 
			if (!exit_loop) 
			{
				OrderReliablePrint("retryable error (" + cnt + "/" + retry_attempts + 
									"): " + OrderReliableErrTxt(err)); 
				OrderReliable_SleepRandomTime(sleep_time, sleep_maximum); 
				RefreshRates(); 
			}
		}
		 
		// We have now exited from loop. 
		if (err == ERR_NO_ERROR) 
		{
			OrderReliablePrint("apparently successful OP_BUYSTOP or OP_SELLSTOP order placed, details follow.");
			OrderSelect(ticket, SELECT_BY_TICKET, MODE_TRADES); 
			OrderPrint(); 
			return(ticket); // SUCCESS! 
		} 
		if (!limit_to_market) 
		{
			OrderReliablePrint("failed to execute stop or limit order after " + cnt + " retries");
			OrderReliablePrint("failed trade: " + OrderReliable_CommandString(cmd) + " " + symbol + 
								"@" + price + " tp@" + takeprofit + " sl@" + stoploss); 
			OrderReliablePrint("last error: " + OrderReliableErrTxt(err)); 
			return(-1); 
		}
	}  // end	  
  
	if (limit_to_market) 
	{
		OrderReliablePrint("going from limit order to market order because market is too close.");
		if ((cmd == OP_BUYSTOP) || (cmd == OP_BUYLIMIT)) 
		{
			cmd = OP_BUY;
			price = MarketInfo(symbol,MODE_ASK);
		} 
		else if ((cmd == OP_SELLSTOP) || (cmd == OP_SELLLIMIT)) 
		{
			cmd = OP_SELL;
			price = MarketInfo(symbol,MODE_BID);
		}	
	}
	
	// we now have a market order.
	err = GetLastError(); // so we clear the global variable.  
	err = 0; 
	_OR_err = 0; 
	ticket = -1;

	if ((cmd == OP_BUY) || (cmd == OP_SELL)) 
	{
		cnt = 0;
		while (!exit_loop) 
		{
			if (IsTradeAllowed()) 
			{
				ticket = OrderSend(symbol, cmd, volume, price, slippage, 
									stoploss, takeprofit, comment, magic, 
									expiration, arrow_color);
				err = GetLastError();
				_OR_err = err; 
			} 
			else 
			{
				cnt++;
			} 
			switch (err) 
			{
				case ERR_NO_ERROR:
					exit_loop = true;
					break;
					
				case ERR_SERVER_BUSY:
				case ERR_NO_CONNECTION:
				case ERR_INVALID_PRICE:
				case ERR_OFF_QUOTES:
				case ERR_BROKER_BUSY:
				case ERR_TRADE_CONTEXT_BUSY: 
					cnt++; // a retryable error
					break;
					
				case ERR_PRICE_CHANGED:
				case ERR_REQUOTE:
					RefreshRates();
					continue; // we can apparently retry immediately according to MT docs.
					
				default:
					// an apparently serious, unretryable error.
					exit_loop = true;
					break; 
					
			}  // end switch 

			if (cnt > retry_attempts) 
			 	exit_loop = true; 
			 	
			if (!exit_loop) 
			{
				OrderReliablePrint("retryable error (" + cnt + "/" + 
									retry_attempts + "): " + OrderReliableErrTxt(err)); 
				OrderReliable_SleepRandomTime(sleep_time,sleep_maximum); 
				RefreshRates(); 
			}
			
			if (exit_loop) 
			{
				if (err != ERR_NO_ERROR) 
				{
					OrderReliablePrint("non-retryable error: " + OrderReliableErrTxt(err)); 
				}
				if (cnt > retry_attempts) 
				{
					OrderReliablePrint("retry attempts maxed at " + retry_attempts); 
				}
			}
		}
		
		// we have now exited from loop. 
		if (err == ERR_NO_ERROR) 
		{
			OrderReliablePrint("apparently successful OP_BUY or OP_SELL order placed, details follow.");
			OrderSelect(ticket, SELECT_BY_TICKET, MODE_TRADES); 
			OrderPrint(); 
			return(ticket); // SUCCESS! 
		} 
		OrderReliablePrint("failed to execute OP_BUY/OP_SELL, after " + cnt + " retries");
		OrderReliablePrint("failed trade: " + OrderReliable_CommandString(cmd) + " " + symbol + 
							"@" + price + " tp@" + takeprofit + " sl@" + stoploss); 
		OrderReliablePrint("last error: " + OrderReliableErrTxt(err)); 
		return(-1); 
	}
}
	
//=============================================================================
//							 OrderSendReliableMKT()
//
//	This is intended to be an alternative for OrderSendReliable() which
// will update market-orders in the retry loop with the current Bid or Ask.
// Hence with market orders there is a greater likelihood that the trade will
// be executed versus OrderSendReliable(), and a greater likelihood it will
// be executed at a price worse than the entry price due to price movement. 
//			  
//	RETURN VALUE: 
//
//	Ticket number or -1 under some error conditions.  Check
// final error returned by Metatrader with OrderReliableLastErr().
// This will reset the value from GetLastError(), so in that sense it cannot
// be a total drop-in replacement due to Metatrader flaw. 
//
//	FEATURES:
//
//     * Most features of OrderSendReliable() but for market orders only. 
//       Command must be OP_BUY or OP_SELL, and specify Bid or Ask at
//       the time of the call.
//
//     * If price moves in an unfavorable direction during the loop,
//       e.g. from requotes, then the slippage variable it uses in 
//       the real attempt to the server will be decremented from the passed
//       value by that amount, down to a minimum of zero.   If the current
//       price is too far from the entry value minus slippage then it
//       will not attempt an order, and it will signal, manually,
//       an ERR_INVALID_PRICE (displayed to log as usual) and will continue
//       to loop the usual number of times. 
//
//		 * Displays various error messages on the log for debugging.
//
//
//	Matt Kennel, 2006-08-16
//
//=============================================================================
int OrderSendReliableMKT(string symbol, int cmd, double volume, double price,
					  int slippage, double stoploss, double takeprofit,
					  string comment, int magic, datetime expiration = 0, 
					  color arrow_color = CLR_NONE) 
{

	// ------------------------------------------------
	// Check basic conditions see if trade is possible. 
	// ------------------------------------------------
	OrderReliable_Fname = "OrderSendReliableMKT";
	OrderReliablePrint(" attempted " + OrderReliable_CommandString(cmd) + " " + volume + 
						" lots @" + price + " sl:" + stoploss + " tp:" + takeprofit); 

   if ((cmd != OP_BUY) && (cmd != OP_SELL)) {
      OrderReliablePrint("Improper non market-order command passed.  Nothing done.");
      _OR_err = ERR_MALFUNCTIONAL_TRADE; 
      return(-1);
   }

	//if (!IsConnected()) 
	//{
	//	OrderReliablePrint("error: IsConnected() == false");
	//	_OR_err = ERR_NO_CONNECTION; 
	//	return(-1);
	//}
	
	if (IsStopped()) 
	{
		OrderReliablePrint("error: IsStopped() == true");
		_OR_err = ERR_COMMON_ERROR; 
		return(-1);
	}
	
	int cnt = 0;
	while(!IsTradeAllowed() && cnt < retry_attempts) 
	{
		OrderReliable_SleepRandomTime(sleep_time, sleep_maximum); 
		cnt++;
	}
	
	if (!IsTradeAllowed()) 
	{
		OrderReliablePrint("error: no operation possible because IsTradeAllowed()==false, even after retries.");
		_OR_err = ERR_TRADE_CONTEXT_BUSY; 

		return(-1);  
	}

	// Normalize all price / stoploss / takeprofit to the proper # of digits.
	int digits = MarketInfo(symbol, MODE_DIGITS);
	if (digits > 0) 
	{
		price = NormalizeDouble(price, digits);
		stoploss = NormalizeDouble(stoploss, digits);
		takeprofit = NormalizeDouble(takeprofit, digits); 
	}
	
	if (stoploss != 0) 
		OrderReliable_EnsureValidStop(symbol, price, stoploss); 

	int err = GetLastError(); // clear the global variable.  
	err = 0; 
	_OR_err = 0; 
	bool exit_loop = false;
	
	// limit/stop order. 
	int ticket=-1;

	// we now have a market order.
	err = GetLastError(); // so we clear the global variable.  
	err = 0; 
	_OR_err = 0; 
	ticket = -1;

	if ((cmd == OP_BUY) || (cmd == OP_SELL)) 
	{
		cnt = 0;
		while (!exit_loop) 
		{
			if (IsTradeAllowed()) 
			{
            double pnow = price;
            int slippagenow = slippage;
            if (cmd == OP_BUY) {
            	// modification by Paul Hampton-Smith to replace RefreshRates()
               pnow = NormalizeDouble(MarketInfo(symbol,MODE_ASK),MarketInfo(symbol,MODE_DIGITS)); // we are buying at Ask
               if (pnow > price) {
                  slippagenow = slippage - (pnow-price)/MarketInfo(symbol,MODE_POINT); 
               }
            } else if (cmd == OP_SELL) {
            	// modification by Paul Hampton-Smith to replace RefreshRates()
               pnow = NormalizeDouble(MarketInfo(symbol,MODE_BID),MarketInfo(symbol,MODE_DIGITS)); // we are buying at Ask
               if (pnow < price) {
                  // moved in an unfavorable direction
                  slippagenow = slippage - (price-pnow)/MarketInfo(symbol,MODE_POINT);
               }
            }
            if (slippagenow > slippage) slippagenow = slippage; 
            if (slippagenow >= 0) {
            
				   ticket = OrderSend(symbol, cmd, volume, pnow, slippagenow, 
									stoploss, takeprofit, comment, magic, 
									expiration, arrow_color);
			   	err = GetLastError();
			   	_OR_err = err; 
			  } else {
			      // too far away, manually signal ERR_INVALID_PRICE, which
			      // will result in a sleep and a retry. 
			      err = ERR_INVALID_PRICE;
			      _OR_err = err; 
			  }
			} 
			else 
			{
				cnt++;
			} 
			switch (err) 
			{
				case ERR_NO_ERROR:
					exit_loop = true;
					break;
					
				case ERR_SERVER_BUSY:
				case ERR_NO_CONNECTION:
				case ERR_INVALID_PRICE:
				case ERR_OFF_QUOTES:
				case ERR_BROKER_BUSY:
				case ERR_TRADE_CONTEXT_BUSY: 
					cnt++; // a retryable error
					break;
					
				case ERR_PRICE_CHANGED:
				case ERR_REQUOTE:
					// Paul Hampton-Smith removed RefreshRates() here and used MarketInfo() above instead
					continue; // we can apparently retry immediately according to MT docs.
					
				default:
					// an apparently serious, unretryable error.
					exit_loop = true;
					break; 
					
			}  // end switch 

			if (cnt > retry_attempts) 
			 	exit_loop = true; 
			 	
			if (!exit_loop) 
			{
				OrderReliablePrint("retryable error (" + cnt + "/" + 
									retry_attempts + "): " + OrderReliableErrTxt(err)); 
				OrderReliable_SleepRandomTime(sleep_time,sleep_maximum); 
			}
			
			if (exit_loop) 
			{
				if (err != ERR_NO_ERROR) 
				{
					OrderReliablePrint("non-retryable error: " + OrderReliableErrTxt(err)); 
				}
				if (cnt > retry_attempts) 
				{
					OrderReliablePrint("retry attempts maxed at " + retry_attempts); 
				}
			}
		}
		
		// we have now exited from loop. 
		if (err == ERR_NO_ERROR) 
		{
			OrderReliablePrint("apparently successful OP_BUY or OP_SELL order placed, details follow.");
			OrderSelect(ticket, SELECT_BY_TICKET, MODE_TRADES); 
			OrderPrint(); 
			return(ticket); // SUCCESS! 
		} 
		OrderReliablePrint("failed to execute OP_BUY/OP_SELL, after " + cnt + " retries");
		OrderReliablePrint("failed trade: " + OrderReliable_CommandString(cmd) + " " + symbol + 
							"@" + price + " tp@" + takeprofit + " sl@" + stoploss); 
		OrderReliablePrint("last error: " + OrderReliableErrTxt(err)); 
		return(-1); 
	}
}
		
	
//=============================================================================
//							 OrderModifyReliable()
//
//	This is intended to be a drop-in replacement for OrderModify() which, 
//	one hopes, is more resistant to various forms of errors prevalent 
//	with MetaTrader.
//			  
//	RETURN VALUE: 
//
//		TRUE if successful, FALSE otherwise
//
//
//	FEATURES:
//
//		 * Re-trying under some error conditions, sleeping a random 
//		   time defined by an exponential probability distribution.
//
//		 * Displays various error messages on the log for debugging.
//
//
//	Matt Kennel, 	2006-05-28
//
//=============================================================================
bool OrderModifyReliable(int ticket, double price, double stoploss, 
						 double takeprofit, datetime expiration, 
						 color arrow_color = CLR_NONE) 
{
	OrderReliable_Fname = "OrderModifyReliable";

	OrderReliablePrint(" attempted modify of #" + ticket + " price:" + price + 
						" sl:" + stoploss + " tp:" + takeprofit); 

	//if (!IsConnected()) 
	//{
	//	OrderReliablePrint("error: IsConnected() == false");
	//	_OR_err = ERR_NO_CONNECTION; 
	//	return(false);
	//}
	
	if (IsStopped()) 
	{
		OrderReliablePrint("error: IsStopped() == true");
		return(false);
	}
	
	int cnt = 0;
	while(!IsTradeAllowed() && cnt < retry_attempts) 
	{
		OrderReliable_SleepRandomTime(sleep_time,sleep_maximum); 
		cnt++;
	}
	if (!IsTradeAllowed()) 
	{
		OrderReliablePrint("error: no operation possible because IsTradeAllowed()==false, even after retries.");
		_OR_err = ERR_TRADE_CONTEXT_BUSY; 
		return(false);  
	}


	
	if (false) {
		 // This section is 'nulled out', because
		 // it would have to involve an 'OrderSelect()' to obtain
		 // the symbol string, and that would change the global context of the
		 // existing OrderSelect, and hence would not be a drop-in replacement
		 // for OrderModify().
		 //
		 // See OrderModifyReliableSymbol() where the user passes in the Symbol 
		 // manually.
		 
		 OrderSelect(ticket,SELECT_BY_TICKET,MODE_TRADES);
		 string symbol = OrderSymbol();
		 int digits = MarketInfo(symbol,MODE_DIGITS);
		 if (digits > 0) {
			 price = NormalizeDouble(price,digits);
			 stoploss = NormalizeDouble(stoploss,digits);
			 takeprofit = NormalizeDouble(takeprofit,digits); 
		 }
		 if (stoploss != 0) OrderReliable_EnsureValidStop(symbol,price,stoploss); 
	}



	int err = GetLastError(); // so we clear the global variable.  
	err = 0; 
	_OR_err = 0; 
	bool exit_loop = false;
	cnt = 0;
	bool result = false;
	
	while (!exit_loop) 
	{
		if (IsTradeAllowed()) 
		{
			result = OrderModify(ticket, price, stoploss, 
								 takeprofit, expiration, arrow_color);
			err = GetLastError();
			_OR_err = err; 
		} 
		else 
			cnt++;

		if (result == true) 
			exit_loop = true;

		switch (err) 
		{
			case ERR_NO_ERROR:
				exit_loop = true;
				break;
				
			case ERR_NO_RESULT:
				// modification without changing a parameter. 
				// if you get this then you may want to change the code.
				exit_loop = true;
				break;
				
			case ERR_SERVER_BUSY:
			case ERR_NO_CONNECTION:
			case ERR_INVALID_PRICE:
			case ERR_OFF_QUOTES:
			case ERR_BROKER_BUSY:
			case ERR_TRADE_CONTEXT_BUSY: 
			case ERR_TRADE_TIMEOUT:		// for modify this is a retryable error, I hope. 
				cnt++; 	// a retryable error
				break;
				
			case ERR_PRICE_CHANGED:
			case ERR_REQUOTE:
				RefreshRates();
				continue; 	// we can apparently retry immediately according to MT docs.
				
			default:
				// an apparently serious, unretryable error.
				exit_loop = true;
				break; 
				
		}  // end switch 

		if (cnt > retry_attempts) 
			exit_loop = true; 
			
		if (!exit_loop) 
		{
			OrderReliablePrint("retryable error (" + cnt + "/" + retry_attempts + 
								"): "  +  OrderReliableErrTxt(err)); 
			OrderReliable_SleepRandomTime(sleep_time,sleep_maximum); 
			RefreshRates(); 
		}
		
		if (exit_loop) 
		{
			if ((err != ERR_NO_ERROR) && (err != ERR_NO_RESULT)) 
				OrderReliablePrint("non-retryable error: "  + OrderReliableErrTxt(err)); 

			if (cnt > retry_attempts) 
				OrderReliablePrint("retry attempts maxed at " + retry_attempts); 
		}
	}  
	
	// we have now exited from loop. 
	if ((result == true) || (err == ERR_NO_ERROR)) 
	{
		OrderReliablePrint("apparently successful modification order, updated trade details follow.");
		OrderSelect(ticket, SELECT_BY_TICKET, MODE_TRADES); 
		OrderPrint(); 
		return(true); // SUCCESS! 
	} 
	
	if (err == ERR_NO_RESULT) 
	{
		OrderReliablePrint("Server reported modify order did not actually change parameters.");
		OrderReliablePrint("redundant modification: "  + ticket + " " + symbol + 
							"@" + price + " tp@" + takeprofit + " sl@" + stoploss); 
		OrderReliablePrint("Suggest modifying code logic to avoid."); 
		return(true);
	}
	
	OrderReliablePrint("failed to execute modify after " + cnt + " retries");
	OrderReliablePrint("failed modification: "  + ticket + " " + symbol + 
						"@" + price + " tp@" + takeprofit + " sl@" + stoploss); 
	OrderReliablePrint("last error: " + OrderReliableErrTxt(err)); 
	
	return(false);  
}
 
 
//=============================================================================
//
//						OrderModifyReliableSymbol()
//
//	This has the same calling sequence as OrderModify() except that the 
//	user must provide the symbol.
//
//	This function will then be able to ensure proper normalization and 
//	stop levels.
//
//=============================================================================
bool OrderModifyReliableSymbol(string symbol, int ticket, double price, 
							   double stoploss, double takeprofit, 
							   datetime expiration, color arrow_color = CLR_NONE) 
{
	int digits = MarketInfo(symbol, MODE_DIGITS);
	
	if (digits > 0) 
	{
		price = NormalizeDouble(price, digits);
		stoploss = NormalizeDouble(stoploss, digits);
		takeprofit = NormalizeDouble(takeprofit, digits); 
	}
	
	if (stoploss != 0) 
		OrderReliable_EnsureValidStop(symbol, price, stoploss); 
		
	return(OrderModifyReliable(ticket, price, stoploss, 
								takeprofit, expiration, arrow_color)); 
	
}
 
 
//=============================================================================
//							 OrderCloseReliable()
//
//	This is intended to be a drop-in replacement for OrderClose() which, 
//	one hopes, is more resistant to various forms of errors prevalent 
//	with MetaTrader.
//			  
//	RETURN VALUE: 
//
//		TRUE if successful, FALSE otherwise
//
//
//	FEATURES:
//
//		 * Re-trying under some error conditions, sleeping a random 
//		   time defined by an exponential probability distribution.
//
//		 * Displays various error messages on the log for debugging.
//
//
//	Derk Wehler, ashwoods155@yahoo.com  	2006-07-19
//
//=============================================================================
bool OrderCloseReliable(int ticket, double lots, double price, 
						int slippage, color arrow_color = CLR_NONE) 
{
	int nOrderType;
	string strSymbol;
	OrderReliable_Fname = "OrderCloseReliable";
	
	OrderReliablePrint(" attempted close of #" + ticket + " price:" + price + 
						" lots:" + lots + " slippage:" + slippage); 

// collect details of order so that we can use GetMarketInfo later if needed
	if (!OrderSelect(ticket,SELECT_BY_TICKET))
	{
		_OR_err = GetLastError();		
		OrderReliablePrint("error: " + ErrorDescription(_OR_err));
		return(false);
	}
	else
	{
		nOrderType = OrderType();
		strSymbol = OrderSymbol();
	}

	if (nOrderType != OP_BUY && nOrderType != OP_SELL)
	{
		_OR_err = ERR_INVALID_TICKET;
		OrderReliablePrint("error: trying to close ticket #" + ticket + ", which is " + OrderReliable_CommandString(nOrderType) + ", not OP_BUY or OP_SELL");
		return(false);
	}

	//if (!IsConnected()) 
	//{
	//	OrderReliablePrint("error: IsConnected() == false");
	//	_OR_err = ERR_NO_CONNECTION; 
	//	return(false);
	//}
	
	if (IsStopped()) 
	{
		OrderReliablePrint("error: IsStopped() == true");
		return(false);
	}

	
	int cnt = 0;
/*	
	Commented out by Paul Hampton-Smith due to a bug in MT4 that sometimes incorrectly returns IsTradeAllowed() = false
	while(!IsTradeAllowed() && cnt < retry_attempts) 
	{
		OrderReliable_SleepRandomTime(sleep_time,sleep_maximum); 
		cnt++;
	}
	if (!IsTradeAllowed()) 
	{
		OrderReliablePrint("error: no operation possible because IsTradeAllowed()==false, even after retries.");
		_OR_err = ERR_TRADE_CONTEXT_BUSY; 
		return(false);  
	}
*/

	int err = GetLastError(); // so we clear the global variable.  
	err = 0; 
	_OR_err = 0; 
	bool exit_loop = false;
	cnt = 0;
	bool result = false;
	
	while (!exit_loop) 
	{
		if (IsTradeAllowed()) 
		{
			result = OrderClose(ticket, lots, price, slippage, arrow_color);
			err = GetLastError();
			_OR_err = err; 
		} 
		else 
			cnt++;

		if (result == true) 
			exit_loop = true;

		switch (err) 
		{
			case ERR_NO_ERROR:
				exit_loop = true;
				break;
				
			case ERR_SERVER_BUSY:
			case ERR_NO_CONNECTION:
			case ERR_INVALID_PRICE:
			case ERR_OFF_QUOTES:
			case ERR_BROKER_BUSY:
			case ERR_TRADE_CONTEXT_BUSY: 
			case ERR_TRADE_TIMEOUT:		// for modify this is a retryable error, I hope. 
				cnt++; 	// a retryable error
				break;
				
			case ERR_PRICE_CHANGED:
			case ERR_REQUOTE:
				continue; 	// we can apparently retry immediately according to MT docs.
				
			default:
				// an apparently serious, unretryable error.
				exit_loop = true;
				break; 
				
		}  // end switch 

		if (cnt > retry_attempts) 
			exit_loop = true; 
			
		if (!exit_loop) 
		{
			OrderReliablePrint("retryable error (" + cnt + "/" + retry_attempts + 
								"): "  +  OrderReliableErrTxt(err)); 
			OrderReliable_SleepRandomTime(sleep_time,sleep_maximum); 
			// Added by Paul Hampton-Smith to ensure that price is updated for each retry
			if (nOrderType == OP_BUY)  price = NormalizeDouble(MarketInfo(strSymbol,MODE_BID),MarketInfo(strSymbol,MODE_DIGITS));
			if (nOrderType == OP_SELL) price = NormalizeDouble(MarketInfo(strSymbol,MODE_ASK),MarketInfo(strSymbol,MODE_DIGITS));
		}
		
		if (exit_loop) 
		{
			if ((err != ERR_NO_ERROR) && (err != ERR_NO_RESULT)) 
				OrderReliablePrint("non-retryable error: "  + OrderReliableErrTxt(err)); 

			if (cnt > retry_attempts) 
				OrderReliablePrint("retry attempts maxed at " + retry_attempts); 
		}
	}  
	
	// we have now exited from loop. 
	if ((result == true) || (err == ERR_NO_ERROR)) 
	{
		OrderReliablePrint("apparently successful close order, updated trade details follow.");
		OrderSelect(ticket, SELECT_BY_TICKET, MODE_TRADES); 
		OrderPrint(); 
		return(true); // SUCCESS! 
	} 
	
	OrderReliablePrint("failed to execute close after " + cnt + " retries");
	OrderReliablePrint("failed close: Ticket #" + ticket + ", Price: " + 
						price + ", Slippage: " + slippage); 
	OrderReliablePrint("last error: " + OrderReliableErrTxt(err)); 
	
	return(false);  
}
 
 

//=============================================================================
//=============================================================================
//								Utility Functions
//=============================================================================
//=============================================================================



int OrderReliableLastErr() 
{
	return (_OR_err); 
}


string OrderReliableErrTxt(int err) 
{
	return ("" + err + ":" + ErrorDescription(err)); 
}


void OrderReliablePrint(string s) 
{
	// Print to log prepended with stuff;
	if (!(IsTesting() || IsOptimization())) Print(OrderReliable_Fname + " " + OrderReliableVersion + ":" + s);
}


string OrderReliable_CommandString(int cmd) 
{
	if (cmd == OP_BUY) 
		return("OP_BUY");

	if (cmd == OP_SELL) 
		return("OP_SELL");

	if (cmd == OP_BUYSTOP) 
		return("OP_BUYSTOP");

	if (cmd == OP_SELLSTOP) 
		return("OP_SELLSTOP");

	if (cmd == OP_BUYLIMIT) 
		return("OP_BUYLIMIT");

	if (cmd == OP_SELLLIMIT) 
		return("OP_SELLLIMIT");

	return("(CMD==" + cmd + ")"); 
}


//=============================================================================
//
//						 OrderReliable_EnsureValidStop()
//
// 	Adjust stop loss so that it is legal.
//
//	Matt Kennel 
//
//=============================================================================
void OrderReliable_EnsureValidStop(string symbol, double price, double& sl) 
{
	// Return if no S/L
	if (sl == 0) 
		return;
	
	double servers_min_stop = MarketInfo(symbol, MODE_STOPLEVEL) * MarketInfo(symbol, MODE_POINT); 
	
	if (MathAbs(price - sl) <= servers_min_stop) 
	{
		// we have to adjust the stop.
		if (price > sl)
			sl = price - servers_min_stop;	// we are long
			
		else if (price < sl)
			sl = price + servers_min_stop;	// we are short
			
		else
			OrderReliablePrint("EnsureValidStop: error, passed in price == sl, cannot adjust"); 
			
		sl = NormalizeDouble(sl, MarketInfo(symbol, MODE_DIGITS)); 
	}
}


//=============================================================================
//
//						 OrderReliable_SleepRandomTime()
//
//	This sleeps a random amount of time defined by an exponential 
//	probability distribution. The mean time, in Seconds is given 
//	in 'mean_time'.
//
//	This is the back-off strategy used by Ethernet.  This will 
//	quantize in tenths of seconds, so don't call this with a too 
//	small a number.  This returns immediately if we are backtesting
//	and does not sleep.
//
//	Matt Kennel mbkennelfx@gmail.com.
//
//=============================================================================
void OrderReliable_SleepRandomTime(double mean_time, double max_time) 
{
	if (IsTesting()) 
		return; 	// return immediately if backtesting.

	double tenths = MathCeil(mean_time / 0.1);
	if (tenths <= 0) 
		return; 
	 
	int maxtenths = MathRound(max_time/0.1); 
	double p = 1.0 - 1.0 / tenths; 
	  
	Sleep(100); 	// one tenth of a second PREVIOUS VERSIONS WERE STUPID HERE. 
	
	for(int i=0; i < maxtenths; i++)  
	{
		if (MathRand() > p*32768) 
			break; 
			
		// MathRand() returns in 0..32767
		Sleep(100); 
	}
}  


