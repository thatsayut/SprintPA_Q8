//+------------------------------------------------------------------+
//|  SprintPA_Q8.mq5
//|  Q8 : Q7 ไม่มีช่วง 03:00-05:00 และไม่พักหลังแพ้ (ผ่านทั้งข้อมูล Exness และ FTMO, log/113)
//|  ฐาน Q6 : Star 3-4 แท่ง ไม่มี Engulfing  ไม่เทรดวันจันทร์ + แพ้แล้วพัก 2 ชม.
//|  Trend filter : M15  EMA7 / EMA30                                |
//|  Entry        : M3   Stochastic(14,3,3) + Price Action           |
//|                 BUY  : Sto <= 20 + Bullish Engulfing / Morning * |
//|                 SELL : Sto >= 80 + Bearish Engulfing / Evening * |
//|  SL / TP      : 1000 points (default)                            |
//|  Filter       : opposing candle longer than 800 points = skip    |
//+------------------------------------------------------------------+
#property copyright "Custom EA"
#property version   "1.00"
#property description "Q8 : Q7 ไม่มีช่วง 03:00-05:00 และไม่พักหลังแพ้ (log/113)"
#property strict

#include <Trade\Trade.mqh>

//--- pattern id ------------------------------------------------------
enum ENUM_PATTERN
  {
   PAT_NONE = 0,
   PAT_ENGULFING,
   PAT_STAR,
   PAT_PIN
  };

//--- วิธีคำนวณ lot ---------------------------------------------------
enum ENUM_LOT_MODE
  {
   LOT_FIXED   = 0,   // ล็อตคงที่
   LOT_RISK_PCT = 1   // % ของยอดเงิน (โตตามพอร์ต)
  };

//--- จะทำยังไงเมื่อแพ้
enum ENUM_AFTERLOSS
  {
   AL_PAUSE_BARS = 0,  // พักกี่แท่ง M3 แล้วเทรดต่อ
   AL_STOP_DAY   = 1   // หยุดยาวถึงสิ้นวัน (เวลาไทย)
  };

//--- ไส้เทียนฝั่งไหนที่ห้ามยาว
enum ENUM_WICK_SIDE
  {
   WICK_AGAINST = 0,   // ไส้ฝั่งตรงข้ามทิศเข้า (BUY=ไส้บน / SELL=ไส้ล่าง)
   WICK_BOTH    = 1    // ห้ามยาวทั้งสองฝั่ง
  };

//--- ตัวกรองแนวรับแนวต้าน -------------------------------------------
enum ENUM_SR_MODE
  {
   SR_OFF       = 0,   // ไม่ใช้
   SR_BLOCK     = 1,   // ห้ามสวนแนว : ใกล้แนวต้านห้าม BUY / ใกล้แนวรับห้าม SELL
   SR_ONLY_NEAR = 2    // เข้าเฉพาะที่แนว : BUY เฉพาะใกล้แนวรับ / SELL เฉพาะใกล้แนวต้าน
  };

//--- สภาพตลาด (regime) ที่ยอมให้เทรด --------------------------------
enum ENUM_REGIME_MODE
  {
   REGIME_OFF        = 0,   // ไม่ใช้ตัวกรองนี้
   REGIME_SKIP_NOISE = 1,   // เทรดทั้ง MR และ Trend ข้ามเฉพาะช่วง noise
   REGIME_MR_ONLY    = 2,   // เทรดเฉพาะตลาดแกว่งกลับ (mean-reverting)
   REGIME_TREND_ONLY = 3    // เทรดเฉพาะตลาดเป็นเทรน
  };

//--- นิยาม Engulfing -------------------------------------------------
enum ENUM_ENGULF_MODE
  {
   ENGULF_STRICT  = 0,   // ตัวแท่งต้องคลุมสนิท (เปิด >= ปิดแท่งก่อน)
   ENGULF_RELAXED = 1    // ปิดทะลุตัวแท่งก่อน + ตัวแท่งใหญ่กว่า (แนะนำสำหรับทอง)
  };

//--- โหมดการใช้เทรน M15 ---------------------------------------------
enum ENUM_TREND_MODE
  {
   TREND_STRICT   = 0,   // ตามเทรนเท่านั้น (ขาขึ้น=buy, ขาลง=sell)
   TREND_REVERSAL = 1,   // ตามเทรน + ยอมสวนเมื่อราคาห่าง EMA30 มาก
   TREND_OFF      = 2    // ไม่สนเทรน เล่นทั้งสองฝั่ง
  };

//--- แหล่งเวลาสำหรับ time filter ------------------------------------
enum ENUM_TIME_SRC
  {
   TIME_AUTO_GMT   = 0,   // อัตโนมัติ (GMT+7 = เวลาไทย)
   TIME_MANUAL_OFF = 1    // ตั้ง offset จากเวลา server เอง
  };

//--- how to measure candle length -----------------------------------
enum ENUM_CANDLE_SIZE
  {
   SIZE_RANGE = 0,   // High - Low  (ทั้งแท่งรวมไส้)
   SIZE_BODY  = 1    // |Open - Close| (เฉพาะตัวแท่ง)
  };

//====================== INPUTS ======================================
input group             "=== Money / Risk ==="
input ENUM_LOT_MODE     InpLotMode           = LOT_RISK_PCT; // วิธีคำนวณ lot
input double            InpRiskPercent       = 0.75;   // เสี่ยงกี่ % ของ balance ต่อไม้ (FTMO 2-Step Safe Mode)
input double            InpLots              = 0.01;   // Lot คงที่ (ใช้เมื่อเลือก LOT_FIXED)
input double            InpMaxLot            = 5.0;    // เพดาน lot (0=ไม่จำกัด)
input double            InpMaxDailyLossPct   = 4.0;    // ขาดทุนวันละกี่ % แล้วหยุด (0=off, FTMO 2-Step < 5.0%)
input int               InpSLPoints          = 1000;   // Stop Loss (points)
input int               InpTPPoints          = 1000;   // Take Profit (points)
input long              InpMagic             = 930318; // Magic number
input int               InpMaxSpreadPoints   = 60;     // Max spread (points, 0=off)
input bool              InpOnePositionOnly   = true;   // ถือได้ทีละ 1 ไม้

input group             "=== Timeframes ==="
input ENUM_TIMEFRAMES   InpTrendTF           = PERIOD_M15; // TF ดูเทรน
input ENUM_TIMEFRAMES   InpEntryTF           = PERIOD_M3;  // TF เข้าไม้

input group             "=== Trend filter (EMA) ==="
input int               InpFastEMA           = 7;      // EMA เร็ว
input int               InpSlowEMA           = 30;     // EMA ช้า
input bool              InpInvertTrend       = false;  // กลับด้านเทรน (EMA7<EMA30 = ขาขึ้น)
input ENUM_TREND_MODE   InpTrendMode         = TREND_STRICT; // โหมดการใช้เทรน
input int               InpReversalDistPts   = 1500;   // สวนเทรนได้เมื่อห่าง EMA30 (M15) เกินกี่ points

input group             "=== ย่อมาเตะเส้น EMA (จากโน้ต Fastbull) ==="
input bool              InpUseEmaTouch       = false;  // ต้องย่อมาเตะ EMA ก่อนถึงเข้า
input int               InpEmaTouchPoints    = 300;    // ระยะที่ถือว่า \"เตะเส้น\" (points)

input group             "=== Stochastic (Entry TF) ==="
input int               InpStochK            = 14;     // %K
input int               InpStochD            = 3;      // %D
input int               InpStochSlow         = 3;      // Slowing
input double            InpStochBuyLevel     = 20.0;   // โซน oversold (<=)
input double            InpStochSellLevel    = 80.0;   // โซน overbought (>=)
input int               InpStochLookback     = 3;      // ย้อนหลังกี่แท่งที่ยอมให้แตะโซน

