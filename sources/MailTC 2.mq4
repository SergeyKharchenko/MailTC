//+------------------------------------------------------------------+
//|                                                     MailTC 2.mq4 |
//|                           Copyright © 2013, AirBionicFX Software |
//|                                           http://airbionicfx.com |
//+------------------------------------------------------------------+
#property copyright "Copyright © 2013, AirBionicFX Software"
#property link      "http://airbionicfx.com"

#import "MailTC.dll"
   
   int Initialize(int hWnd, string login, string password, string recordId, string keySubject, double hoursToClose);
   void Deinitialize(int hWnd);
   
   int LoadAllOrders(int hWnd, string recordId, int &tickets[], int &openDates[]);   
   
   int GetReadyOrders(int hWnd, 
                      string &orderSymbols[], 
                      int &orderTypes[], 
                      double &orderOpenPrice[], 
                      double &orderStopLoss[], 
                      double &orderTakeProfit[],
                      int &closeTimes[],
                      int &hashCodes[],
                      int brokerTime);   
                      
   void AddOrder(int hWnd, string recordId, int ticket, int closeDate, int hashCode);
   void RemoveOrder(int hWnd, int hashCode);      
   void RemoveOrderFromFile(int hWnd, string recordId, int ticket);       
   
   void DllSleep(int milliseconds);                                 
     
#import

#include <stderror.mqh>
#include <stdlib.mqh>
#include <WinUser32.mqh>

//--- input parameters

extern string    Login         = "example@gmail.com";
extern string    Password      = "password";
extern string    LetterSubjectKey = "Новый сигнал";
extern double    Lot           = 1;

extern double    HoursForOrderClose = 4;

extern int       MagicNumber   = 42;
extern int       Slippage      = 5;


int
   ticket,
   hWnd,
   validTickets[],
   closeOrderTimes[],
   lastHashCode;

double
   lot,
   sl,
   tp,
   bidsOnPriviousTicks[],
   asksOnPriviousTicks[];
   
bool
   work;
   
string 
   recordId,
   symbols[];      

//+------------------------------------------------------------------+
//| expert initialization function                                   |
//+------------------------------------------------------------------+
int init()
{
   Comment("");
   work = true;
   // --> Check inputs   
   if (Lot <= 0) 
      ShowCriticalAlertAndStop("Lot is invalid");
      
   if (MagicNumber < 0) 
      ShowCriticalAlertAndStop("MagicNumber is invalid");
      
   if (Slippage < 0) 
      ShowCriticalAlertAndStop("Slippage is invalid");                 
      
   if (HoursForOrderClose < 1) 
      ShowCriticalAlertAndStop("HoursForOrderClose is invalid");         
   // <--     
   
   hWnd = WindowHandle(Symbol(), Period());
   recordId = TerminalName() + "_" + WindowExpertName() + "_" + MagicNumber;   
   int result = Initialize(hWnd, Login, Password, recordId, LetterSubjectKey, HoursForOrderClose);
   if (result == 1)
      ShowCriticalAlertAndStop("EA has already attached");   
   if (result == 2)
      ShowCriticalAlertAndStop("Invalid login or password");         
   
   if (work)
   {
      lot = NormalizeLots(Lot, Symbol());
  
      ticket = -1;
      SymbolsList(symbols);
      
      ArrayResize(bidsOnPriviousTicks, ArraySize(symbols));
      ArrayResize(asksOnPriviousTicks, ArraySize(symbols));
      FillPriviousTicksArrays();
      
      if ((Digits == 3) || (Digits == 5))
      {
         Slippage *= 10;
      }
   }
   
   CheckObsoleteOrders();   
}

void ShowCriticalAlertAndStop(string alertText)
{
   Alert(alertText);
   work = false;
}

void FillPriviousTicksArrays()
{
   for (int i = 0; i < ArraySize(symbols); i++)
   {
      bidsOnPriviousTicks[i] = MarketInfo(symbols[i], MODE_BID);
      asksOnPriviousTicks[i] = MarketInfo(symbols[i], MODE_ASK);
   }
}

int GetSymbolIndex(string symbol)
{
   for (int i = 0; i < ArraySize(symbols); i++)
   {
      if (symbol == symbols[i])
         return (i);
   }
   return (-1);
}

