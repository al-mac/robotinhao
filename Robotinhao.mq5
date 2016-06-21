#property copyright "Copyright 2016, AlMac."
#property link      "https://www.google.com.br"
#property version   "0.58"

#include <Trade\Trade.mqh>

// PARAMETROS;
input int               FAST_EMA = 17;
input int               SLOW_EMA = 34;
input int               VOLUME = 5;
input double            STOP_GAIN = 10;
input double            CALAMITY_GAIN = 5;
input double            EUPHORIA_GAIN = 20;
input double            EUPHORIA_LOSS = 4;
input double            EUPHORIA_TRIGGER = 2;
input ENUM_TIMEFRAMES   FASTER_TIMEFRAME = PERIOD_M1;
input int               EMA_FASTER_TIMEFRAME = 10;
input int               AVERAGE_DISTANCE = 4;
input bool              ENABLE_EUPHORIA = true;

// INDICADORES;
int                     FAST_EMA_HANDLE;
int                     SLOW_EMA_HANDLE;
int                     EMA_HANDLE_FASTER_TIMEFRAME;
double                  FAST_EMA_BUFFER[];
double                  SLOW_EMA_BUFFER[];
double                  EMA_BUFFER_FASTER_TIMEFRAME[];

// ESTADO DO TRADE;
bool                    IS_TRADING;
bool                    IS_BUY;
bool                    CALAMITY = false;
bool                    EUPHORIA = false;

// PREÇOS;
MqlTick                 LATEST_PRICE;
MqlRates                RECENT_BARS[];
CTrade                  TRADE;

