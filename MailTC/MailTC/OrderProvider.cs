using System;
using System.Collections.Generic;
using System.Globalization;
using System.Threading;
using System.Timers;
using MailTC.Support;
using MailTC.Xml;
using Timer = System.Timers.Timer;
using System.Linq;

namespace MailTC
{
    public class OrderProvider : IDisposable
    {
        public const int MailInterval = 5000;

        public const string MailServer = "imap.gmail.com";

        public const string OrderRegexPattern =
            "(?<CurrencyStart>[A-z]{3})\\/(?<CurrencyEnd>[A-z]{3})\\s+" +
            "(?<OrderType>ПРОДАЖА|ПОКУПКА)\\s+" +
            "ЦЕНА:\\s+(?<OpenPrice>[0-9]*\\.?[0-9]*)\\s+" +
            "LOSS:\\s+(?<StopLoss>[0-9]*\\.?[0-9]*)\\s+" +
            "PROFIT:\\s+(?<TakeProfit>[0-9]*\\.?[0-9]*)";

        public const string OrderRegexRawPattern =
            "(?<CurrencyStart>[A-z]{3})\\/(?<CurrencyEnd>[A-z]{3})\\s+" +
            "(?<OrderType>ПРОДАЖА|ПОКУПКА)\\s+" +
            "ЦЕНА:\\s+(?<OpenPrice>[0-9]*\\.?[0-9]*)\\s+" +
            "LOSS:\\s+(?<StopLoss>[0-9]*\\.?[0-9]*)\\s+" +
            "PROFIT:\\s+(?<TakeProfit>[0-9]*\\.?[0-9]*)\\s+" +
            "CLOSE TIME:\\s+(?<CloseTime>[0-9]*)\\s+" +
            "GET TIME:\\s+(?<GeyTime>[0-9]*)";

        private readonly string keySubject;

        private DateTime lastCheckedMailDate;

        private Timer mailTimer;

        private readonly List<Order> readyOrders = new List<Order>();
        private readonly ReaderWriterLockSlim ordersLocker = new ReaderWriterLockSlim();

        private readonly string recordId;   
     
        private readonly MailReceiver mailReceiver;        

        public OrderProvider(string login, string password, string recordId, string keySubject, double hoursToClose)
        {
            this.recordId = recordId;
            this.keySubject = keySubject;
            LoadLastReadMailTime();

            mailReceiver = new MailReceiver(MailServer, login, password, TimeSpan.FromHours(hoursToClose));

            LoadOrdersFromFile();

            mailTimer = new Timer(MailInterval);
            mailTimer.Elapsed += MailTimerOnElapsed;
            mailTimer.Start();
        }

        private void LoadLastReadMailTime()
        {
            var minTime = DateTime.Now - TimeSpan.FromMinutes(30);
            lastCheckedMailDate = minTime;
            var timeString = ToXml.LoadRecord(Connector.AppName, recordId, ChartService.LastReadMailTimeXmlName);
            if (!string.IsNullOrEmpty(timeString))
            {
                try
                {
                    var ticks = long.Parse(timeString);
                    lastCheckedMailDate = DateTime.FromBinary(ticks);
                }
                catch (Exception) { }
            }

            if (lastCheckedMailDate < minTime)
                lastCheckedMailDate = minTime;
        }

        public void LoadOrdersFromFile()
        {
            var ordersString = ToXml.LoadRecord(Connector.AppName, recordId, ChartService.OrdersXmlName);
            var orders = mailReceiver.ExtractOrders(ordersString, OrderRegexRawPattern);
            if (orders.Count <= 0) 
                return;
            ordersLocker.EnterWriteLock();
            readyOrders.AddRange(orders);
            ordersLocker.ExitWriteLock();
        }

        public void SaveOrdersToFile()
        {
            var ordersString = readyOrders.Aggregate("", (current, order) => current + (order.Raw + ";"));
            ToXml.SaveRecord(Connector.AppName, recordId, ChartService.OrdersXmlName, ordersString);
        }

        public Order[] GetReadyOrders()
        {
            ordersLocker.EnterWriteLock();
            var orders = readyOrders.ToArray();            
            ordersLocker.ExitWriteLock();
            return orders;
        }

        public void RemoveOrder(int hashCode)
        {
            ordersLocker.EnterWriteLock();
            readyOrders.RemoveAll(order => order.GetHashCode() == hashCode);
            ordersLocker.ExitWriteLock();
        }

        private void MailTimerOnElapsed(object sender, ElapsedEventArgs elapsedEventArgs)
        {
            mailTimer.Stop();
            lastCheckedMailDate = lastCheckedMailDate > (DateTime.Now - TimeSpan.FromMinutes(30))
                                      ? lastCheckedMailDate
                                      : DateTime.Now - TimeSpan.FromMinutes(30);

            var newOrders = mailReceiver.CheckMailInbox(OrderRegexPattern, keySubject, ref lastCheckedMailDate);
            
            if (newOrders.Count > 0)
            {
                ordersLocker.EnterWriteLock();
                if (readyOrders.Count == 0 || !newOrders.First().Equals(readyOrders.Last()))
                    readyOrders.AddRange(newOrders);
                ordersLocker.ExitWriteLock();
            }
            SaveOrdersToFile();
            ToXml.SaveRecord(Connector.AppName, recordId,
                             ChartService.LastReadMailTimeXmlName,
                             lastCheckedMailDate.Ticks.ToString(CultureInfo.InvariantCulture));
            mailTimer.Start();
        }

        public void Dispose()
        {
            if (mailTimer != null)
            {
                mailTimer.Stop();
                mailTimer = null;
            }
        }
    }
}