#property link          "https://www.earnforex.com/metatrader-indicators/stochastic-alert/"
#property version       "1.04"
#property strict
#property copyright     "EarnForex.com - 2019-2025"
#property description   "The Stochastic Indicator With Alert"
#property description   ""
#property description   "WARNING: Use this software at your own risk."
#property description   "The creator of these plugins cannot be held responsible for any damage or loss."
#property description   ""
#property description   "Find More on EarnForex.com"
#property icon          "\\Files\\EF-Icon-64x64px.ico"

#property indicator_separate_window
#property indicator_buffers 2
#property indicator_color1 clrBlue
#property indicator_type1 DRAW_LINE
#property indicator_label1 "Stochastic Main"
#property indicator_color2 clrRed
#property indicator_type2 DRAW_LINE
#property indicator_label2 "Stochastic Signal"
#property indicator_minimum 0
#property indicator_maximum 100

#include <MQLTA ErrorHandling.mqh>
#include <MQLTA Utils.mqh>

enum ENUM_TRADE_SIGNAL
{
    SIGNAL_BUY = 1,   //BUY
    SIGNAL_SELL = -1, //SELL
    SIGNAL_NEUTRAL = 0 //NEUTRAL
};

enum ENUM_CANDLE_TO_CHECK
{
    CURRENT_CANDLE,  //CURRENT CANDLE
    CLOSED_CANDLE    //PREVIOUS CANDLE
};

enum ENUM_STOCH_TO_WATCH
{
    STOCH_MAIN = 0,   //STOCHASTIC MAIN LINE
    STOCH_SIGNAL = 1  //STOCHASTIC SIGNAL LINE
};

enum ENUM_ALERT_SIGNAL
{
    STOCH_MAIN_SIGNAL_CROSS,  //STOCHASTIC MAIN AND SIGNAL CROSS
    STOCH_BREAK_OUT,          //STOCHASTIC BREAKS OUT THE LIMITS
    STOCH_COMES_IN            //STOCHASTIC RETURNS IN THE LIMITS
};

enum ENUM_ARROW_SIZE
{
    ARROW_SIZE_VERYSMALL = 1, //VERY SMALL
    ARROW_SIZE_SMALL = 2,     //SMALL
    ARROW_SIZE_MEDIUM = 3,    //MEDIUM
    ARROW_SIZE_BIG = 4,       //BIG
    ARROW_SIZE_VERYBIG = 5,   //VERY BIG
};

input string Comment1 = "========================";      //MQLTA Stochastic With Alert
input string IndicatorName = "MQLTA-STOCHWA";            //Indicator Short Name

input string Comment2 = "========================";      //Indicator Parameters
input int StochKPeriod = 5;                              //Stochastic K Period
input int StochDPeriod = 3;                              //Stochastic D Period
input int StochSlowing = 3;                              //Stochastic Slowing
input ENUM_MA_METHOD StochMAMethod = MODE_SMA;           //Stochastic MA Method
input ENUM_STO_PRICE StochPriceField = 0;                //Stochastic Price Field
input int StochHighLimit = 80;                           //Stochastic High Limit
input int StochLowLimit = 20;                            //Stochastic Low Limit
input ENUM_STOCH_TO_WATCH AlertLine = STOCH_MAIN;        //Stochastic Line To Watch For Alerts
input ENUM_ALERT_SIGNAL AlertSignal = STOCH_MAIN_SIGNAL_CROSS; //Alert Signal When
input ENUM_CANDLE_TO_CHECK CandleToCheck = CURRENT_CANDLE; //Candle To Use For Analysis
input int BarsToScan = 500;                                // Number Of Candles To Analyze (0 = All)

input string Comment_3 = "====================";   //Notification Options
extern bool EnableNotify = false;                  //Enable Notifications Feature
extern bool SendAlert = true;                      //Send Alert Notification
extern bool SendApp = false;                       //Send Notification to Mobile
extern bool SendEmail = false;                     //Send Notification via Email
input int WaitTimeNotify = 5;                      //Wait time between notifications (Minutes)

