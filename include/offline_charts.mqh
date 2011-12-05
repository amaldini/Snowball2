//+------------------------------------------------------------------+
//|                                               offline_charts.mq4 |
//|                                                     Bernd Kreuss |
//|                                              Version 2010.9.12.1 |
//|                 paypal-donations go here -> mailto:7ibt@arcor.de |
//+------------------------------------------------------------------+
#property copyright "Bernd Kreuss"
#property link      "http://sites.google.com/site/prof7bit/"

/** @file
* This file contains functions, needed to handle offline charts,
* the latest version of this file is available at 
* http://sites.google.com/site/prof7bit/
*
* You can create or update offline charts in real time and also refresh
* the chart window associated with such an offline chart automatically, 
*
* The main purpose of this library is to be able to produce
* equity curves resulting from traded strategies in real time, 
* equity curves that would contain every drawdown that occured
* during the trades, not only closed profits. This is especially
* useful when used while backtesting an EA, unlike the built-in
* backtester equity plotter this one will record everything that
* happens while the positions are open and draw a much more 
* realistic picture.
*
* To use the equity plotter feature simply include the .mqh file in 
* your expert and then on every tick call the function recordEquity()
* For example if you have an EA with the name "foobazer" and want to
* record it's performance in an M15 chart you would issue the following
* call on every tick: 
* 
*   recordEquity("foobazer", PERIOD_M15, magic_number)
*
* 
* !!! Use a different name for every chart the EA runs on !!!
* The period has nothing to do with the period the EA runs on, it is
* just meant to tell the function which timeframe the equity chart should have
* and can be every period you want. In the above example It will create and 
* continually update an offline M15 chart with the name "foobazer" containing 
* the performance of your EA in real time from this moment on. If you run your 
* EA on backtester then an underscore will be prepended to the name of the chart,
* so it won't overwrite your live chart.
* 
* Names can only contain up to 12 characters. Make sure every EA on every 
* chart will use a DIFFERENT NAME when calling this function or they will 
* all write to the same chart and produce a complete mess.
*/

#include <WinUser32.mqh>

#define OFFLINE_HEADER_SIZE 148 ///< LONG_SIZE + 64 + 12 + 4 * LONG_SIZE + 13 * LONG_SIZE 
#define OFFLINE_RECORD_SIZE 44  ///< 5 * DOUBLE_SIZE + LONG_SIZE 

int __chart_file = 0; ///< the cache for the file handle (only used in backtesting mode) 

/**
* Record the equity curve for the specified filter critera into an offline chart.
* Call this function on every tick. It will produce a chart that will 
* include every high and low of the total floating and realized profits.
* 
* You can filter by magic number and/or by the comment field.
* If magic is -1 then all magic numbers are allowed, if it is 0 then 
* only manually opened trades are counted, if it is any other
* value then only trades with this particular number are counted. 
* The second filter is comment, if it is "" then it is not filtered
* by comment, else only trades with this exact comment string are
* counted.
* 
* Offset is used to make sure the chart always is in positive terrotory.
* Since metatrader won't display charts with negative values and we are
* only summing up an individual strategie's profit (or loss!), not total 
* equity, we need some imaginary positive starting capital for each chart.
*/
void recordEquity(string name, int period, int magic=-1, string comment="", double offset=5000){
   double equity;
   
   // don't do anything during optimization runs
   if (IsOptimization()){
      return(0);
   }
   
   // This can happen shortly after a restart of metatrader. The order history
   // is still empty. We do nothing in this case and wait for the next tick.
   if (OrdersHistoryTotal() == 0){
      return(0);
   }

   if (magic == -1 && comment == ""){
      // If there is no filter we can simply use AccountEquity(), also we
      // don't need a virtual starting balance in this case. 
      equity = AccountEquity();
   }else{
      // Otherwise calculate the partial profits and add 'offset' 
      // as virtual starting balance.
      equity = getAllProfitFiltered(magic, comment) + offset;
   }
      
   // when run in the strategy tester we add a _ to the chart name
   // so it wont interfere with the same chart in live trading
   if (IsTesting()){
      name = "_" + name;
   }
   
   // write it into the chart.
   updateOfflineChart(name, period, 2, equity, 0); 
}

