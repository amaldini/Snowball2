


double ATRdiv2 = 0;

double calcOrderDistance(int danglers,int openTrades) {
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
   	bool initialOrdersDone = (openTrades>0);
      if (!initialOrdersDone) {
         res = GRID_STEP / 2 * pip;
         initialOrdersDone = true;
      } else {
         if (isBurstGrid) {
            res = 3* GRID_STEP*pip * (1+danglers);
         } else {
            res =  ATRdiv3 * (1+danglers);
         }
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
   }
}

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