input string Comment_4 = "====================";     //Drawing Options
input bool EnableDrawArrows = true;                  //Draw Signal Arrows
input int ArrowBuy = 241;                            //Buy Arrow Code
input int ArrowSell = 242;                           //Sell Arrow Code
input ENUM_ARROW_SIZE ArrowSize = ARROW_SIZE_MEDIUM; //Arrow Size
input bool NoWindow = false;                         //Disable Indicator Window?

double BufferMain[];
double BufferSignal[];

datetime LastNotificationTime;
int Shift = 0;

int OnInit()
{
    string name = IndicatorName + " - Stoch - (" + string(StochKPeriod) + "," + string(StochDPeriod) + "," + string(StochSlowing) + ") - ";
    IndicatorSetString(INDICATOR_SHORTNAME, name);

    OnInitInitialization();
    if (!OnInitPreChecksPass())
    {
        return INIT_FAILED;
    }

    InitializeBuffers();

    if (NoWindow)
    {
        IndicatorSetInteger(INDICATOR_LEVELS, 0);
        int window = WindowFind(name);
        bool b = ChartSetInteger(ChartID(), CHART_HEIGHT_IN_PIXELS, window, 4); // Doesn't go below 4.
    }

    return INIT_SUCCEEDED;
}

int OnCalculate(const int rates_total,
                const int prev_calculated,
                const datetime &time[],
                const double &open[],
                const double &high[],
                const double &low[],
                const double &close[],
                const long &tick_volume[],
                const long &volume[],
                const int &spread[])
{
    if (rates_total < StochKPeriod)
    {
        Print("Not Enough Historical Candles");
        return 0;
    }

    bool IsNewCandle = CheckIfNewCandle();
    int counted_bars = 0;
    if (prev_calculated > 0) counted_bars = prev_calculated - 1;

    if (counted_bars < 0) return -1;
    if (counted_bars > 0) counted_bars--;
    int limit = rates_total - counted_bars;
    if ((BarsToScan > 0) && (limit > BarsToScan))
    {
        limit = BarsToScan;
        if (rates_total < BarsToScan + StochKPeriod) limit = BarsToScan - 2 - StochKPeriod;
        if (limit <= 0)
        {
            Print("Need more historical data.");
            return 0;
        }
    }
    if (limit > rates_total - 2 - StochKPeriod) limit = rates_total - 2 - StochKPeriod;

    for (int i = limit; i >= 0; i--)
    {
        BufferMain[i] = iStochastic(Symbol(), PERIOD_CURRENT, StochKPeriod, StochDPeriod, StochSlowing, StochMAMethod, StochPriceField, MODE_MAIN, i);
        BufferSignal[i] = iStochastic(Symbol(), PERIOD_CURRENT, StochKPeriod, StochDPeriod, StochSlowing, StochMAMethod, StochPriceField, MODE_SIGNAL, i);
    }

    if ((IsNewCandle) || (prev_calculated == 0))
    {
        if (EnableDrawArrows) DrawArrows(limit);
        CleanUpOldArrows();
    }

    if (EnableDrawArrows) DrawArrow(0);

    if (EnableNotify) NotifyHit();

    return rates_total;
}

void OnDeinit(const int reason)
{
    CleanChart();
}

void OnInitInitialization()
{
    LastNotificationTime = TimeCurrent();
    Shift = CandleToCheck;
}

bool OnInitPreChecksPass()
{
    if ((StochDPeriod <= 0) || (StochHighLimit > 100) || (StochHighLimit < 0) || (StochLowLimit > 100) || (StochLowLimit < 0) || (StochLowLimit > StochHighLimit) || (StochKPeriod <= 0) || (StochSlowing <= 0))
    {
        Print("Wrong input parameter");
        return false;
    }
    return true;
}

void CleanChart()
{
    ObjectsDeleteAll(ChartID(), IndicatorName);
}