input group             "=== Price Action ==="
input bool              InpUseEngulfing      = false;   // ใช้ Engulfing
input ENUM_ENGULF_MODE  InpEngulfMode        = ENGULF_RELAXED; // นิยาม Engulfing
input bool              InpUseStar           = true;   // ใช้ Morning / Evening Star
input ENUM_CANDLE_SIZE  InpSizeMode          = SIZE_RANGE; // วิธีวัดความยาวแท่ง
input int               InpMaxOpposePoints   = 800;    // แท่งฝั่งตรงข้ามยาวเกินนี้ = ข้าม (0=off)
input double            InpStarSmallBodyPct  = 50.0;   // ตัวกลาง Star ต้องเล็กกว่า % ของแท่งที่ 1
input double            InpStarPenetration   = 50.0;   // แท่ง 3 ต้องกินตัวแท่งที่ 1 อย่างน้อย %
input bool              InpUsePin            = false;  // ใช้ Hammer / Pin bar (แท่งไส้ยาว)
input double            InpPinWickRatio      = 2.0;    // ไส้ต้องยาวอย่างน้อยกี่เท่าของตัวแท่ง
input double            InpPinWickPct        = 50.0;   // ไส้ต้องยาวอย่างน้อยกี่ % ของทั้งแท่ง
input int               InpPinMinRangePts    = 100;    // แท่งต้องยาวอย่างน้อยกี่จุด (กันโดจิเล็ก ๆ)

input group             "=== เสริมจากโน้ต Fastbull (ปิดไว้ default) ==="
input bool              InpM3ForStar         = true;   // Morning/Evening Star ต้องรอ M3 ด้วยไหม (false = Star เข้าได้เลย)
input bool              InpUseM3Trend        = true;   // M3 ต้องเขียว/แดงตาม M15 ด้วย (สำคัญมาก - ยืนยันด้วย backtest)
input int               InpMaxHoldMinutes    = 0;      // ถือเกินกี่นาทีให้ปิด (0=off, โน้ต=60)
input bool              InpUseTimeFilter     = true;   // จำกัดช่วงเวลาเทรด
input ENUM_TIME_SRC     InpTimeSrc           = TIME_AUTO_GMT; // อ้างอิงเวลาไทย
input string            InpSkipDows          = "1";         // ไม่เทรดวันไหน (เวลาไทย) 1=จ 2=อ 3=พ 4=พฤ 5=ศ เช่น "1"
input int               InpServerToThaiHours = 4;      // ใช้เมื่อเลือก manual (ไทย = server + N ชม.)
input string            InpSession1          = "07:00-18:00"; // เวลาไทย
input string            InpSession2          = "21:00-00:00"; // เวลาไทย
input string            InpSession3          = "";          // เวลาไทย (ว่าง = ไม่ใช้)

input group             "=== ลดไม้เมื่อผันผวนสูง ==="
input bool              InpUseVolSizing      = false;  // ช่วงกราฟวิ่งแรงให้ลดขนาดไม้
input ENUM_TIMEFRAMES   InpVolTF             = PERIOD_M15; // TF ที่ใช้วัดความผันผวน
input int               InpVolAtrPeriod      = 14;     // ATR period
input int               InpVolAvgBars        = 100;    // เทียบกับค่าเฉลี่ยย้อนหลังกี่แท่ง
input double            InpVolHighMult       = 1.5;    // ATR เกินค่าเฉลี่ย x นี้ = ผันผวนสูง
input double            InpVolLotFactor      = 0.5;    // ผันผวนสูงแล้วคูณ lot ด้วยเท่านี้

input bool              InpLogFeatures       = false;      // พิมพ์บริบทตอนเข้าไม้ (เพื่อวิเคราะห์)
input group             "=== หยุดหลังแพ้ (โค้ชสอน) ==="
input int               InpStopAfterLosses   = 0;          // แพ้ติดกันกี่ไม้แล้วหยุด (0=ไม่ใช้)
input ENUM_AFTERLOSS    InpAfterLossMode     = AL_PAUSE_BARS; // หยุดแบบไหน
input int               InpPauseBars         = 40;         // พักกี่แท่ง M3 (20 แท่ง = 1 ชม.)

input int               InpEngulfMaxBars     = 1;          // Engulfing: ใช้แท่งรวมกันได้กี่แท่ง (1-3) เกินนี้ไม่เข้า
input int               InpStarMaxMiddle     = 2;          // Star: แท่งกลางได้กี่แท่ง (1=3แท่ง, 2=4แท่ง, 3=5แท่ง)

input group             "=== ไส้เทียนแท่งสัญญาณ ==="
input double            InpMaxWickPct        = 0.0;        // ไส้ยาวเกิน % ของเนื้อเทียน = ข้าม (0=ปิด)
input ENUM_WICK_SIDE    InpWickSide          = WICK_AGAINST; // นับไส้ฝั่งไหน
input bool              InpWickForStar       = true;       // ใช้กับ Star ด้วย

input group             "=== แนวรับแนวต้าน H1 ==="
input ENUM_SR_MODE      InpSRMode            = SR_OFF;     // โหมดแนวรับแนวต้าน
input ENUM_TIMEFRAMES   InpSRTF              = PERIOD_H1;  // TF ที่ใช้หาแนว
input int               InpSRLookback        = 120;        // ย้อนหลังกี่แท่ง (H1 120 = 5 วัน)
input int               InpSRSwing           = 3;          // จุดกลับตัวต้องสูง/ต่ำกว่ากี่แท่งซ้ายขวา
input int               InpSRNearPts         = 500;        // ห่างแนวไม่เกินกี่จุด = ใกล้แนว

input group             "=== Regime filter (AR1 autocorrelation) ==="
input ENUM_REGIME_MODE  InpRegimeMode        = REGIME_OFF; // สภาพตลาดที่ยอมเทรด
input ENUM_TIMEFRAMES   InpRegimeTF          = PERIOD_M15; // TF ที่ใช้วัดสภาพตลาด
input int               InpRegimeBars        = 100;   // จำนวนแท่งที่ใช้คำนวณ
input double            InpRegimeMRThresh    = -0.10; // AR1 ต่ำกว่านี้ = แกว่งกลับ
input double            InpRegimeTrThresh    = 0.10;  // AR1 สูงกว่านี้ = เป็นเทรน

input group             "=== ตัวกรองจาก Plan B (ชุด D3) ==="
input bool              InpMacro200          = true;   // M15 ปิดเหนือ EMA200 = BUY เท่านั้น / ใต้ = SELL เท่านั้น
input bool              InpBand200Entry      = false;  // M3 ไม่ตามเทรน แต่ทดสอบโซน EMA200 Band (M3) = เข้าได้
input int               InpBand200BufPts     = 150;    // buffer รอบโซน EMA200 Band (points)
input double            InpBand200TPMult     = 1.0;    // TP x เท่านี้เมื่อเข้าที่โซน EMA200 (1.0 = ไม่ขยาย)
input bool              InpSLUnderStar       = true;   // SL ใต้ Low / เหนือ High ของชุด Star
input int               InpStarSLBufPts      = 100;    // ระยะเผื่อจาก Low/High (points)
input double            InpStarSLTPMult      = 1.5;    // TP = SL x เท่านี้ เมื่อใช้ SL ตาม Star
input int               InpStarSLMinPts      = 400;    // SL ตาม Star ต้องไม่น้อยกว่านี้ ไม่งั้นใช้ SL ปกติ
input int               InpStarSLMaxPts      = 2500;   // SL ตาม Star ต้องไม่เกินนี้ ไม่งั้นใช้ SL ปกติ

input group             "=== Misc ==="

input bool              InpAutoScalePoints   = true;   // ปรับ point อัตโนมัติตามทศนิยมโบรก
input bool              InpAllowNewBarOnly   = true;   // ตรวจสัญญาณเมื่อเปิดแท่งใหม่เท่านั้น
input bool              InpVerboseLog        = false;  // พิมพ์ log ทุกแท่ง (ใช้ debug เท่านั้น)
input string            InpComment           = "Q8";

//====================== GLOBALS =====================================
CTrade         trade;
int            hEmaFast = INVALID_HANDLE;
int            hEmaSlow = INVALID_HANDLE;
int            hStoch   = INVALID_HANDLE;
int            hEmaFastEntry = INVALID_HANDLE;
int            hEmaSlowEntry = INVALID_HANDLE;
int            hAtrVol  = INVALID_HANDLE;
int            hEma200M15 = INVALID_HANDLE;
int            hE200HiM3  = INVALID_HANDLE;
int            hE200LoM3  = INVALID_HANDLE;
datetime       lastBarTime = 0;
datetime       lastTradeBar = 0;
int            g_scale = 1;      // ตัวคูณ point (โบรก 3/5 ทศนิยม = 10)