void CheckObsoleteOrders()
{
   int arraySize = 100;
   int tickets[];
   int openDates[];
   ArrayResize(tickets, arraySize);
   ArrayResize(openDates, arraySize);  
   
   ArrayResize(validTickets, 0); 
   ArrayResize(closeOrderTimes, 0);
   
   int count = LoadAllOrders(hWnd, recordId, tickets, openDates); 
   for (int i = 0; i < count; i++)
   {
      if (!OrderSelect(tickets[i], SELECT_BY_TICKET) || (CheckOpen(tickets[i]) != 1))
      {
         RemoveOrderFromFile(hWnd, recordId, tickets[i]);   
         continue;  
      }   
      
      int closeTime = openDates[i];
      if (TimeCurrent() >= closeTime)
      {
         if (TryClose(tickets[i]))
         {
            RemoveOrderFromFile(hWnd, recordId, tickets[i]);
            continue;
         }
      }            
      AddValidOrder(tickets[i], closeTime);
   }
}  


//+------------------------------------------------------------------+
//| expert deinitialization function                                 |
//+------------------------------------------------------------------+
int deinit()
{
//----
   Deinitialize(hWnd);
//----
   return(0);
}

//+----------------------------------------------------------------------------------------------+
//| expert start function                                            |
//+----------------------------------------------------------------------------------------------+
int start()
{
//----
   if (!IsExpertEnabled()) 
      ShowCriticalAlertAndStop("Expert advisors are disabled for running");

   if (!work) 
   {
      Comment("Reload EA with correct parameters.");
      return;
   }   
   
   CheckOrdersForCloseTime();
   CheckSellOrdersForCloseByBid();
   
   int arraySize = 100;
   string orderSymbols[];
   int orderTypes[];
   double orderOpenPrice[];
   double orderStopLoss[];
   double orderTakeProfit[];   
   int closeTimes[];
   int hashCodes[];
   
   ArrayResize(orderSymbols, arraySize);
   ArrayResize(orderTypes, arraySize);     
   ArrayResize(orderOpenPrice, arraySize);  
   ArrayResize(orderStopLoss, arraySize);  
   ArrayResize(orderTakeProfit, arraySize);  
   ArrayResize(closeTimes, arraySize);  
   ArrayResize(hashCodes, arraySize);  
   
   for (int i = 0; i < arraySize; i++) 
   {
      orderSymbols[i] = "qwertyqwertyqwertyqwertyqwertyqwerty"+  i;
   }     
      
   int timeCurrent = TimeCurrent();   
      
   int count = GetReadyOrders(hWnd, orderSymbols, orderTypes, orderOpenPrice, orderStopLoss, orderTakeProfit, closeTimes, hashCodes, timeCurrent); 
      
   string commentStr = "";
   for (i = 0; i < count; i++)
   {         
      if (!ContainsSymbol(orderSymbols[i]))
         continue;
         
      if (closeTimes[i] <= TimeCurrent())   
      {
         RemoveOrder(hWnd, hashCodes[i]);
         continue;         
      }
         
      double price = NormalizeDouble(orderOpenPrice[i], MarketInfo(orderSymbols[i], MODE_DIGITS)); 
      sl = NormalizeDouble(orderStopLoss[i], MarketInfo(orderSymbols[i], MODE_DIGITS));
      tp = NormalizeDouble(orderTakeProfit[i], MarketInfo(orderSymbols[i], MODE_DIGITS)); 
         
      double 
         ask = MarketInfo(orderSymbols[i], MODE_ASK),
         bid = MarketInfo(orderSymbols[i], MODE_BID);         
             
      bool opened = false;   
      double bidOnPriviousTick = bidsOnPriviousTicks[GetSymbolIndex(orderSymbols[i])];           
      switch (orderTypes[i])
      {
         case OP_BUY:   
            if ((bid == price) 
                || (((bidOnPriviousTick < price) && (bid >= price)) 
                    || ((bidOnPriviousTick > price) && (bid <= price))))
            {                  
               ticket = OpenOrder(orderSymbols[i], OP_BUY, lot, ask, sl, tp, Slippage, NULL, MagicNumber, 10, 0, Blue);
               opened = true;                 
            }        
            break;
         case OP_SELL:
            tp += MarketInfo(orderSymbols[i], MODE_SPREAD) * MarketInfo(orderSymbols[i], MODE_POINT);
            if ((bid == price) 
                || (((bidOnPriviousTick < price) && (bid >= price)) 
                    || ((bidOnPriviousTick > price) && (bid <= price))))
            {               
               ticket = OpenOrder(orderSymbols[i], OP_SELL, lot, bid, sl, tp, Slippage, NULL, MagicNumber, 10, 0, Red);   
               opened = true;              
            }          
           break;                        
      }
      
      if (opened)
      {
         if (IsNeedToDisplayError(ticket))
         {
            if (lastHashCode != hashCodes[count - 1])
            {
               DisplayError(ticket);
            }   
            continue; 
         }
         AddValidOrder(ticket, closeTimes[i]);
         AddOrder(hWnd, recordId, ticket, closeTimes[i], hashCodes[i]);       
      }   
      else
      {
         if (orderTypes[i] == 0)
            commentStr = commentStr + "Buy ";
         if (orderTypes[i] == 1)
            commentStr = commentStr + "Sell ";
                                 
         commentStr = commentStr + "Symbol: " + orderSymbols[i]
                                 + " open price: " + DoubleToStr(price, MarketInfo(orderSymbols[i], MODE_DIGITS)) 
                                 + " stop loss: " + DoubleToStr(sl, MarketInfo(orderSymbols[i], MODE_DIGITS))
                                 + " take profit: " + DoubleToStr(tp, MarketInfo(orderSymbols[i], MODE_DIGITS)) 
                                 + " close time: " + TimeToStr(closeTimes[i]) + "\r\n";
      }                           
   }      
   
   FillPriviousTicksArrays();
   ShowOrderComments(commentStr);
//----
   return(0);
}
//+----------------------------------------------------------------------------------------------+