int OnInit()
{
   FAST_EMA_HANDLE = iMA(NULL, 0, FAST_EMA, 0, MODE_EMA, PRICE_CLOSE);
   SLOW_EMA_HANDLE = iMA(NULL, 0, SLOW_EMA, 0, MODE_EMA, PRICE_CLOSE);
   EMA_HANDLE_FASTER_TIMEFRAME = iMA(NULL, FASTER_TIMEFRAME, EMA_FASTER_TIMEFRAME, 0, MODE_EMA, PRICE_CLOSE);
   
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
   
   if(IS_TRADING && PositionGetInteger(POSITION_TYPE) == POSITION_TYPE_SELL)
      IS_BUY = false;
      
   CopyBuffer(FAST_EMA_HANDLE, 0, 0, 5, FAST_EMA_BUFFER);
   CopyBuffer(SLOW_EMA_HANDLE, 0, 0, 5, SLOW_EMA_BUFFER);
   CopyBuffer(EMA_HANDLE_FASTER_TIMEFRAME, 0, 0, 4, EMA_BUFFER_FASTER_TIMEFRAME);
   SymbolInfoTick(_Symbol, LATEST_PRICE);
   
   if(!IS_TRADING)
   {
      if((time.hour == 17 && time.min >= 55) || time.hour >= 18)
         return;
      // ---------------TENDÊNCIA DE BAIXA--------------- //
      // se a média curta está para baixo da longa
      CopyRates(_Symbol, _Period, 0, 2, RECENT_BARS);
      if(FAST_EMA_BUFFER[4] < SLOW_EMA_BUFFER[4])
      {
         // nos ultimos 5 períodos o preço vêm caindo. (melhorar essa lógica)
         if(FAST_EMA_BUFFER[4] < FAST_EMA_BUFFER[3] && 
            FAST_EMA_BUFFER[3] < FAST_EMA_BUFFER[2] &&
            FAST_EMA_BUFFER[2] < FAST_EMA_BUFFER[1] &&
            FAST_EMA_BUFFER[1] < FAST_EMA_BUFFER[0])
         {
            
            // o preço atual está para baixo da média curta
            if(LATEST_PRICE.last < FAST_EMA_BUFFER[4])
            {
               // e o preço de abertura do candle anterior estava para cima da média curta
               if(RECENT_BARS[0].open > FAST_EMA_BUFFER[0] || // ou a maxima esta entre as duas medias
                  (RECENT_BARS[0].high > FAST_EMA_BUFFER[0] && RECENT_BARS[0].high < SLOW_EMA_BUFFER[0]))
               {
                  if(EMA_BUFFER_FASTER_TIMEFRAME[3] < EMA_BUFFER_FASTER_TIMEFRAME[2] && 
                     EMA_BUFFER_FASTER_TIMEFRAME[2] < EMA_BUFFER_FASTER_TIMEFRAME[1] && 
                     EMA_BUFFER_FASTER_TIMEFRAME[1] < EMA_BUFFER_FASTER_TIMEFRAME[0])
                  {
                     // se a distância entre as médias for maior que o parâmetro
                     double avgDist = SLOW_EMA_BUFFER[4] - FAST_EMA_BUFFER[4];
                     if(avgDist > AVERAGE_DISTANCE)
                     {                        
                        // se o stop gain for maior que o stop loss
                        if(SLOW_EMA_BUFFER[0] - LATEST_PRICE.bid < STOP_GAIN)
                        {
                           // abrir venda
                           uint code = StartTrade(ORDER_TYPE_SELL, LATEST_PRICE.bid, SLOW_EMA_BUFFER[0]);
                           EvaluateTradeResult(code);
                        }
                     }
                  }
               }
            }
         }
      }
      
      // ---------------TENDÊNCIA DE ALTA--------------- //
      // se a média curta está para cima da longa
      if(FAST_EMA_BUFFER[4] > SLOW_EMA_BUFFER[4])
      {
         // nos ultimos 5 períodos o preço vêm subindo. (melhorar essa lógica)
         if(FAST_EMA_BUFFER[4] > FAST_EMA_BUFFER[3] && 
            FAST_EMA_BUFFER[3] > FAST_EMA_BUFFER[2] &&
            FAST_EMA_BUFFER[2] > FAST_EMA_BUFFER[1] &&
            FAST_EMA_BUFFER[1] > FAST_EMA_BUFFER[0])
         {
            // o preço atual está para cima da média curta
            if(LATEST_PRICE.last > FAST_EMA_BUFFER[4])
            {
               // e o preço de abertura do candle anterior estava para baixo da média curta
               if(RECENT_BARS[0].open < FAST_EMA_BUFFER[0] || // ou a minima esta entre as duas medias;
                  (RECENT_BARS[0].low < FAST_EMA_BUFFER[0] && RECENT_BARS[0].low > SLOW_EMA_BUFFER[0]))
               {
                  if(EMA_BUFFER_FASTER_TIMEFRAME[3] > EMA_BUFFER_FASTER_TIMEFRAME[2] && 
                     EMA_BUFFER_FASTER_TIMEFRAME[2] > EMA_BUFFER_FASTER_TIMEFRAME[1] && 
                     EMA_BUFFER_FASTER_TIMEFRAME[1] > EMA_BUFFER_FASTER_TIMEFRAME[0])
                  {
                     // se a distância entre as médias for maior que o parâmetro
                     double avgDist = FAST_EMA_BUFFER[4] - SLOW_EMA_BUFFER[4];
                     if(avgDist > AVERAGE_DISTANCE)
                     {
                        // se o stop gain for maior que o stop loss
                        if(LATEST_PRICE.bid - SLOW_EMA_BUFFER[0] < STOP_GAIN)
                        {
                           // abrir compra
                           uint code = StartTrade(ORDER_TYPE_BUY, LATEST_PRICE.ask, SLOW_EMA_BUFFER[0]);
                           EvaluateTradeResult(code);
                        }
                     }
                  }
               }
            }
         }
      }
   }
   else
   {
      // Analisar o trade para ver se entra no estado de calamidade.
      // Estado de calamidade: se o preço passar para cima das médias,
      // alterar stop gain para 1 ponto.
      CopyRates(_Symbol, _Period, 0, 5, RECENT_BARS);
      if(IS_BUY)
      {
         if(SLOW_EMA_BUFFER[0] > LATEST_PRICE.last && !CALAMITY)
         {
            CALAMITY = true;
            double newTp = PositionGetDouble(POSITION_PRICE_OPEN) + CALAMITY_GAIN;
            Print("BUY: ENTRANDO EM ESTADO DE CALAMIDADE");
            TRADE.PositionModify(_Symbol, PositionGetDouble(POSITION_SL), newTp);
         }
         
         if(!EUPHORIA && ENABLE_EUPHORIA && PositionGetDouble(POSITION_TP) > LATEST_PRICE.last + EUPHORIA_TRIGGER &&
            ((RECENT_BARS[0].low - FAST_EMA_BUFFER[4]) > (RECENT_BARS[1].low - FAST_EMA_BUFFER[3]) && RECENT_BARS[0].low < RECENT_BARS[1].low) &&
            (RECENT_BARS[1].low - FAST_EMA_BUFFER[3]) > (RECENT_BARS[2].low - FAST_EMA_BUFFER[2] && RECENT_BARS[1].low < RECENT_BARS[2].low)
           )
         {
            EUPHORIA = true;
            Print("BUY: ENTRANDO EM ESTADO DE EUFORIA");
            double newTp = PositionGetDouble(POSITION_PRICE_OPEN) + EUPHORIA_GAIN;
            double newSl = PositionGetDouble(POSITION_PRICE_OPEN) + EUPHORIA_LOSS;
            TRADE.PositionModify(_Symbol, newSl, newTp);
         }
      }
      else
      {
         if(SLOW_EMA_BUFFER[0] < LATEST_PRICE.last && !CALAMITY)
         {
            CALAMITY = true;
            Print("SELL: ENTRANDO EM ESTADO DE CALAMIDADE");
            double newTp = PositionGetDouble(POSITION_PRICE_OPEN) - CALAMITY_GAIN;
            TRADE.PositionModify(_Symbol, PositionGetDouble(POSITION_SL), newTp);
         }
         
         if(!EUPHORIA && ENABLE_EUPHORIA && PositionGetDouble(POSITION_TP) > LATEST_PRICE.last - EUPHORIA_TRIGGER &&
            ((RECENT_BARS[0].high - FAST_EMA_BUFFER[4]) > (RECENT_BARS[1].high - FAST_EMA_BUFFER[3]) && RECENT_BARS[0].high < RECENT_BARS[1].high) &&
            (RECENT_BARS[1].high - FAST_EMA_BUFFER[3]) > (RECENT_BARS[2].high - FAST_EMA_BUFFER[2] && RECENT_BARS[1].high < RECENT_BARS[2].high)
           )
         {
            EUPHORIA = true;
            Print("SELL: ENTRANDO EM ESTADO DE EUFORIA");
            double newTp = PositionGetDouble(POSITION_PRICE_OPEN) - EUPHORIA_GAIN;
            double newSl = PositionGetDouble(POSITION_PRICE_OPEN) - EUPHORIA_LOSS;
            TRADE.PositionModify(_Symbol, newSl, newTp);
         }
         
      }
   
      
      
      if((time.hour == 17 && time.min >= 55) || time.hour >= 18)
      {
         Print("FIM DO DIA. ENCERRANDO POSIÇÃO.");
         PlaySound("alert");
         TRADE.PositionClose(_Symbol);
      }
   }
}