//--- ค่าที่ปรับสเกลแล้ว ---------------------------------------------
int SLPts()      { return(InpSLPoints        * g_scale); }
int TPPts()      { return(InpTPPoints        * g_scale); }
int OpposePts()  { return(InpMaxOpposePoints * g_scale); }
int SpreadPts()  { return(InpMaxSpreadPoints * g_scale); }

//+------------------------------------------------------------------+
int OnInit()
  {
   if(InpFastEMA >= InpSlowEMA)
     {
      Print("ERROR: EMA เร็วต้องน้อยกว่า EMA ช้า");
      return(INIT_PARAMETERS_INCORRECT);
     }

   hEmaFast = iMA(_Symbol, InpTrendTF, InpFastEMA, 0, MODE_EMA, PRICE_CLOSE);
   hEmaSlow = iMA(_Symbol, InpTrendTF, InpSlowEMA, 0, MODE_EMA, PRICE_CLOSE);
   hStoch   = iStochastic(_Symbol, InpEntryTF, InpStochK, InpStochD, InpStochSlow,
                          MODE_SMA, STO_LOWHIGH);

   if(hEmaFast == INVALID_HANDLE || hEmaSlow == INVALID_HANDLE || hStoch == INVALID_HANDLE)
     {
      Print("ERROR: สร้าง indicator handle ไม่สำเร็จ");
      return(INIT_FAILED);
     }

   hEmaFastEntry = iMA(_Symbol, InpEntryTF, InpFastEMA, 0, MODE_EMA, PRICE_CLOSE);
   hEmaSlowEntry = iMA(_Symbol, InpEntryTF, InpSlowEMA, 0, MODE_EMA, PRICE_CLOSE);
   if(hEmaFastEntry == INVALID_HANDLE || hEmaSlowEntry == INVALID_HANDLE)
     {
      Print("ERROR: สร้าง EMA ของ entry TF ไม่สำเร็จ");
      return(INIT_FAILED);
     }

   if(InpUseVolSizing)
     {
      hAtrVol = iATR(_Symbol, InpVolTF, InpVolAtrPeriod);
      if(hAtrVol == INVALID_HANDLE)
        {
         Print("ERROR: สร้าง ATR สำหรับวัดความผันผวนไม่สำเร็จ");
         return(INIT_FAILED);
        }
     }

   if(InpMacro200)
      hEma200M15 = iMA(_Symbol, InpTrendTF, 200, 0, MODE_EMA, PRICE_CLOSE);
   if(InpBand200Entry || InpBand200TPMult != 1.0)
     {
      hE200HiM3 = iMA(_Symbol, InpEntryTF, 200, 0, MODE_EMA, PRICE_HIGH);
      hE200LoM3 = iMA(_Symbol, InpEntryTF, 200, 0, MODE_EMA, PRICE_LOW);
     }

   //--- ทองแบบ 3 ทศนิยม / ฟอเร็กซ์ 5 ทศนิยม ต้องคูณ point 10 เท่า
   g_scale = 1;
   if(InpAutoScalePoints && (_Digits == 3 || _Digits == 5))
      g_scale = 10;
   PrintFormat("Digits=%d _Point=%.5f -> ตัวคูณ point = %d", _Digits, _Point, g_scale);

   trade.SetExpertMagicNumber(InpMagic);
   trade.SetTypeFillingBySymbol(_Symbol);
   trade.SetDeviationInPoints(30);

   PrintFormat("SprintPA started | Trend %s EMA%d/EMA%d | Entry %s Stoch(%d,%d,%d)",
               EnumToString(InpTrendTF), InpFastEMA, InpSlowEMA,
               EnumToString(InpEntryTF), InpStochK, InpStochD, InpStochSlow);

   ReportRiskAndTime();
   return(INIT_SUCCEEDED);
  }

//+------------------------------------------------------------------+
void OnDeinit(const int reason)
  {
   if(hEmaFast != INVALID_HANDLE) IndicatorRelease(hEmaFast);
   if(hEmaSlow != INVALID_HANDLE) IndicatorRelease(hEmaSlow);
   if(hStoch   != INVALID_HANDLE) IndicatorRelease(hStoch);
   if(hEmaFastEntry != INVALID_HANDLE) IndicatorRelease(hEmaFastEntry);
   if(hEmaSlowEntry != INVALID_HANDLE) IndicatorRelease(hEmaSlowEntry);
   if(hAtrVol != INVALID_HANDLE) IndicatorRelease(hAtrVol);
   if(hEma200M15 != INVALID_HANDLE) IndicatorRelease(hEma200M15);
   if(hE200HiM3  != INVALID_HANDLE) IndicatorRelease(hE200HiM3);
   if(hE200LoM3  != INVALID_HANDLE) IndicatorRelease(hE200LoM3);
  }

//+------------------------------------------------------------------+
void OnTick()
  {
   ManageOpenPositions();                      // ปิดไม้ที่ถือนานเกิน (ถ้าเปิดใช้)

   //--- ทำงานเมื่อแท่ง M3 ปิดใหม่เท่านั้น
   datetime bt = (datetime)SeriesInfoInteger(_Symbol, InpEntryTF, SERIES_LASTBAR_DATE);
   if(InpAllowNewBarOnly)
     {
      if(bt == lastBarTime) return;
      lastBarTime = bt;
     }

   if(InpVerboseLog) DumpBar();

   if(InpOnePositionOnly && HasOpenPosition()) { Why("มีไม้เปิดอยู่"); return; }
   if(lastTradeBar == bt) { Why("เข้าไปแล้วในแท่งนี้"); return; }
   if(!SpreadOK()) { Why("spread"); return; }
   if(!TimeFilterOK()) { Why("นอกเวลา"); return; }
   if(!DailyLossOK()) { Why("ขาดทุนรายวันเกิน"); return; }
   AfterLossUpdate();
   if(!AfterLossOK()) { Why("พักหลังแพ้"); return; }
   if(!RegimeOK()) { Why("regime"); return; }

   double ema30 = 0.0;
   int trend = GetTrendEx(ema30);              // +1 = ขาขึ้น, -1 = ขาลง, 0 = ไม่ชัด

   bool allowBuy = false, allowSell = false;

   if(InpTrendMode == TREND_OFF)
     {
      allowBuy = true;
      allowSell = true;
     }
   else
     {
      if(trend == 0) { Why("M15 ไม่มีเทรน"); return; }
      allowBuy  = (trend > 0);
      allowSell = (trend < 0);

      //--- ยอมสวนเทรนเมื่อราคายืดออกจาก EMA30 ของ M15 ไปไกลพอ
      if(InpTrendMode == TREND_REVERSAL && ema30 > 0.0)
        {
         double px   = SymbolInfoDouble(_Symbol, SYMBOL_BID);
         double dist = InpReversalDistPts * g_scale * _Point;

         if(trend < 0 && (ema30 - px) >= dist) allowBuy  = true;   // ลงลึกมาก -> รับกลับได้
         if(trend > 0 && (px - ema30) >= dist) allowSell = true;   // ขึ้นแรงมาก -> สวนได้
        }
     }

   //--- แนวรับแนวต้าน H1
   if(InpSRMode != SR_OFF)
     {
      double px = SymbolInfoDouble(_Symbol, SYMBOL_BID);
      double sup = 0.0, res = 0.0;
      if(GetNearestSR(px, sup, res))
        {
         double nearDist = InpSRNearPts * g_scale * _Point;
         bool nearSup = (sup > 0.0 && px - sup <= nearDist);
         bool nearRes = (res > 0.0 && res - px <= nearDist);
         if(InpSRMode == SR_BLOCK)
           {
            if(nearRes) allowBuy  = false;
            if(nearSup) allowSell = false;
           }
         else
           {
            if(!nearSup) allowBuy  = false;
            if(!nearRes) allowSell = false;
           }
         if(InpVerboseLog)
            PrintFormat("SR sup=%.2f res=%.2f px=%.2f nearSup=%d nearRes=%d buy=%d sell=%d",
                        sup, res, px, (int)nearSup, (int)nearRes, (int)allowBuy, (int)allowSell);
        }
     }

   //--- M15 EMA200 : BUY เฉพาะเหนือเส้น / SELL เฉพาะใต้เส้น
   if(InpMacro200 && hEma200M15 != INVALID_HANDLE)
     {
      double e2[];
      MqlRates m[];
      ArraySetAsSeries(m, true);
      if(CopyBuffer(hEma200M15, 0, 1, 1, e2) == 1 && CopyRates(_Symbol, InpTrendTF, 0, 2, m) == 2)
        {
         if(m[1].close < e2[0]) allowBuy  = false;
         if(m[1].close > e2[0]) allowSell = false;
        }
     }
   bool nearBandBuy  = Band200Test(true);
   bool nearBandSell = Band200Test(false);

   //--- ให้ background M3 ตรงกับทิศที่จะเข้า (ถ้าเปิดใช้)
   bool m3Buy = true, m3Sell = true;
   if(InpUseM3Trend)
     {
      int t3 = GetEntryTFTrend();
      if(t3 >= 0) m3Sell = false;
      if(t3 <= 0) m3Buy  = false;
     }

   if(allowBuy)
     {
      ENUM_PATTERN p = DetectBullish();
      bool m3ok = m3Buy || (p == PAT_STAR && !InpM3ForStar) || (InpBand200Entry && nearBandBuy);
      if(p != PAT_NONE)
         Why(StringFormat("BUY pat=%d m3ok=%d sto=%d", (int)p, (int)m3ok, (int)StochInZone(true)));
      if(p != PAT_NONE && m3ok && StochInZone(true) && EmaTouchOK(true))
        {
         if(OpenTrade(ORDER_TYPE_BUY, p, nearBandBuy))
           {
            lastTradeBar = bt;
            return;
           }
        }
     }

   if(allowSell)
     {
      ENUM_PATTERN p = DetectBearish();
      bool m3ok = m3Sell || (p == PAT_STAR && !InpM3ForStar) || (InpBand200Entry && nearBandSell);
      if(p != PAT_NONE)
         Why(StringFormat("SELL pat=%d m3ok=%d sto=%d", (int)p, (int)m3ok, (int)StochInZone(false)));
      if(p != PAT_NONE && m3ok && StochInZone(false) && EmaTouchOK(false))
        {
         if(OpenTrade(ORDER_TYPE_SELL, p, nearBandSell))
            lastTradeBar = bt;
        }
     }
  }

