using System;
using System.Runtime.InteropServices;
using System.Timers;
using MailTC.Support;

namespace MailTC
{
    public class ChartService : IDisposable
    {
        public const string LastReadMailTimeXmlName = "lastReadMailTime";
        public const string OrdersTicketsXmlName = "ordersTickets";
        public const string OrdersXmlName = "orders";
        
        private const int TickInterval = 3000;

        private Timer tickTimer;

        public IntPtr HWnd { get; private set; }
        private readonly HandleRef chartRef;
        private readonly UInt32 tickMsg;

        private readonly OrderProvider orderProvider;

        public ChartService(IntPtr hWnd, string login, string password, string recordId, string keySubject, double hoursToClose)
        {
            HWnd = hWnd;
            tickMsg = Functions.RegisterWindowMessage("MetaTrader4_Internal_Message");
            chartRef = new HandleRef(this, hWnd);

            tickTimer = new Timer(TickInterval);
            tickTimer.Elapsed += TickTimerOnElapsed;
            tickTimer.Start();

            orderProvider = new OrderProvider(login, password, recordId, keySubject, hoursToClose);
        }

        public Order[] GetReadyOrders()
        {
            return orderProvider.GetReadyOrders();
        }

        public void RemoveOrder(int hashCode)
        {
            orderProvider.RemoveOrder(hashCode);
        }

        private void TickTimerOnElapsed(object sender, ElapsedEventArgs e)
        {
            Functions.PostMessage(chartRef, tickMsg, (IntPtr)2, IntPtr.Zero);
        }

        public void Dispose()
        {
            if (tickTimer != null)
            {
                tickTimer.Stop();
                tickTimer = null;
            }
            if (orderProvider != null)
                orderProvider.Dispose();
        }
    }
}