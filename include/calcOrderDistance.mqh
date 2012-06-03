


double ATRdiv2 = 0;
bool initialOrdersDone = false;

double calcOrderDistance(int danglers) {
   double ATR = iATR(NULL, PERIOD_D1,14,1);
   double ATRdiv3 = ATR / 3;
   double res;
   ATRdiv2 = ATR / 2;
   if (isGrid) {
      maldaLog("ATR="+
         DoubleToStr(ATR,Digits)+" ATR/3="+
         DoubleToStr((ATR/3)/pip,2)+" pips"
      );
      // res = ATRdiv3;
      res = 0;
   } else {
      if (!initialOrdersDone) {
         res = GRID_STEP / 2 * pip;
         initialOrdersDone = true;
      } else {
         res =  ATRdiv3 * (1+danglers);
         maldaLog("ATR="+
            DoubleToStr(ATR,Digits)+" ATR/3="+
            DoubleToStr((ATR/3)/pip,2)+" pips"+
            " ATR/3*(1+"+danglers+")="+DoubleToStr(res/pip,2)+" pips"
         );
      }
   }
   return (res);
}

void ExitConditions(int isMaster) {
   if (getCloseOpenTrades(Symbol6(),isMaster)) {
      closeOpenOrders(OP_BUY,magic,"command issued by controlpanel");
      closeOpenOrders(OP_SELL,magic,"command issued by controlpanel");
      setCloseOpenTrades(Symbol6(),isMaster,0);
      initialOrdersDone = false;
   }
}