//+----------------------------------------------------------------------------------------------+
void ShowOrderComments(string commentStr)
{
   commentStr = commentStr + "--------------------------------------------------------------------\r\n";
   for (int i = 0; i < ArraySize(validTickets); i++)
   {
      if (OrderSelect(validTickets[i], SELECT_BY_TICKET))
      {
         int minutesToClose = (closeOrderTimes[i] - TimeCurrent()) / 60;
         commentStr = commentStr + "Ticket: " + OrderTicket() + " " + OrderSymbol() + " close time: " + TimeToStr(closeOrderTimes[i]) 
                      + " minutes to close: " + minutesToClose + "\r\n";
      }
   }
   
   Comment(commentStr);
}
//+----------------------------------------------------------------------------------------------+

//+----------------------------------------------------------------------------------------------+
void CheckOrdersForCloseTime()
{
   for (int i = 0; i < ArraySize(validTickets); i++)
   {
      if (!OrderSelect(validTickets[i], SELECT_BY_TICKET) || (CheckOpen(validTickets[i]) != 1))
      {
         RemoveOrderFromFile(hWnd, recordId, validTickets[i]); 
         RemoveInvalidOrder(validTickets[i]);
         continue;  
      }   
      
      if (TimeCurrent() >= closeOrderTimes[i])
      {
         if (TryClose(validTickets[i]))
         {            
            Alert("Ticket " + validTickets[i] + " was closed by expiration date");
            RemoveOrderFromFile(hWnd, recordId, validTickets[i]); 
            RemoveInvalidOrder(validTickets[i]);            
            continue;
         }
      }  
   }
}
//+----------------------------------------------------------------------------------------------+

//+----------------------------------------------------------------------------------------------+
void CheckSellOrdersForCloseByBid()
{
   for (int i = 0; i < ArraySize(validTickets); i++)
   {
      if (!OrderSelect(validTickets[i], SELECT_BY_TICKET) || (CheckOpen(validTickets[i]) != 1))
      {
         RemoveOrderFromFile(hWnd, recordId, validTickets[i]); 
         RemoveInvalidOrder(validTickets[i]);
         continue;  
      }   
      if (OrderType() != OP_SELL)
         continue;
         
      string symbol = OrderSymbol();
      double bid = MarketInfo(symbol, MODE_BID);
      if (bid <= OrderTakeProfit())
      {
         if (TryClose(validTickets[i]))
         {            
            Alert("Sell ticket " + validTickets[i] + " was closed by bid price");
            RemoveOrderFromFile(hWnd, recordId, validTickets[i]); 
            RemoveInvalidOrder(validTickets[i]);            
            continue;
         }
      }
   }
}
//+----------------------------------------------------------------------------------------------+