//--- ราคาทดสอบโซน EMA200 Band (High/Low) ของ M3 ใน 3 แท่งล่าสุด (เหมือน Plan B)
bool Band200Test(const bool isBuy)
  {
   if(hE200HiM3 == INVALID_HANDLE || hE200LoM3 == INVALID_HANDLE) return(false);
   double eh[], el[];
   if(CopyBuffer(hE200HiM3, 0, 1, 1, eh) < 1) return(false);
   if(CopyBuffer(hE200LoM3, 0, 1, 1, el) < 1) return(false);
   MqlRates r[];
   ArraySetAsSeries(r, true);
   if(CopyRates(_Symbol, InpEntryTF, 0, 4, r) < 4) return(false);

   double buf = InpBand200BufPts * g_scale * _Point;
   bool touched = false;
   for(int i = 1; i <= 3; i++)
      if(r[i].low <= eh[0] + buf && r[i].high >= el[0] - buf) { touched = true; break; }
   if(!touched) return(false);
   return(isBuy ? (r[1].close >= el[0] - buf) : (r[1].close <= eh[0] + buf));
  }

//--- DEBUG : บอกเหตุผลที่ไม่เข้าไม้ (พิมพ์เฉพาะตอนเปิด InpVerboseLog)
void Why(const string reason)
  {
   if(InpVerboseLog) PrintFormat("WHY %s", reason);
  }

//+------------------------------------------------------------------+
//| DEBUG : พิมพ์สภาพของแท่งที่ปิดแล้ว เพื่อไล่ว่าเงื่อนไขไหนตัดไม้    |
//+------------------------------------------------------------------+
void DumpBar()
  {
   MqlRates r[];
   ArraySetAsSeries(r, true);
   if(CopyRates(_Symbol, InpEntryTF, 0, 4, r) < 4) return;

   double e30 = 0.0;
   int t15 = GetTrendEx(e30);
   int t3  = GetEntryTFTrend();

   double m[];
   double sto = -1.0;
   if(CopyBuffer(hStoch, MAIN_LINE, 1, 1, m) == 1) sto = m[0];

   //--- ตรวจ engulfing แบบดิบ (ยังไม่กรองความยาวแท่ง)
   bool coverB = (InpEngulfMode == ENGULF_STRICT) ? (r[1].open <= r[2].close) : (Body(r[1]) >= Body(r[2]));
   bool coverS = (InpEngulfMode == ENGULF_STRICT) ? (r[1].open >= r[2].close) : (Body(r[1]) >= Body(r[2]));
   bool rawBull = IsBull(r[1]) && IsBear(r[2]) && (r[1].close > r[2].open) && coverB;
   bool rawBear = IsBear(r[1]) && IsBull(r[2]) && (r[1].close < r[2].open) && coverS;

   double opp = (r[2].high - r[2].low) / _Point;   // ความยาวแท่งก่อนหน้า

   PrintFormat("DBG %s O%.3f H%.3f L%.3f C%.3f | M15=%+d M3=%+d | Sto=%.1f | rawBull=%d rawBear=%d | prevLen=%.0f (ลิมิต %d) | spread=%d",
               TimeToString(r[1].time, TIME_DATE | TIME_MINUTES),
               r[1].open, r[1].high, r[1].low, r[1].close,
               t15, t3, sto, (int)rawBull, (int)rawBear,
               opp, OpposePts(), (int)SymbolInfoInteger(_Symbol, SYMBOL_SPREAD));
  }

//+------------------------------------------------------------------+
//| มูลค่า 1 point ต่อ 1 lot (สกุลเงินบัญชี)                          |
//+------------------------------------------------------------------+
double PointValuePerLot()
  {
   double tickValue = SymbolInfoDouble(_Symbol, SYMBOL_TRADE_TICK_VALUE);
   double tickSize  = SymbolInfoDouble(_Symbol, SYMBOL_TRADE_TICK_SIZE);
   if(tickSize <= 0.0) return(0.0);
   return(tickValue * (_Point / tickSize));
  }

//+------------------------------------------------------------------+
//| ตอนนี้ผันผวนสูงกว่าปกติไหม (ATR ปัจจุบัน เทียบ ค่าเฉลี่ยตัวเอง)  |
//+------------------------------------------------------------------+
bool VolatilityHigh(void)
  {
   if(!InpUseVolSizing || hAtrVol == INVALID_HANDLE) return(false);

   int n = InpVolAvgBars;
   if(n < 20) n = 20;

   double a[];
   if(CopyBuffer(hAtrVol, 0, 1, n, a) < n) return(false);

   double sum = 0.0;
   for(int i = 0; i < n; i++) sum += a[i];
   double avg = sum / n;
   if(avg <= 0.0) return(false);

   double cur = a[n - 1];        // ตัวสุดท้าย = ใหม่สุด
   return(cur > avg * InpVolHighMult);
  }

//+------------------------------------------------------------------+
//| คำนวณ lot ที่จะใช้เข้าไม้                                        |
//|  LOT_RISK_PCT : lot = (balance * risk%) / (SL points * ค่า/point) |
//+------------------------------------------------------------------+
double CalcLot(const int slPts)
  {
   double lot = InpLots;

   if(InpLotMode == LOT_RISK_PCT)
     {
      double pv = PointValuePerLot();
      if(pv <= 0.0 || slPts <= 0)
        {
         Print("เตือน: คำนวณ lot ตาม % ไม่ได้ ใช้ lot คงที่แทน");
         return(NormalizeLot(InpLots));
        }

      double balance  = AccountInfoDouble(ACCOUNT_BALANCE);
      double riskMoney = balance * InpRiskPercent / 100.0;
      lot = riskMoney / (slPts * pv);
     }

   //--- ผันผวนสูง -> ลดขนาดไม้
   if(VolatilityHigh())
     {
      lot *= InpVolLotFactor;
      if(InpVerboseLog) PrintFormat("ผันผวนสูง ลด lot เหลือ %.2f", lot);
     }

   if(InpMaxLot > 0.0 && lot > InpMaxLot)
     {
      PrintFormat("lot %.2f เกินเพดาน ตัดเหลือ %.2f", lot, InpMaxLot);
      lot = InpMaxLot;
     }

   return(NormalizeLot(lot));
  }