/**
* Update the offline chart with a new price. 
* This function will find the last bar in the offline chart file 
* (create the chart if necessary) update the last bar (adjust the close, 
* add to the volume and extend high or low if necessary) or start a new bar 
* if current time is beyond the lifetime of the last bar in the chart.
* Note: if you want to make Renko or other range based charts you will need to
* write your own function similar to this but with a different algorithm to
* detect when a new bar must be started. This one is strictly time based.
*/ 
void updateOfflineChart(string symbol, int period, int digits, double price, double volume){
   double o,h,l,c,v;
   int t;
   int time_current = iTime(NULL, period, 0); // FIXME! the starting time for the period's current bar
   
   // create the chart if it doesn't already exist
   // or just update the header
   writeOfflineHeader(symbol, period, digits);
   
   // read the last bar in the chart (if any)
   if (!readOfflineBar(symbol, period, 1, t, o, h, l, c, v)){
      // no bars in chart yet, so just make one
      writeOfflineBar(symbol, period, 0, time_current, price, price, price, price, volume);
      return(0);
   }
   
   if (t > time_current){
      // this is a very special case: the last bar in the chart is
      // NEWER that the bar we just want to record. This can only
      // happen if we backtest and there is already a chart left
      // from a previous backtest. In this case the only reasonable
      // thing we would want to do is completely empty the chart and
      // start again.
      if (IsTesting()){
         // ONLY empty the chart if we REALLY are in the baktester, 
         // else we simply IGNORE it completely instead of accidently 
         // destroying a whole and possibly months old chart just 
         // because of one bad timestamp.
         emptyOfflineChart(symbol, period, digits);   
         writeOfflineBar(symbol, period, 0, time_current, price, price, price, price, volume);
      }
      return(0);
   }
   
   if (t == time_current){
      // the bar has the current time, so update it
      if (price > h){
         h = price;
      }
      if (price < l){
         l = price;
      }
      c = price;
      v += volume;
      writeOfflineBar(symbol, period, 1, t, o, h, l, c, v);
   }else{
      // last bar is old, start a new one
      writeOfflineBar(symbol, period, 0, time_current, price, price, price, price, volume);
   }  
}

/**
* empty the chart, write a fresh header
*/
void emptyOfflineChart(string symbol, int period, int digits){
   // close it first (if we are in the backtester and the file is kept open)
   forceFileClose();
      
   // open (and immediately close) the file in write only mode, 
   // this will truncate it to zero length, after that we write a fresh header
   FileClose(FileOpenHistory(offlineFileName(symbol, period), FILE_WRITE | FILE_BIN));
   writeOfflineHeader(symbol, period, digits);
}

/**
* write or update the header of an offline chart file,
* if the file does not yet exist create the file.
*/
void writeOfflineHeader(string symbol, int period, int digits){
   int    version = 400;
   string c_copyright = "(C)opyright 2009-2010, Bernd Kreuss";
   int    i_unused[13];
   
   int F = fileOpenEx(offlineFileName(symbol, period), FILE_BIN | FILE_READ | FILE_WRITE);
   FileSeek(F, 0, SEEK_SET);
   FileWriteInteger(F, version, LONG_VALUE);
   FileWriteString(F, c_copyright, 64);
   FileWriteString(F, symbol, 12);
   FileWriteInteger(F, period, LONG_VALUE);
   FileWriteInteger(F, digits, LONG_VALUE);
   FileWriteInteger(F, 0, LONG_VALUE);       //timesign
   FileWriteInteger(F, 0, LONG_VALUE);       //last_sync
   FileWriteArray(F, i_unused, 0, 13);

   fileCloseEx(F);
}

/**
* Write (or update) one bar in the offline chart file
* and refresh the chart window if it is currently open.
* The parameter bars_back is the offset counted from the end of
* the file: 0 means append a new bar, 1 means update the last bar
* 2 would be the second last bar and so on.
* The parameter time is the POSIX-Timestamp representing the 
* beginning of that bar. It is the same value that would be 
* returned from iTime() or Time[], namely the seconds that
* have passed since the UNIX-Epoch (00:00 a.m. of 1 January, 1970)
*/
void writeOfflineBar(string symbol, int period, int bars_back, int time, double open, double high, double low, double close, double volume){
   int F = fileOpenEx(offlineFileName(symbol, period), FILE_BIN | FILE_READ | FILE_WRITE);
   
   int position = bars_back * OFFLINE_RECORD_SIZE;   
   FileSeek(F, -position, SEEK_END);

   if (FileTell(F) >= OFFLINE_HEADER_SIZE){
      FileWriteInteger(F, time, LONG_VALUE); 
      FileWriteDouble(F, open, DOUBLE_VALUE);
      FileWriteDouble(F, low, DOUBLE_VALUE);
      FileWriteDouble(F, high, DOUBLE_VALUE);
      FileWriteDouble(F, close, DOUBLE_VALUE);
      FileWriteDouble(F, volume, DOUBLE_VALUE);
   
      // refresh the chart window
      // this won't work in backtesting mode
      // and also don't do it while deinitializing or the
      // WindowHandle() function will run into a deadlock
      // for unknown reasons. (this took me a while to debug)
      if (!IsStopped() && !IsTesting()){
         int hwnd=WindowHandle(symbol, period);
         if (hwnd != 0){
            PostMessageA(hwnd, WM_COMMAND, 33324, 0);
         }
      }
   }
   fileCloseEx(F);
}