//+----------------------------------------------------------------------------------------------+
void AddValidOrder(int ticket, int closeTime)
{
   ArrayResize(validTickets, ArraySize(validTickets) + 1);
   ArrayResize(closeOrderTimes, ArraySize(closeOrderTimes) + 1);
   validTickets[ArraySize(validTickets) - 1] = ticket;
   closeOrderTimes[ArraySize(closeOrderTimes) - 1] = closeTime;
}
//+----------------------------------------------------------------------------------------------+

//+----------------------------------------------------------------------------------------------+
void RemoveInvalidOrder(int ticket)
{
   for (int i = 0; i < ArraySize(validTickets); i++)
   {
      if (validTickets[i] == ticket)
      {
         for (int j = i; j < ArraySize(validTickets) - 1; j++)
         {
            validTickets[j] = validTickets[j + 1];
            closeOrderTimes[j] = closeOrderTimes[j + 1];
         }
         ArrayResize(validTickets, ArraySize(validTickets) - 1);
         ArrayResize(closeOrderTimes, ArraySize(closeOrderTimes) - 1);
         break;
      }
   }
}
//+----------------------------------------------------------------------------------------------+

//+----------------------------------------------------------------------------------------------+
int CheckOpen(int tick)
{
   // 1 - Open
   // 0 - Closed
   // -1 - ticket fail
   
   if (OrderSelect(tick, SELECT_BY_TICKET)) 
   {
      if (OrderCloseTime() == 0) return (1);
      return (0);
   }   
   return (-1);
}
//+----------------------------------------------------------------------------------------------+

//+------------------------------------------------------------------+
bool TryClose(int ticket) 
{
   if (OrderSelect(ticket, SELECT_BY_TICKET) && (CheckOpen(ticket) == 1))
   {   
      RefreshRates();
      
      int k = 0;
      while(k < 5)
      {
         RefreshRates();
         if (OrderType() > OP_SELL)
         {
            OrderDelete(ticket);
            return (true);
         }
         else
         {
            if(OrderClose(ticket, OrderLots(), OrderClosePrice(), Slippage)) 
            {
               return (true);
            }
         }   
         k++;
      }             
   }
   return (false);
}
//+------------------------------------------------------------------+

//+----------------------------------------------------------------------------------------------+
bool DisplayError(int errorCodeWithMinus)
{
   if (IsNeedToDisplayError(errorCodeWithMinus))
   {
      int errorCode = MathAbs(errorCodeWithMinus);
      Alert("ERROR: ", errorCode, " ", ErrorDescription(errorCode));                                        
      return (true);            
   }
   return (false);
}
//+----------------------------------------------------------------------------------------------+

//+----------------------------------------------------------------------------------------------+
bool IsNeedToDisplayError(int errorCodeWithMinus)
{
   if (errorCodeWithMinus < 0)                                      
      return (true);   
   return (false);
}
//+----------------------------------------------------------------------------------------------+



//+-------------------------+
#define NoneError 0       //|
#define WaitError 1       //|
#define LongWaitError 2   //|
#define StopsError 3      //|
#define CriticalError 4   //|
//+-------------------------+