//+------------------------------------------------------------------+
//| หยุดเทรดถ้าขาดทุนวันนี้เกินเพดาน                                 |
//+------------------------------------------------------------------+
//+------------------------------------------------------------------+
//| หยุดหลังแพ้ : นับไม้ที่ปิดขาดทุนติดกัน แล้วพักตามที่ตั้งไว้        |
//+------------------------------------------------------------------+
datetime g_alLastDeal  = 0;    // เวลาไม้ล่าสุดที่นับไปแล้ว
int      g_alLosses    = 0;    // แพ้ติดกันกี่ไม้
datetime g_alPauseTill = 0;    // พักถึงเมื่อไหร่ (0 = ไม่พัก)
int      g_alStopDay   = -1;   // วันที่สั่งหยุดยาว (day_of_year)

void AfterLossUpdate()
  {
   if(InpStopAfterLosses <= 0) return;

   //--- อ่านดีลที่ปิดไม้ของเราตั้งแต่ดีลล่าสุดที่เคยนับ
   datetime from = (g_alLastDeal > 0) ? g_alLastDeal : (TimeCurrent() - 7 * 24 * 3600);
   if(!HistorySelect(from, TimeCurrent())) return;

   int total = HistoryDealsTotal();
   for(int i = 0; i < total; i++)
     {
      ulong tk = HistoryDealGetTicket(i);
      if(tk == 0) continue;
      if(HistoryDealGetInteger(tk, DEAL_MAGIC) != InpMagic) continue;
      if(HistoryDealGetInteger(tk, DEAL_ENTRY) != DEAL_ENTRY_OUT) continue;
      datetime dt = (datetime)HistoryDealGetInteger(tk, DEAL_TIME);
      if(dt <= g_alLastDeal) continue;

      double pl = HistoryDealGetDouble(tk, DEAL_PROFIT)
                  + HistoryDealGetDouble(tk, DEAL_SWAP)
                  + HistoryDealGetDouble(tk, DEAL_COMMISSION);
      g_alLastDeal = dt;

      if(pl < 0.0)
        {
         g_alLosses++;
         if(g_alLosses >= InpStopAfterLosses)
           {
            if(InpAfterLossMode == AL_STOP_DAY)
              {
               MqlDateTime d;
               TimeToStruct(ThaiTime(), d);
               g_alStopDay = d.day_of_year;
              }
            else
               g_alPauseTill = dt + (datetime)(InpPauseBars * PeriodSeconds(InpEntryTF));
            g_alLosses = 0;
           }
        }
      else
         g_alLosses = 0;
     }
  }

bool AfterLossOK()
  {
   if(InpStopAfterLosses <= 0) return(true);
   if(g_alPauseTill > 0)
     {
      if(TimeCurrent() < g_alPauseTill) return(false);
      g_alPauseTill = 0;
     }
   if(g_alStopDay >= 0)
     {
      MqlDateTime d;
      TimeToStruct(ThaiTime(), d);
      if(d.day_of_year == g_alStopDay) return(false);
      g_alStopDay = -1;
     }
   return(true);
  }

//+------------------------------------------------------------------+
//| Check if EA trading is allowed by Remote Web Dashboard           |
//+------------------------------------------------------------------+
bool IsRemoteTradingAllowed()
  {
   string filename = "ea_control.json";
   if(!FileIsExist(filename, FILE_COMMON)) return(true);

   int h = FileOpen(filename, FILE_READ | FILE_TXT | FILE_COMMON);
   if(h == INVALID_HANDLE) return(true);

   string text = "";
   while(!FileIsEnding(h))
     {
      text += FileReadString(h);
     }
   FileClose(h);

   long login = AccountInfoInteger(ACCOUNT_LOGIN);
   string keyDisabled1 = "\"" + IntegerToString(login) + "\": false";
   string keyDisabled2 = "\"" + IntegerToString(login) + "\":false";
   string allDisabled1 = "\"all\": false";
   string allDisabled2 = "\"all\":false";

   if(StringFind(text, keyDisabled1) >= 0 || StringFind(text, keyDisabled2) >= 0 ||
      StringFind(text, allDisabled1) >= 0 || StringFind(text, allDisabled2) >= 0)
     {
      return(false);
     }
   return(true);
  }

bool DailyLossOK()
  {
   if(InpMaxDailyLossPct <= 0.0) return(true);

   MqlDateTime dt;
   TimeToStruct(TimeCurrent(), dt);
   dt.hour = 0; dt.min = 0; dt.sec = 0;
   datetime dayStart = StructToTime(dt);

   if(!HistorySelect(dayStart, TimeCurrent())) return(true);

   double pnl = 0.0;
   for(int i = HistoryDealsTotal() - 1; i >= 0; i--)
     {
      ulong tk = HistoryDealGetTicket(i);
      if(tk == 0) continue;
      if(HistoryDealGetString(tk, DEAL_SYMBOL) != _Symbol) continue;
      if(HistoryDealGetInteger(tk, DEAL_MAGIC) != InpMagic) continue;
      if(HistoryDealGetInteger(tk, DEAL_ENTRY) != DEAL_ENTRY_OUT) continue;

      pnl += HistoryDealGetDouble(tk, DEAL_PROFIT)
           + HistoryDealGetDouble(tk, DEAL_SWAP)
           + HistoryDealGetDouble(tk, DEAL_COMMISSION);
     }

   double limit = AccountInfoDouble(ACCOUNT_BALANCE) * InpMaxDailyLossPct / 100.0;
   if(pnl <= -limit)
     {
      PrintFormat("หยุดเทรดวันนี้: ขาดทุน %.2f เกินเพดาน %.2f", pnl, limit);
      return(false);
     }
   return(true);
  }

//+------------------------------------------------------------------+
//| สรุปความเสี่ยง / เวลา ตอน EA เริ่มทำงาน                          |
//+------------------------------------------------------------------+
void ReportRiskAndTime()
  {
   double lot = CalcLot(SLPts());
   double pv  = PointValuePerLot();
   string cur = AccountInfoString(ACCOUNT_CURRENCY);

   if(InpLotMode == LOT_RISK_PCT)
      PrintFormat("โหมด lot: เสี่ยง %.2f%% ของ balance %.2f %s -> lot ปัจจุบัน %.2f (เพดาน %.2f)",
                  InpRiskPercent, AccountInfoDouble(ACCOUNT_BALANCE), cur, lot, InpMaxLot);
   else
      PrintFormat("โหมด lot: คงที่ %.2f", lot);

   if(pv > 0.0)
      PrintFormat("เงินต่อไม้ที่ %.2f lot : เสี่ยง %.2f %s (SL %d pt) | กำไร %.2f %s (TP %d pt)",
                  lot, SLPts() * pv * lot, cur, SLPts(),
                  TPPts() * pv * lot, cur, TPPts());
   else
      Print("เตือน: อ่าน tick value ไม่ได้ คำนวณเงินต่อไม้ไม่ได้");

   PrintFormat("แท่งฝั่งตรงข้ามยาวเกิน %d pt (~%.2f %s ที่ %.2f lot) = ข้ามไม้",
               OpposePts(), OpposePts() * pv * lot, cur, lot);

   if(InpUseTimeFilter)
      PrintFormat("เวลา server=%s | เวลาไทย=%s | ช่วงเทรด(ไทย): %s %s %s",
                  TimeToString(TimeCurrent(), TIME_DATE | TIME_MINUTES),
                  TimeToString(ThaiTime(), TIME_DATE | TIME_MINUTES),
                  InpSession1, InpSession2, InpSession3);
   else
      Print("Time filter: ปิด (เทรดได้ตลอดเวลา)");
  }

//+------------------------------------------------------------------+
//| เทรนจาก M15 : EMA7 vs EMA30 (ใช้แท่งที่ปิดแล้ว)                  |
//+------------------------------------------------------------------+
int GetTrend()
  {
   double f[], s[];
   if(CopyBuffer(hEmaFast, 0, 1, 1, f) < 1) return(0);
   if(CopyBuffer(hEmaSlow, 0, 1, 1, s) < 1) return(0);

   int dir = 0;
   if(f[0] > s[0]) dir = 1;
   else if(f[0] < s[0]) dir = -1;

   if(InpInvertTrend) dir = -dir;
   return(dir);
  }

