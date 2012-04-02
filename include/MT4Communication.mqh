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