//+----------------------------------------------------------------------------------------------+
int OpenOrder(string symbol, 
              int type, 
              double lot, 
              double price, 
              double stopLoss, 
              double takeProfit, 
              int slippage = 100, 
              string comment = "", 
              int magic = 42, 
              int attempts = 10, 
              datetime expiration = 0, 
              color orderColor = CLR_NONE)
{
   int 
      error,
      ticket;
   
   double  
      stopLevel = MarketInfo(symbol, MODE_STOPLEVEL) * MarketInfo(symbol, MODE_POINT),
      zeroDouble = MarketInfo(symbol, MODE_POINT),
      ask = MarketInfo(symbol, MODE_ASK) / 10,
      bid = MarketInfo(symbol, MODE_BID);            
      
   lot = NormalizeLots(lot, symbol);
   price = NormalizeDouble(price, MarketInfo(symbol, MODE_DIGITS));
   stopLoss = NormalizeDouble(stopLoss, MarketInfo(symbol, MODE_DIGITS));
   takeProfit = NormalizeDouble(takeProfit, MarketInfo(symbol, MODE_DIGITS));    

   for (int i = 0; i < attempts; i++)
   {      
      ticket = OrderSend(symbol, type, lot, price, slippage, stopLoss, takeProfit, comment, magic, expiration, orderColor);
      error = GetLastError() * (-1);  
      switch (ProccessError(error)) 
      {
         case WaitError:
            DllSleep(250);
            continue;
         case LongWaitError:
            i--;
            DllSleep(100);
            continue;
         case CriticalError: 
            return (error);             
      } 
      break;
   }
   
   if (ticket == -1)
      return (error);
   // -->  Check stops
   if ((sl <= zeroDouble) && (tp <= zeroDouble))
      return (ticket);
   // <--   
   
   ticket = ModifyOrder(symbol, ticket, sl, tp, orderColor);
   return (ticket);
}
//+----------------------------------------------------------------------------------------------+

//+----------------------------------------------------------------------------------------------+
int ModifyOrder(string symbol, int ticket, double stopLoss, double takeProfit, color orderColor = CLR_NONE)
{
   int 
      error = ticket;
   bool
      needModify = true;      
   double  
      stopLevel = MarketInfo(symbol, MODE_STOPLEVEL) * Point,
      zeroDouble = Point / 10,
      ask = MarketInfo(symbol, MODE_ASK),
      bid = MarketInfo(symbol, MODE_BID);      
   
   if ((stopLoss < zeroDouble) && (takeProfit < zeroDouble))
      needModify = false;
         
   for (int i = 0; i < 10; i++)      
   {
      if (OrderSelect(ticket, SELECT_BY_TICKET))
      {        
         RefreshRates();
         switch (OrderType())
         {
            case OP_BUY:  
            {
               if ((stopLoss > zeroDouble) && ((bid - stopLoss) < stopLevel) && (stopLoss != OrderStopLoss()))
                  needModify = false;
               if ((takeProfit > zeroDouble) && ((takeProfit - ask) < stopLevel) && (takeProfit != OrderTakeProfit()))
                  needModify = false;
               break;     
            }   
            case OP_SELL:  
            {
               if ((stopLoss > zeroDouble) && ((stopLoss - ask) < stopLevel) && (stopLoss != OrderStopLoss()))
                  needModify = false;
               if ((takeProfit > zeroDouble) && ((bid - takeProfit) < stopLevel) && (takeProfit != OrderTakeProfit()))
                  needModify = false;            
               break;     
            }        
            case OP_BUYLIMIT : 
            {
               if ((stopLoss > zeroDouble) && ((OrderOpenPrice() - stopLoss) < stopLevel) && (stopLoss != OrderStopLoss()))
                  needModify = false;
               if ((takeProfit > zeroDouble) && ((takeProfit - OrderOpenPrice()) < stopLevel) && (takeProfit != OrderTakeProfit()))
                  needModify = false;
               break;
            }   
            case OP_SELLLIMIT : 
            {
               if ((stopLoss > zeroDouble) && ((stopLoss - OrderOpenPrice()) < stopLevel) && (stopLoss != OrderStopLoss()))
                  needModify = false;
               if ((takeProfit > zeroDouble) && ((OrderOpenPrice() - takeProfit) < stopLevel) && (takeProfit != OrderTakeProfit()))
                  needModify = false;   
               break;
            } 
            case OP_BUYSTOP : 
            {
               if ((stopLoss > zeroDouble) && ((OrderOpenPrice() - stopLoss) < stopLevel) && (stopLoss != OrderStopLoss()))
                  needModify = false;
               if ((takeProfit > zeroDouble) && ((takeProfit - OrderOpenPrice()) < stopLevel) && (takeProfit != OrderTakeProfit()))
                  needModify = false;  
               break;
            } 
            case OP_SELLSTOP : 
            {
               if ((stopLoss > zeroDouble) && ((stopLoss - OrderOpenPrice()) < stopLevel) && (stopLoss != OrderStopLoss()))
                  needModify = false;
               if ((takeProfit > zeroDouble) && ((OrderOpenPrice() - takeProfit) < stopLevel) && (takeProfit != OrderTakeProfit()))
                  needModify = false;
               break;
            }  
         }         
               
         if (needModify)
         {         
            bool modified = OrderModify(ticket, OrderOpenPrice(), stopLoss, takeProfit, OrderExpiration(), orderColor);         
            if (!modified)
            {
               error = GetLastError() * (-1); 
               switch (ProccessError(error)) 
               {
                  case WaitError:
                     DllSleep(250);
                     continue;
                  case LongWaitError:
                     i--;
                     DllSleep(100);
                     continue;
                  case CriticalError: 
                     return (error);            
                  case NoneError: 
                     return (ticket);  
               }            
            }               
            else
               return (ticket);                 
         }
         else
         {
            return (ticket);
         }
      }
   }      
   return (error);
}
//+----------------------------------------------------------------------------------------------+