//+------------------------------------------------------------------+
//| เทรน M15 พร้อมส่งค่า EMA30 กลับไปด้วย                            |
//+------------------------------------------------------------------+
int GetTrendEx(double &slowVal)
  {
   double f[], s[];
   slowVal = 0.0;
   if(CopyBuffer(hEmaFast, 0, 1, 1, f) < 1) return(0);
   if(CopyBuffer(hEmaSlow, 0, 1, 1, s) < 1) return(0);
   slowVal = s[0];

   int dir = 0;
   if(f[0] > s[0]) dir = 1;
   else if(f[0] < s[0]) dir = -1;
   if(InpInvertTrend) dir = -dir;
   return(dir);
  }

//+------------------------------------------------------------------+
//| แท่งสัญญาณย่อมาเตะ EMA7 หรือ EMA30 ของ TF เข้าไม้หรือยัง         |
//+------------------------------------------------------------------+
bool EmaTouchOK(const bool isBuy)
  {
   if(!InpUseEmaTouch) return(true);

   double f[], s[];
   if(CopyBuffer(hEmaFastEntry, 0, 1, 1, f) < 1) return(false);
   if(CopyBuffer(hEmaSlowEntry, 0, 1, 1, s) < 1) return(false);

   MqlRates r[];
   ArraySetAsSeries(r, true);
   if(CopyRates(_Symbol, InpEntryTF, 0, 3, r) < 3) return(false);

   double tol = InpEmaTouchPoints * g_scale * _Point;

   if(isBuy)   // ไส้ล่างต้องลงไปแตะ (หรือใกล้) เส้น
      return(r[1].low <= f[0] + tol || r[1].low <= s[0] + tol);

   return(r[1].high >= f[0] - tol || r[1].high >= s[0] - tol);
  }

//+------------------------------------------------------------------+
//| เทรนของ TF เข้าไม้ (ใช้เมื่อ InpUseM3Trend = true)                |
//+------------------------------------------------------------------+
int GetEntryTFTrend()
  {
   double f[], s[];
   if(CopyBuffer(hEmaFastEntry, 0, 1, 1, f) < 1) return(0);
   if(CopyBuffer(hEmaSlowEntry, 0, 1, 1, s) < 1) return(0);

   int dir = 0;
   if(f[0] > s[0]) dir = 1;
   else if(f[0] < s[0]) dir = -1;

   if(InpInvertTrend) dir = -dir;
   return(dir);
  }

//+------------------------------------------------------------------+
//| AR(1) : สหสัมพันธ์ของผลตอบแทนกับผลตอบแทนแท่งก่อนหน้า             |
//|   ค่าลบ = ราคาชอบเด้งกลับ (mean-reverting)                        |
//|   ค่าบวก = ราคาชอบไปต่อ (trending)                                |
//+------------------------------------------------------------------+
//+------------------------------------------------------------------+
//| หาแนวรับ (ใต้ราคา) และแนวต้าน (เหนือราคา) ที่ใกล้ที่สุด           |
//| แนว = swing high / swing low ของ InpSRTF                         |
//+------------------------------------------------------------------+
bool GetNearestSR(const double price, double &sup, double &res)
  {
   sup = 0.0;
   res = 0.0;
   int sw = MathMax(1, InpSRSwing);
   int n  = MathMax(20, InpSRLookback) + sw * 2;

   MqlRates r[];
   ArraySetAsSeries(r, true);
   if(CopyRates(_Symbol, InpSRTF, 1, n, r) < n) return(false);

   for(int i = sw; i < n - sw; i++)
     {
      bool isHigh = true, isLow = true;
      for(int k = 1; k <= sw; k++)
        {
         if(r[i].high <= r[i - k].high || r[i].high <= r[i + k].high) isHigh = false;
         if(r[i].low  >= r[i - k].low  || r[i].low  >= r[i + k].low)  isLow  = false;
        }
      for(int j = 0; j < 2; j++)
        {
         if(j == 0 && !isHigh) continue;
         if(j == 1 && !isLow)  continue;
         double lv = (j == 0) ? r[i].high : r[i].low;
         if(lv > price && (res == 0.0 || lv < res)) res = lv;
         if(lv < price && (sup == 0.0 || lv > sup)) sup = lv;
        }
     }
   return(true);
  }

double CalcAR1(void)
  {
   int n = InpRegimeBars;
   if(n < 20) n = 20;

   double c[];
   if(CopyClose(_Symbol, InpRegimeTF, 1, n + 1, c) < n + 1) return(0.0);

   //--- ผลตอบแทนรายแท่ง (c เรียงจากเก่าไปใหม่)
   double r[];
   ArrayResize(r, n);
   for(int i = 0; i < n; i++)
      r[i] = c[i + 1] - c[i];

   double mean = 0.0;
   for(int i = 0; i < n; i++) mean += r[i];
   mean /= n;

   double num = 0.0, den = 0.0;
   for(int i = 0; i < n - 1; i++)
      num += (r[i] - mean) * (r[i + 1] - mean);
   for(int i = 0; i < n; i++)
      den += (r[i] - mean) * (r[i] - mean);

   if(den <= 0.0) return(0.0);
   return(num / den);
  }

//+------------------------------------------------------------------+
//| สภาพตลาดตอนนี้ผ่านเงื่อนไขที่ตั้งไว้ไหม                          |
//+------------------------------------------------------------------+
bool RegimeOK(void)
  {
   if(InpRegimeMode == REGIME_OFF) return(true);

   double ar1 = CalcAR1();

   bool isMR    = (ar1 < InpRegimeMRThresh);
   bool isTrend = (ar1 > InpRegimeTrThresh);
   bool isNoise = (!isMR && !isTrend);

   switch(InpRegimeMode)
     {
      case REGIME_SKIP_NOISE: return(!isNoise);
      case REGIME_MR_ONLY:    return(isMR);
      case REGIME_TREND_ONLY: return(isTrend);
     }
   return(true);
  }

//+------------------------------------------------------------------+
//| ช่วงเวลาเทรด : รูปแบบ "HH:MM-HH:MM" (ว่าง = ไม่ใช้ช่องนั้น)      |
//+------------------------------------------------------------------+
bool InSession(const string sess, const int nowMin)
  {
   if(StringLen(sess) < 11) return(false);

   int h1 = (int)StringToInteger(StringSubstr(sess, 0, 2));
   int m1 = (int)StringToInteger(StringSubstr(sess, 3, 2));
   int h2 = (int)StringToInteger(StringSubstr(sess, 6, 2));
   int m2 = (int)StringToInteger(StringSubstr(sess, 9, 2));

   int a = h1 * 60 + m1;
   int b = h2 * 60 + m2;

   if(a <= b) return(nowMin >= a && nowMin <= b);
   return(nowMin >= a || nowMin <= b);          // ข้ามเที่ยงคืน
  }

//--- เวลาไทย (GMT+7) ------------------------------------------------
datetime ThaiTime()
  {
   if(InpTimeSrc == TIME_AUTO_GMT)
      return(TimeGMT() + 7 * 3600);
   return((datetime)(TimeCurrent() + (long)InpServerToThaiHours * 3600));
  }

bool TimeFilterOK()
  {
   MqlDateTime dt;
   TimeToStruct(ThaiTime(), dt);

   if(StringLen(InpSkipDows) > 0)
     {
      string d = IntegerToString(dt.day_of_week);
      if(StringFind(InpSkipDows, d) >= 0) return(false);
     }

   if(!InpUseTimeFilter) return(true);

   int nowMin = dt.hour * 60 + dt.min;

   return(InSession(InpSession1, nowMin) ||
          InSession(InpSession2, nowMin) ||
          InSession(InpSession3, nowMin));
  }

//+------------------------------------------------------------------+
//| ปิดไม้ที่ถือนานเกิน InpMaxHoldMinutes                            |
//+------------------------------------------------------------------+
void ManageOpenPositions()
  {
   if(InpMaxHoldMinutes <= 0) return;

   for(int i = PositionsTotal() - 1; i >= 0; i--)
     {
      ulong tk = PositionGetTicket(i);
      if(tk == 0) continue;
      if(PositionGetString(POSITION_SYMBOL) != _Symbol) continue;
      if(PositionGetInteger(POSITION_MAGIC) != InpMagic) continue;

      datetime opened = (datetime)PositionGetInteger(POSITION_TIME);
      if((TimeCurrent() - opened) >= (long)InpMaxHoldMinutes * 60)
        {
         PrintFormat("ปิดไม้ #%I64u : ถือครบ %d นาที", tk, InpMaxHoldMinutes);
         trade.PositionClose(tk);
        }
     }
  }

