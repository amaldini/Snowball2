#include <common_functions.mqh>

double pointsPerPip = 0;
double pip = 0;

double ACCOUNT_EURO() {

   if (AccountCurrency()=="EUR") {
      return (AccountBalance());
   } else {
      return (0);
   }
}

void calculatePointsPerPip() {
   pointsPerPip = pointsPerPip();
   pip = Point*pointsPerPip;
}

double calculateLotSize(double oOpenPrice,double oStopLoss,double riskInEUR) {

   double toDestCurrency;
   double PointValue;
   double pipValueInDollars;

   double eu_ask = MarketInfo("EURUSD",MODE_ASK); 
   double eu_bid = MarketInfo("EURUSD",MODE_BID);
   double EURUSD = (eu_ask + eu_bid) / 2;

   double lotSize = MarketInfo(Symbol6(),MODE_LOTSIZE);
   double TradeSize;

   if (pointsPerPip==0) {
      calculatePointsPerPip();
   }

   double StopPips = MathAbs(oOpenPrice-oStopLoss)/pip;

   double riskInDollars = riskInEUR * EURUSD;   
   pipValueInDollars = riskInDollars / StopPips;

   /*
   maldaLog("lotSize:"+lotSize);
   maldaLog("pip:"+pip);
   maldaLog("tradeSize(lots):"+TradeSize);
   */
   double currentQuote = ((Bid+Ask)/2);

   // COPPIE xxxUSD
   if (StringSubstr(Symbol6(),3,3)=="USD") {   
      TradeSize = pipValueInDollars / (lotSize * pip);   
      // maldaLog("lotSize*pip*TradeSize="+lotSize+"*"+pip+"*"+TradeSize);         
      // COPPIE USDxxx
   } else if (StringSubstr(Symbol6(),0,3)=="USD") {
      TradeSize = pipValueInDollars * currentQuote /  (lotSize * pip) ; 
   } else { // COPPIE xxxyyy
      string baseCurr = StringSubstr(Symbol6(),0,3)+"USD";
      double baseQuote= (MarketInfo(baseCurr,MODE_ASK)+MarketInfo(baseCurr,MODE_BID))/2; 
      // maldaLog("baseQuote:"+baseQuote);
      TradeSize = pipValueInDollars * currentQuote / (lotSize * pip * baseQuote );  
   }

   // maldaLog("pipValueInDollars:"+pipValueInDollars);
   TradeSize = MathFloor(TradeSize*100)/100;
   return (TradeSize);
}