/**
* Read one bar out of the offline chart file and fill the
* "by reference"-parameters that were passed to the function.
* The function returns True if successful or False otherwise.
* The parameter bars_back is the offset counting from the end
* of the file: 0 makes no sense since it would be past the end,
* 1 means read the last bar in the file, 2 the second last, etc.
* If bars_back would point outside the file (beginning or end)
* the function will return False and do nothing, otherwise
* the read values will be filled into the supplied parameters
* and the function will return True
*/ 
bool readOfflineBar(string symbol, int period, int bars_back, int& time, double& open, double& high, double& low, double& close, double& volume){
   int F = fileOpenEx(offlineFileName(symbol, period), FILE_BIN | FILE_READ | FILE_WRITE);
   
   int position = bars_back * OFFLINE_RECORD_SIZE;
   FileSeek(F, -position, SEEK_END);
   
   if (FileSize(F) - FileTell(F) >= OFFLINE_RECORD_SIZE && FileTell(F) >= OFFLINE_HEADER_SIZE){
      time = FileReadInteger(F, LONG_VALUE); 
      open = FileReadDouble(F, DOUBLE_VALUE);
      low = FileReadDouble(F, DOUBLE_VALUE);
      high = FileReadDouble(F, DOUBLE_VALUE);
      close = FileReadDouble(F, DOUBLE_VALUE);
      volume = FileReadDouble(F, DOUBLE_VALUE);
      fileCloseEx(F);
      return(True);
   }else{
      fileCloseEx(F);
      return(False);
   }
}

/**
* construct the file name for the chart file, truncate the 
* symbol name to the maximum of 12 allowed characters.
*/
string offlineFileName(string symbol, int period){
   return(StringSubstr(symbol, 0, 12) + period + ".hst");
}

/**
* loop through all trades (historic and currently open) and
* sum up all profits (including swap and commission).
*/
double getAllProfitFiltered(int magic=-1, string comment=""){
   int cnt, total;
   double floating = 0;
   double realized = 0;
   static int last_closed_ticket = 0;
   string cache_name; 
   
   // we need a unique name under which to cache the realized P&L later
   if (IsTesting()){
      cache_name = "profit_cache@@" + magic + "@" + comment;
   }else{
      cache_name = "profit_cache@" + magic + "@" + comment;
   }
   
   // sum up the floating
   total=OrdersTotal();
   for(cnt=0; cnt<total; cnt++){
      OrderSelect(cnt, SELECT_BY_POS, MODE_TRADES);
      if ((magic == -1 || OrderMagicNumber() == magic) 
       && (comment == "" || StringFind(OrderComment(), comment, 0) != -1)
      ){
         floating += OrderProfit() + OrderSwap() + OrderCommission();
      }
   }
   
   // Now calculate the total realized profit.
   // We first check if the order history has changed since 
   // the last tick by looking at the newest ticket number.
   // If there was no change then we can assume that no trade
   // has been closed and we can simply use the cached value
   // of the previously calculated realized profit.
   total=OrdersHistoryTotal();
   OrderSelect(total-1, SELECT_BY_POS, MODE_HISTORY);
   if (last_closed_ticket != OrderTicket()){
   
      // history is different from last time, so we must do 
      // the expensive loop and sum up all realized profit
      last_closed_ticket = OrderTicket();
      realized = 0;
      for(cnt=0; cnt<total; cnt++){
         OrderSelect(cnt, SELECT_BY_POS, MODE_HISTORY);
         if ((magic == -1 || OrderMagicNumber() == magic) 
          && (comment == "" ||  StringFind(OrderComment(), comment, 0) != -1)
         ){
            realized += OrderProfit() + OrderSwap() + OrderCommission();
         }
      }
      // remember it for the next call.
      // We need to store it separately for every possible filter.
      // We dont have hash tables in mql4, so we must abuse 
      // the global variables function to store name-value pairs.
      GlobalVariableSet(cache_name, realized);      
   }else{
   
      // history not changed. retrieve the cached value.
      realized = GlobalVariableGet(cache_name);
   }
   
   return (floating + realized);
}

/**
* Open the chart file. In testing mode this will open the file
* only when called for the first time and cache the file handle
* for subsequent calls to speed up things. The corresponding
* fileCloseEx() function will do nothing when in testing mode.
*/
int fileOpenEx(string name, int mode){
   if (IsTesting()){
      if (__chart_file == 0){
         __chart_file = FileOpenHistory(name, mode);
      }
      return(__chart_file);
   }else{
      return(FileOpenHistory(name, mode));
   }
}

/**
* close the file. Keep the file open when in teting mode.
*/
void fileCloseEx(int file){
   if (!IsTesting()){
      FileClose(file);
   }else{
      //FileFlush(file);
   }
}

/**
* enforce closing of the file (in backtesting mode when it is held open)
*/ 
void forceFileClose(){
   if(__chart_file != 0){
      FileClose(__chart_file);
      __chart_file = 0;
   }
}