//+------------------------------------------------------------------+
//| Stochastic อยู่ในโซนหรือไม่ (ดูย้อนหลัง InpStochLookback แท่ง)   |
//+------------------------------------------------------------------+
bool StochInZone(const bool isBuy)
  {
   int bars = MathMax(1, InpStochLookback);
   double main[];
   if(CopyBuffer(hStoch, MAIN_LINE, 1, bars, main) < bars) return(false);

   for(int i = 0; i < bars; i++)
     {
      if(isBuy)  { if(main[i] <= InpStochBuyLevel)  return(true); }
      else       { if(main[i] >= InpStochSellLevel) return(true); }
     }
   return(false);
  }

//+------------------------------------------------------------------+
//| ความยาวแท่งเป็น point                                            |
//+------------------------------------------------------------------+
double CandleLenPoints(const MqlRates &r)
  {
   double len = (InpSizeMode == SIZE_BODY)
                ? MathAbs(r.open - r.close)
                : (r.high - r.low);
   return(len / _Point);
  }

bool OpposeTooLong(const MqlRates &r)
  {
   if(InpMaxOpposePoints <= 0) return(false);
   return(CandleLenPoints(r) > (double)OpposePts());
  }

bool IsBull(const MqlRates &r) { return(r.close > r.open); }
bool IsBear(const MqlRates &r) { return(r.close < r.open); }
double Body(const MqlRates &r) { return(MathAbs(r.close - r.open)); }

//+------------------------------------------------------------------+
//| หา PA ฝั่งซื้อ : Bullish Engulfing / Morning Star                |
//| index 1 = แท่งสัญญาณ (ปิดแล้ว), 2 = ก่อนหน้า, 3 = ก่อนหน้าอีก    |
//+------------------------------------------------------------------+
//--- แท่งไส้ล่างยาว (hammer) = ปฏิเสธราคาต่ำ / ไส้บนยาว = ปฏิเสธราคาสูง
bool IsPin(const MqlRates &b, const bool bullish)
  {
   double rng = b.high - b.low;
   if(rng <= 0.0) return(false);
   if(rng / _Point < (double)(InpPinMinRangePts * g_scale)) return(false);

   double body  = Body(b);
   double lowW  = MathMin(b.open, b.close) - b.low;
   double highW = b.high - MathMax(b.open, b.close);

   double wick  = bullish ? lowW  : highW;
   double other = bullish ? highW : lowW;

   return(wick >= InpPinWickRatio * body &&
          wick >= rng * InpPinWickPct / 100.0 &&
          other <= wick * 0.5);
  }

//+------------------------------------------------------------------+
//| ไส้เทียนของแท่งสัญญาณยาวเกินกำหนดหรือไม่                          |
//+------------------------------------------------------------------+
bool WickTooLong(const MqlRates &b, const bool bullish)
  {
   if(InpMaxWickPct <= 0.0) return(false);
   double body = Body(b);
   if(body <= 0.0) return(true);
   double lowW  = MathMin(b.open, b.close) - b.low;
   double highW = b.high - MathMax(b.open, b.close);
   double w = (InpWickSide == WICK_BOTH)
              ? MathMax(lowW, highW)
              : (bullish ? highW : lowW);
   return(w > body * InpMaxWickPct / 100.0);
  }

//+------------------------------------------------------------------+
//| Morning/Evening Star ที่แท่งกลางมีได้หลายแท่ง                      |
//| r[1] = แท่งสัญญาณ, แท่งกลาง = r[2..1+m], แท่งแรก = r[2+m]         |
//+------------------------------------------------------------------+
bool IsStar(const MqlRates &r[], const bool bullish)
  {
   int maxMid = MathMax(1, MathMin(3, InpStarMaxMiddle));
   for(int m = 1; m <= maxMid; m++)
     {
      int fi = 2 + m;                       // index แท่งแรก
      if(fi >= ArraySize(r)) break;
      double b1 = Body(r[fi]);
      if(b1 <= 0.0) continue;
      if(bullish ? !IsBear(r[fi]) : !IsBull(r[fi])) continue;
      if(OpposeTooLong(r[fi])) continue;

      bool midOK = true;
      for(int k = 2; k <= 1 + m; k++)
        {
         if(Body(r[k]) > b1 * (InpStarSmallBodyPct / 100.0)) { midOK = false; break; }
         if(bullish)
           { if(MathMax(r[k].open, r[k].close) >= r[fi].open) { midOK = false; break; } }
         else
           { if(MathMin(r[k].open, r[k].close) <= r[fi].open) { midOK = false; break; } }
        }
      if(!midOK) continue;

      if(bullish)
        {
         if(IsBull(r[1]) && r[1].close >= r[fi].close + b1 * (InpStarPenetration / 100.0) &&
            !(InpWickForStar && WickTooLong(r[1], true)))
            return(true);
        }
      else
        {
         if(IsBear(r[1]) && r[1].close <= r[fi].close - b1 * (InpStarPenetration / 100.0) &&
            !(InpWickForStar && WickTooLong(r[1], false)))
            return(true);
        }
     }
   return(false);
  }

//+------------------------------------------------------------------+
//| Engulfing ที่ใช้แท่งสีเดียวกันรวมกันได้ 1-3 แท่ง                  |
//| r[1] = แท่งสัญญาณ  แท่ง 1..k สีเดียวกัน  r[k+1] = แท่งที่ถูกกลืน  |
//| โค้ชสอน: ถ้าต้องใช้เกิน 3 แท่งถึงจะชนะ = ฝั่งตรงข้ามแรง ห้ามเข้า  |
//+------------------------------------------------------------------+
bool IsEngulf(const MqlRates &r[], const bool bullish)
  {
   int maxb = MathMax(1, MathMin(3, InpEngulfMaxBars));
   for(int k = 1; k <= maxb; k++)
     {
      int pi = k + 1;
      if(pi >= ArraySize(r)) break;

      //--- แท่ง 1..k ต้องเป็นสีเดียวกันทั้งหมด
      bool same = true;
      for(int i = 1; i <= k; i++)
         if(bullish ? !IsBull(r[i]) : !IsBear(r[i])) { same = false; break; }
      if(!same) continue;

      //--- แท่งที่ถูกกลืนต้องเป็นสีตรงข้ามและมีเนื้อ
      if(bullish ? !IsBear(r[pi]) : !IsBull(r[pi])) continue;
      double pb = Body(r[pi]);
      if(pb <= 0.0) continue;

      //--- ระยะรวมของกลุ่ม
      double move = bullish ? (r[1].close - r[k].open) : (r[k].open - r[1].close);
      if(move <= 0.0) continue;

      //--- ต้องชนะจริงที่แท่งนี้
      bool win = bullish ? (r[1].close > r[pi].open) : (r[1].close < r[pi].open);
      if(!win) continue;

      //--- ถ้าใช้หลายแท่ง ต้องเป็นแท่งที่ "เพิ่งชนะ" ไม่ใช่ชนะไปแล้วตั้งแต่แท่งก่อน
      if(k >= 2)
        {
         bool already = bullish ? (r[2].close > r[pi].open) : (r[2].close < r[pi].open);
         if(already) continue;
        }

      bool cover = (InpEngulfMode == ENGULF_STRICT)
                   ? (bullish ? (r[k].open <= r[pi].close) : (r[k].open >= r[pi].close))
                   : (move >= pb);
      if(!cover) continue;

      if(OpposeTooLong(r[pi])) continue;
      if(WickTooLong(r[1], bullish)) continue;
      return(true);
     }
   return(false);
  }

ENUM_PATTERN DetectBullish()
  {
   MqlRates r[];
   ArraySetAsSeries(r, true);
   if(CopyRates(_Symbol, InpEntryTF, 0, 6, r) < 6) return(PAT_NONE);

   //--- 1) Morning Star : แดงยาว -> ตัวเล็ก(1-3 แท่ง) -> เขียวกินคืน
   if(InpUseStar && IsStar(r, true))
      return(PAT_STAR);

   //--- 2) Bullish Engulfing : เขียว 1-3 แท่งรวมกันกลืนแดง
   if(InpUseEngulfing && IsEngulf(r, true))
      return(PAT_ENGULFING);

   //--- 3) Hammer : แท่งไส้ล่างยาว
   if(InpUsePin && IsPin(r[1], true))
      return(PAT_PIN);

   return(PAT_NONE);
  }

