#property copyright "Copyright 2016, AlMac."
#property link      "https://www.google.com.br"
#property version   "0.50"

#include <Trade\Trade.mqh>

// PARAMETROS;
input int      FAST_EMA = 17;
input int      SLOW_EMA = 34;
input int      VOLUME = 5;
input double   PROFIT_MOVE_STOP = 0;
input double   STOP_GAIN = 10;

// INDICADORES;
int            FAST_EMA_HANDLE;
int            SLOW_EMA_HANDLE;
double         FAST_EMA_BUFFER[];
double         SLOW_EMA_BUFFER[];

// ESTADO DO TRADE;
bool           IS_TRADING;
bool           IS_BUY;

// PRE�OS;
MqlTick        LATEST_PRICE;
MqlRates       RECENT_BARS[];
CTrade         TRADE;
double         LAST_SL;

int OnInit()
{
   FAST_EMA_HANDLE = iMA(NULL, 0, FAST_EMA, 0, MODE_EMA, PRICE_CLOSE);
   SLOW_EMA_HANDLE = iMA(NULL, 0, SLOW_EMA, 0, MODE_EMA, PRICE_CLOSE);
   Print("INICIANDO ROBOTINHAO");
   return(INIT_SUCCEEDED);
}

void OnTick()
{
   MqlDateTime time;
   TimeCurrent(time);
   bool wasTrading = IS_TRADING;
   IS_TRADING = PositionSelect(_Symbol);
   
   if(wasTrading && !IS_TRADING)
      PlaySound("alert");
   
   if(IS_TRADING && PositionGetInteger(POSITION_TYPE) == POSITION_TYPE_BUY)
      IS_BUY = true;
   CopyBuffer(FAST_EMA_HANDLE, 0, 0, 5, FAST_EMA_BUFFER);
   CopyBuffer(SLOW_EMA_HANDLE, 0, 0, 5, SLOW_EMA_BUFFER);
   
   if(!IS_TRADING)
   {
      if(time.hour >= 17 && time.min >= 55)
         return;
      // ---------------TEND�NCIA DE BAIXA--------------- //
      // se a m�dia curta est� para baixo da longa
      if(FAST_EMA_BUFFER[4] < SLOW_EMA_BUFFER[4])
      {
         // nos ultimos 5 per�odos o pre�o v�m caindo. (melhorar essa l�gica)
         if(FAST_EMA_BUFFER[4] < FAST_EMA_BUFFER[3] && 
            FAST_EMA_BUFFER[3] < FAST_EMA_BUFFER[2] &&
            FAST_EMA_BUFFER[2] < FAST_EMA_BUFFER[1] &&
            FAST_EMA_BUFFER[1] < FAST_EMA_BUFFER[0])
         {
            SymbolInfoTick(_Symbol, LATEST_PRICE);
            // o pre�o atual est� para baixo da m�dia curta
            if(LATEST_PRICE.last < FAST_EMA_BUFFER[4])
            {
               CopyRates(_Symbol, _Period, 0, 2, RECENT_BARS);
               // e o pre�o de abertura do candle anterior estava para cima da m�dia curta
               if(RECENT_BARS[0].open > FAST_EMA_BUFFER[0] || // ou a maxima esta entre as duas medias
               (RECENT_BARS[0].high > FAST_EMA_BUFFER[0] && RECENT_BARS[0].high < SLOW_EMA_BUFFER[0]))
               {
                  PlaySound("news");
                  StartTrade(ORDER_TYPE_SELL, LATEST_PRICE.ask, SLOW_EMA_BUFFER[0]);
               }
            }
         }
      }
      
      // ---------------TEND�NCIA DE ALTA--------------- //
      // se a m�dia curta est� para cima da longa
      if(FAST_EMA_BUFFER[4] > SLOW_EMA_BUFFER[4])
      {
         // nos ultimos 5 per�odos o pre�o v�m subindo. (melhorar essa l�gica)
         if(FAST_EMA_BUFFER[4] > FAST_EMA_BUFFER[3] && 
            FAST_EMA_BUFFER[3] > FAST_EMA_BUFFER[2] &&
            FAST_EMA_BUFFER[2] > FAST_EMA_BUFFER[1] &&
            FAST_EMA_BUFFER[1] > FAST_EMA_BUFFER[0])
         {
            SymbolInfoTick(_Symbol, LATEST_PRICE);
            // o pre�o atual est� para cima da m�dia curta
            if(LATEST_PRICE.last > FAST_EMA_BUFFER[4])
            {
               CopyRates(_Symbol, _Period, 0, 2, RECENT_BARS);
               // e o pre�o de abertura do candle anterior estava para baixo da m�dia curta
               if(RECENT_BARS[0].open < FAST_EMA_BUFFER[0] || // ou a minima esta entre as duas medias;
               (RECENT_BARS[0].low < FAST_EMA_BUFFER[0] && RECENT_BARS[0].low > SLOW_EMA_BUFFER[0]))
               {
                  PlaySound("news");
                  StartTrade(ORDER_TYPE_BUY, LATEST_PRICE.ask, SLOW_EMA_BUFFER[0]);
               }
            }
         }
      }
   }
   else
   {
      double profit = PositionGetDouble(POSITION_PROFIT);
      if(profit > PROFIT_MOVE_STOP && PROFIT_MOVE_STOP > 0)
      {
         if(IS_BUY)
         {
            if(LAST_SL < FAST_EMA_BUFFER[0])
            {
               LAST_SL = FAST_EMA_BUFFER[0];
               Print("SUBINDO STOP", LAST_SL);
               TRADE.PositionModify(_Symbol, LAST_SL, PositionGetDouble(POSITION_TP));
            }
         }
         else
         {
            if(LAST_SL > FAST_EMA_BUFFER[0])
            {
               LAST_SL = FAST_EMA_BUFFER[0];
               Print("DESCENDO STOP", LAST_SL);
               TRADE.PositionModify(_Symbol, LAST_SL, PositionGetDouble(POSITION_TP));
            }
         }
      }
      
      
      if(time.hour >= 17 && time.min >= 55)
      {
         Print("FIM DO DIA. ENCERRANDO POSI��O.");
         PlaySound("alert");
         TRADE.PositionClose(_Symbol);
      }
   }
}

uint StartTrade(ENUM_ORDER_TYPE type, double price, double sl)
{
   LAST_SL = sl;
   TRADE.PositionOpen(_Symbol,
                      type,
                      VOLUME,
                      NormalizeDouble(price, _Digits),
                      NormalizeDouble(sl, 0),
                      type == ORDER_TYPE_BUY ? NormalizeDouble(price + STOP_GAIN, 0) : NormalizeDouble(price - STOP_GAIN, 0),
                      NULL);
                      
   return TRADE.ResultRetcode();
}

void OnDeinit(const int reason)
{
}