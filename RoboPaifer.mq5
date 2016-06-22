#property copyright "Copyright 2016, AlMac."
#property link      "https://www.google.com.br"
#property version   "0.01"

#include <Trade\Trade.mqh>

input int               VOLUME = 5;
input double            BREAK_OFFSET = 3;
input double            STOP_GAIN = 5;
input double            STOP_LOSS = 3;

MqlTick                 LATEST_PRICE;
MqlRates                FIRST_CANDLE;
bool                    GOT_FIRST_CANDLE = false;
bool                    TRADED = false;
CTrade                  TRADE;

int OnInit()
{
   
   return(INIT_SUCCEEDED);
}

void OnTick()
{
   MqlDateTime time;
   TimeCurrent(time);
   
   if(time.hour == 9 && time.min < 5)
   {
      GOT_FIRST_CANDLE = false;
      TRADED = false;
   }
   
   if(time.hour == 9 && time.min >= 5 && time.min < 10 && !GOT_FIRST_CANDLE)
   {
      MqlRates rates[];
      CopyRates(_Symbol, PERIOD_M5, 0, 1, rates);
      FIRST_CANDLE = rates[0];
      GOT_FIRST_CANDLE = true;
   }
   
   if(GOT_FIRST_CANDLE)
   {
      SymbolInfoTick(_Symbol, LATEST_PRICE);
      if(LATEST_PRICE.last > (FIRST_CANDLE.high + BREAK_OFFSET) && !TRADED)
      {
         TRADED = true;
         TRADE.PositionOpen(_Symbol,
                            ORDER_TYPE_BUY,
                            VOLUME,
                            NormalizeDouble(LATEST_PRICE.ask, 0),
                            NormalizeDouble(LATEST_PRICE.ask - STOP_LOSS, 0),
                            NormalizeDouble(LATEST_PRICE.ask + STOP_GAIN, 0),
                            NULL);
      }
      else if(LATEST_PRICE.last < (FIRST_CANDLE.low - BREAK_OFFSET) && !TRADED)
      {
         
         TRADED = true;
         TRADE.PositionOpen(_Symbol,
                            ORDER_TYPE_SELL,
                            VOLUME,
                            NormalizeDouble(LATEST_PRICE.bid, 0),
                            NormalizeDouble(LATEST_PRICE.bid + STOP_LOSS, 0),
                            NormalizeDouble(LATEST_PRICE.bid - STOP_GAIN, 0),
                            NULL);
      }
   }
}

void OnDeinit(const int reason)
{

}