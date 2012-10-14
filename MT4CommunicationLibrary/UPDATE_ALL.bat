PUSHD "C:\Programmi\OANDA - MetaTrader\experts\MT4CommunicationLibrary"
xcopy MT4Library.dll ..\Libraries /Y
xcopy ..\*.* "C:\Programmi\OANDA - MetaTrader - Secondary\experts" /S /Y
POPD