//+------------------------------------------------------------------+
//| หา PA ฝั่งขาย : Bearish Engulfing / Evening Star                 |
//+------------------------------------------------------------------+
ENUM_PATTERN DetectBearish()
  {
   MqlRates r[];
   ArraySetAsSeries(r, true);
   if(CopyRates(_Symbol, InpEntryTF, 0, 6, r) < 6) return(PAT_NONE);

   //--- 1) Evening Star : เขียวยาว -> ตัวเล็ก(1-3 แท่ง) -> แดงกินคืน
   if(InpUseStar && IsStar(r, false))
      return(PAT_STAR);

   //--- 2) Bearish Engulfing : แดง 1-3 แท่งรวมกันกลืนเขียว
   if(InpUseEngulfing && IsEngulf(r, false))
      return(PAT_ENGULFING);

   //--- 3) Shooting star / Pin bar : แท่งไส้บนยาว
   if(InpUsePin && IsPin(r[1], false))
      return(PAT_PIN);

   return(PAT_NONE);
  }

//+------------------------------------------------------------------+
bool HasOpenPosition()
  {
   for(int i = PositionsTotal() - 1; i >= 0; i--)
     {
      ulong tk = PositionGetTicket(i);
      if(tk == 0) continue;
      if(PositionGetString(POSITION_SYMBOL) == _Symbol &&
         PositionGetInteger(POSITION_MAGIC) == InpMagic)
         return(true);
     }
   return(false);
  }

//+------------------------------------------------------------------+
bool SpreadOK()
  {
   if(InpMaxSpreadPoints <= 0) return(true);
   long sp = SymbolInfoInteger(_Symbol, SYMBOL_SPREAD);
   if(sp > SpreadPts())
     {
      PrintFormat("ข้าม: spread %d > %d", (int)sp, SpreadPts());
      return(false);
     }
   return(true);
  }

//+------------------------------------------------------------------+
bool OpenTrade(const ENUM_ORDER_TYPE type, const ENUM_PATTERN pat, const bool nearBand)
  {
   double ask = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
   double bid = SymbolInfoDouble(_Symbol, SYMBOL_BID);
   int    dg  = (int)SymbolInfoInteger(_Symbol, SYMBOL_DIGITS);
   long   stopLevel = SymbolInfoInteger(_Symbol, SYMBOL_TRADE_STOPS_LEVEL);

   double price, sl = 0.0, tp = 0.0;
   int slPts = SLPts(), tpPts = TPPts();
   price = (type == ORDER_TYPE_BUY) ? ask : bid;

   //--- SL ใต้ Low / เหนือ High ของชุด Star (แท่งสัญญาณ + แท่งกลาง + แท่งแรก)
   if(InpSLUnderStar && pat == PAT_STAR)
     {
      MqlRates sr[];
      ArraySetAsSeries(sr, true);
      int look = 2 + MathMax(1, MathMin(3, InpStarMaxMiddle));
      if(CopyRates(_Symbol, InpEntryTF, 0, look + 2, sr) >= look + 1)
        {
         double ext = (type == ORDER_TYPE_BUY) ? sr[1].low : sr[1].high;
         for(int i = 2; i <= look; i++)
            ext = (type == ORDER_TYPE_BUY) ? MathMin(ext, sr[i].low) : MathMax(ext, sr[i].high);
         double buf = InpStarSLBufPts * g_scale * _Point;
         int dyn = (int)MathRound(((type == ORDER_TYPE_BUY) ? (price - (ext - buf)) : ((ext + buf) - price)) / _Point);
         if(dyn >= InpStarSLMinPts * g_scale && dyn <= InpStarSLMaxPts * g_scale)
           {
            slPts = dyn;
            tpPts = (int)MathRound(dyn * InpStarSLTPMult);
           }
        }
     }
   if(nearBand && InpBand200TPMult != 1.0)
      tpPts = (int)MathRound(tpPts * InpBand200TPMult);

   if(type == ORDER_TYPE_BUY)
     {
      if(slPts > 0) sl = NormalizeDouble(price - slPts * _Point, dg);
      if(tpPts > 0) tp = NormalizeDouble(price + tpPts * _Point, dg);
     }
   else
     {
      if(slPts > 0) sl = NormalizeDouble(price + slPts * _Point, dg);
      if(tpPts > 0) tp = NormalizeDouble(price - tpPts * _Point, dg);
     }

   //--- ตรวจระยะขั้นต่ำของโบรก
   if(stopLevel > 0)
     {
      if((sl != 0.0 && MathAbs(price - sl) / _Point < (double)stopLevel) ||
         (tp != 0.0 && MathAbs(price - tp) / _Point < (double)stopLevel))
        {
         PrintFormat("ข้าม: SL/TP ใกล้เกิน stops level (%d points)", (int)stopLevel);
         return(false);
        }
     }

   double lot = CalcLot(slPts);
   if(lot <= 0.0)
     {
      Print("ข้าม: lot ที่คำนวณได้เป็น 0 (ทุนน้อยเกินไปสำหรับ SL นี้)");
      return(false);
     }
   string cmt = InpComment + "-" + (pat == PAT_ENGULFING ? "ENG" : (pat == PAT_STAR ? "STAR" : "PIN"));

   bool ok = (type == ORDER_TYPE_BUY)
             ? trade.Buy(lot, _Symbol, 0.0, sl, tp, cmt)
             : trade.Sell(lot, _Symbol, 0.0, sl, tp, cmt);

   if(ok && InpLogFeatures)
     {
      double sup = 0.0, res = 0.0;
      GetNearestSR(price, sup, res);
      bool buy = (type == ORDER_TYPE_BUY);
      double ahead  = buy ? (res - price) : (price - sup);
      double behind = buy ? (price - sup) : (res - price);
      double pts = g_scale * _Point;

      double atrv = 0.0;
      int hA = iATR(_Symbol, InpTrendTF, 14);
      double ab[];
      if(hA != INVALID_HANDLE && CopyBuffer(hA, 0, 0, 1, ab) == 1) atrv = ab[0];
      IndicatorRelease(hA);

      double e200 = 0.0;
      int hE = iMA(_Symbol, InpTrendTF, 200, 0, MODE_EMA, PRICE_CLOSE);
      double eb[];
      if(hE != INVALID_HANDLE && CopyBuffer(hE, 0, 0, 1, eb) == 1) e200 = eb[0];
      IndicatorRelease(hE);

      double f[], sl2[];
      double ef = 0.0, es = 0.0;
      if(CopyBuffer(hEmaFast, 0, 1, 1, f) == 1) ef = f[0];
      if(CopyBuffer(hEmaSlow, 0, 1, 1, sl2) == 1) es = sl2[0];

      PrintFormat("FEAT side=%s ahead=%.0f behind=%.0f atr=%.0f emadist=%.0f withtrend=%d above200=%d",
                  buy ? "BUY" : "SELL",
                  (ahead > 0 ? ahead / pts : 99999.0),
                  (behind > 0 ? behind / pts : 99999.0),
                  atrv / pts,
                  MathAbs(price - e200) / pts,
                  (int)((ef > es) == buy),
                  (int)((price > e200) == buy));
     }

   if(!ok)
      PrintFormat("ส่งออเดอร์ไม่สำเร็จ ret=%d %s", trade.ResultRetcode(),
                  trade.ResultRetcodeDescription());
   else
      PrintFormat("%s %.2f lot @%.*f SL=%.*f TP=%.*f [%s]",
                  (type == ORDER_TYPE_BUY ? "BUY" : "SELL"), lot,
                  dg, price, dg, sl, dg, tp, cmt);

   return(ok);
  }

//+------------------------------------------------------------------+
double NormalizeLot(double lot)
  {
   double mn   = SymbolInfoDouble(_Symbol, SYMBOL_VOLUME_MIN);
   double mx   = SymbolInfoDouble(_Symbol, SYMBOL_VOLUME_MAX);
   double step = SymbolInfoDouble(_Symbol, SYMBOL_VOLUME_STEP);
   if(step <= 0.0) step = 0.01;

   lot = MathFloor(lot / step) * step;
   lot = MathMax(mn, MathMin(mx, lot));
   return(NormalizeDouble(lot, 2));
  }
//+------------------------------------------------------------------+
