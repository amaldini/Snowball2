PUSHD "c:\Program Files (x86)\OANDA - MetaTrader\experts\MT4CommunicationLibrary"
xcopy MT4Library.dll ..\Libraries /Y
xcopy ..\*.* "C:\Program Files (x86)\OANDA - MetaTrader - Secondary\experts" /S /Y
POPD