void InitializeBuffers()
{
    SetIndexBuffer(0, BufferMain);
    SetIndexDrawBegin(0, StochKPeriod);
    SetIndexBuffer(1, BufferSignal);
    SetIndexDrawBegin(1, StochSlowing);
    SetLevelValue(0, (double)StochLowLimit);
    SetLevelValue(1, (double)StochHighLimit);
}

datetime NewCandleTime = TimeCurrent();
bool CheckIfNewCandle()
{
    if (NewCandleTime == iTime(Symbol(), 0, 0)) return false;
    else
    {
        NewCandleTime = iTime(Symbol(), 0, 0);
        return true;
    }
}

// Check if it is a trade signal: 0 = Neutral, 1 = Buy, -1 = Sell.
ENUM_TRADE_SIGNAL IsSignal(int i)
{
    int j = i + Shift;
    if (AlertLine == STOCH_MAIN)
    {
        if (AlertSignal == STOCH_BREAK_OUT)
        {
            if ((BufferMain[j + 1] < StochHighLimit) && (BufferMain[j] > StochHighLimit)) return SIGNAL_BUY;
            if ((BufferMain[j + 1] > StochLowLimit) && (BufferMain[j] < StochLowLimit)) return SIGNAL_SELL;
        }
        else if (AlertSignal == STOCH_COMES_IN)
        {
            if ((BufferMain[j + 1] < StochLowLimit) && (BufferMain[j] > StochLowLimit)) return SIGNAL_BUY;
            if ((BufferMain[j + 1] > StochHighLimit) && (BufferMain[j] < StochHighLimit)) return SIGNAL_SELL;
        }
    }
    else if (AlertLine == STOCH_SIGNAL)
    {
        if (AlertSignal == STOCH_BREAK_OUT)
        {
            if ((BufferSignal[j + 1] < StochHighLimit) && (BufferSignal[j] > StochHighLimit)) return SIGNAL_BUY;
            if ((BufferSignal[j + 1] > StochLowLimit) && (BufferSignal[j] < StochLowLimit)) return SIGNAL_SELL;
        }
        else if (AlertSignal == STOCH_COMES_IN)
        {
            if ((BufferSignal[j + 1] < StochLowLimit) && (BufferSignal[j] > StochLowLimit)) return SIGNAL_BUY;
            if ((BufferSignal[j + 1] > StochHighLimit) && (BufferSignal[j] < StochHighLimit)) return SIGNAL_SELL;
        }
    }
    if (AlertSignal == STOCH_MAIN_SIGNAL_CROSS)
    {
        if ((BufferMain[j + 1] < BufferSignal[j + 1]) && (BufferMain[j] > BufferSignal[j])) return SIGNAL_BUY;
        if ((BufferMain[j + 1] > BufferSignal[j + 1]) && (BufferMain[j] < BufferSignal[j])) return SIGNAL_SELL;
    }

    return SIGNAL_NEUTRAL;
}

datetime LastNotification = TimeCurrent() - WaitTimeNotify * 60;
void NotifyHit()
{
    if ((!EnableNotify) || (TimeCurrent() < LastNotification + WaitTimeNotify * 60)) return;
    if ((!SendAlert) && (!SendApp) && (!SendEmail)) return;
    if (Time[0] == LastNotificationTime) return;
    ENUM_TRADE_SIGNAL Signal = IsSignal(0);
    if (Signal == SIGNAL_NEUTRAL) return;
    string EmailSubject = IndicatorName + " " + Symbol() + " Notification";
    string EmailBody = AccountCompany() + " - " + AccountName() + " - " + IntegerToString(AccountNumber()) + "\r\n" + IndicatorName + " Notification for " + Symbol() + " @ " + EnumToString((ENUM_TIMEFRAMES)Period()) + "\r\n";
    string AlertText = IndicatorName + " - " + Symbol() + " @ " + EnumToString((ENUM_TIMEFRAMES)Period()) + " ";
    string AppText = AccountCompany() + " - " + AccountName() + " - " + IntegerToString(AccountNumber()) + " - " + IndicatorName + " - " + Symbol() + " @ " + EnumToString((ENUM_TIMEFRAMES)Period()) + " - ";
    string Text = "";

    Text += "The Stochastic indicator triggered a signal: " + EnumToString(Signal);

    EmailBody += Text;
    AlertText += Text;
    AppText += Text;
    if (SendAlert) Alert(AlertText);
    if (SendEmail)
    {
        if (!SendMail(EmailSubject, EmailBody)) Print("Error sending email " + IntegerToString(GetLastError()));
    }
    if (SendApp)
    {
        if (!SendNotification(AppText)) Print("Error sending notification " + IntegerToString(GetLastError()));
    }
    LastNotification = TimeCurrent();
}