//+----------------------------------------------------------------------------------------------+
int ProccessError(int errorCode)
{
   if (errorCode > 0)
      return (NoneError);
   errorCode = MathAbs(errorCode);   
   switch (errorCode) 
   {
      case ERR_NO_ERROR:
      case ERR_NO_RESULT:      
         return (NoneError);      
      case ERR_COMMON_ERROR:
      case ERR_INVALID_PRICE:
      case ERR_PRICE_CHANGED:      
      case ERR_TOO_MANY_REQUESTS:
      case ERR_REQUOTE:
         return (WaitError);
      case ERR_TRADE_CONTEXT_BUSY:   
         return (LongWaitError);
      case ERR_INVALID_STOPS:
         return (StopsError);
      default: 
         return (CriticalError);        
   }   
}
//+----------------------------------------------------------------------------------------------+

//+----------------------------------------------------------------------------------------------+
int CheckStop(string symbol, int Stop_pt, int stopType = 1)
{
   // 0 - SL
   // 1 - TP
   
   if (Stop_pt == 0) return (0);   
   double MinStopDist = MarketInfo(Symbol(), MODE_STOPLEVEL);
   int spread = MarketInfo(Symbol(), MODE_SPREAD);
   if (Stop_pt < MinStopDist) Stop_pt = MinStopDist;
      
   if (stopType == 0)
   {
      if (Stop_pt < MinStopDist + spread) Stop_pt = MinStopDist + spread;
   }   
   
   return (Stop_pt);
}
//+----------------------------------------------------------------------------------------------+ 

//+----------------------------------------------------------------------------------------------+
double NormalizeLots(double lots, string symbol)
{
   double lotStep = MarketInfo(symbol, MODE_LOTSTEP),
      maxLot = MarketInfo(symbol, MODE_MAXLOT),
      minLot = MarketInfo(symbol, MODE_MINLOT);
   
   int fullCount = lots / lotStep;            
   double result = fullCount * lotStep;        
   
   if (result < minLot) result = minLot;
   if (result > maxLot) result = maxLot;

   return(result);
}
//+----------------------------------------------------------------------------------------------+



int SymbolsList(string &Symbols[], bool Selected = true) {

   string SymbolsFileName;
   int Offset, SymbolsNumber;
   
   if(Selected) SymbolsFileName = "symbols.sel";
   else         SymbolsFileName = "symbols.raw";
   
   int hFile = FileOpenHistory(SymbolsFileName, FILE_BIN|FILE_READ);
   if(hFile < 0) return(-1);
   if(Selected) { SymbolsNumber = (FileSize(hFile) - 4) / 128; Offset = 116;  }
   else         { SymbolsNumber = FileSize(hFile) / 1936;      Offset = 1924; }

   ArrayResize(Symbols, SymbolsNumber);

   if(Selected) FileSeek(hFile, 4, SEEK_SET);
   
   for(int i = 0; i < SymbolsNumber; i++)
   {
      Symbols[i] = FileReadString(hFile, 12);
      FileSeek(hFile, Offset, SEEK_CUR);
   }
   
   FileClose(hFile);

   return(SymbolsNumber);
}

bool ContainsSymbol(string symbol)
{
   for (int i = 0; i < ArraySize(symbols); i++)  
   {
      if (symbols[i] == symbol)
      {
         return (true);
      }
   }
   return (false);
}