void EvaluateTradeResult(uint code)
{
   switch(code)
   {
      case TRADE_RETCODE_REJECT:
         Print("ORDEM REJEITADA");
         PlaySound("alert2");
         break;
      case TRADE_RETCODE_DONE:
         Print("ORDEM ACEITA");
         PlaySound("news");
         break;
      case TRADE_RETCODE_DONE_PARTIAL:
         Print("ORDEM PARCIALMENTE EXECUTADA");
         PlaySound("connect");
         break;
      case TRADE_RETCODE_TIMEOUT:
      case TRADE_RETCODE_ERROR:
      case TRADE_RETCODE_INVALID:
      case TRADE_RETCODE_INVALID_VOLUME:
      case TRADE_RETCODE_INVALID_PRICE:
      case TRADE_RETCODE_INVALID_STOPS:
         Print("ERRO AO INICIAR O TRADE: ", code);
         PlaySound("stops");
         break;
      case TRADE_RETCODE_NO_MONEY:
      case TRADE_RETCODE_PRICE_CHANGED:
         Print("AVISO - TRADE NÃO INICIADO: ", code);
         PlaySound("request");
         break;
      
   }
}

uint StartTrade(ENUM_ORDER_TYPE type, double price, double sl)
{
   CALAMITY = false;
   EUPHORIA = false;
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