void DrawArrows(int limit)
{
    for (int i = limit - 1; i >= 1; i--)
    {
        DrawArrow(i);
    }
}

void DrawArrow(int i)
{
    RemoveArrowCurr(i);
    ENUM_TRADE_SIGNAL Signal = IsSignal(i);
    if (Signal == SIGNAL_NEUTRAL) return;
    datetime ArrowDate = iTime(Symbol(), 0, i);
    string ArrowName = IndicatorName + "-ARWS-" + IntegerToString(ArrowDate);
    double ArrowPrice = 0;
    int ArrowType = 0;
    color ArrowColor = 0;
    int ArrowAnchor = 0;
    string ArrowDesc = "";
    if (Signal == SIGNAL_BUY)
    {
        ArrowPrice = Low[i];
        ArrowType = ArrowBuy;
        ArrowColor = clrGreen;
        ArrowAnchor = ANCHOR_TOP;
        ArrowDesc = "BUY";
    }
    else if (Signal == SIGNAL_SELL)
    {
        ArrowPrice = High[i];
        ArrowType = ArrowSell;
        ArrowColor = clrRed;
        ArrowAnchor = ANCHOR_BOTTOM;
        ArrowDesc = "SELL";
    }
    ObjectCreate(0, ArrowName, OBJ_ARROW, 0, ArrowDate, ArrowPrice);
    ObjectSetInteger(0, ArrowName, OBJPROP_COLOR, ArrowColor);
    ObjectSetInteger(0, ArrowName, OBJPROP_SELECTABLE, false);
    ObjectSetInteger(0, ArrowName, OBJPROP_HIDDEN, true);
    ObjectSetInteger(0, ArrowName, OBJPROP_ANCHOR, ArrowAnchor);
    ObjectSetInteger(0, ArrowName, OBJPROP_ARROWCODE, ArrowType);
    ObjectSetInteger(0, ArrowName, OBJPROP_WIDTH, ArrowSize);
    ObjectSetInteger(0, ArrowName, OBJPROP_STYLE, STYLE_SOLID);
    ObjectSetInteger(0, ArrowName, OBJPROP_BGCOLOR, ArrowColor);
    ObjectSetString(0, ArrowName, OBJPROP_TEXT, ArrowDesc);
}

void RemoveArrowCurr(int i)
{
    datetime ArrowDate = iTime(Symbol(), 0, i);
    string ArrowName = IndicatorName + "-ARWS-" + IntegerToString(ArrowDate);
    ObjectDelete(0, ArrowName);
}

// Delete all arrows that are older than BarsToScan bars.
void CleanUpOldArrows()
{
    int total = ObjectsTotal(ChartID(), 0, OBJ_ARROW);
    for (int i = total - 1; i >= 0; i--)
    {
        string ArrowName = ObjectName(ChartID(), i, 0, OBJ_ARROW);
        datetime time = (datetime)ObjectGetInteger(ChartID(), ArrowName, OBJPROP_TIME);
        int bar = iBarShift(Symbol(), Period(), time);
        if ((BarsToScan > 0) && (bar >= BarsToScan)) ObjectDelete(ChartID(), ArrowName);
    }
}
//+------------------------------------------------------------------+