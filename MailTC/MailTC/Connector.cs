using System;
using System.Collections.Generic;
using System.Globalization;
using System.IO;
using System.Linq;
using System.Threading;
using MailTC.Support;
using MailTC.Xml;

namespace MailTC
{
    public static class Connector
    {
        public const string AppName = "MailTC";

        public const string MutexName = "MailTC mutex";
        private static readonly ReaderWriterLockSlim initializeLocker = new ReaderWriterLockSlim();

        private static ChartService chartService;

        // ReSharper disable ObjectCreationAsStatement
        [DllExport]
        public static int Initialize(IntPtr hWnd, string login, string password, string recordId, string keySubject,
                                     double hoursToClose)
        {
            initializeLocker.EnterWriteLock();
            if (chartService == null)
            {
                var returnState = ReturnState.Ok;
                try
                {
                    chartService = new ChartService(hWnd, login, password, recordId, keySubject, hoursToClose);
                }
                catch (Exception)
                {
                    if (chartService != null)
                    {
                        chartService.Dispose();
                        chartService = null;
                    }
                    returnState = ReturnState.WrongLoginOrPassword;
                }

                initializeLocker.ExitWriteLock();
                return (int) returnState;
            }
            initializeLocker.ExitWriteLock();
            return (int) ReturnState.AppAlreadyExist;
        }

        // ReSharper restore ObjectCreationAsStatement

        [DllExport]
        public static void Deinitialize(IntPtr hWnd)
        {           
            if (!IsChartServiceRegistered(hWnd))
                return;

            initializeLocker.EnterWriteLock();
            chartService = null;
            initializeLocker.ExitWriteLock();
            if (chartService != null)
                chartService.Dispose();
        }

        [DllExport]
        public static unsafe int LoadAllOrders(IntPtr hWnd, string recordId, int* tickets, int* openDates)
        {
            if (!IsChartServiceRegistered(hWnd))
                return 0;

            var ticketsOpenDatesString = ToXml.LoadRecord(AppName, recordId, ChartService.OrdersTicketsXmlName);

            var index = 0;
            foreach (var data in ticketsOpenDatesString.Split(new[] {";"}, StringSplitOptions.RemoveEmptyEntries)
                                                       .Select(
                                                           ticketOpenDate =>
                                                           ticketOpenDate.Split(new[] {"-"},
                                                                                StringSplitOptions.RemoveEmptyEntries))
                                                       .Where(data => data.Length == 2))
            {
                int ticket;
                if (!int.TryParse(data[0], out ticket))
                    continue;
                tickets[index] = ticket;
                int openDate;
                if (!int.TryParse(data[1], out openDate))
                    continue;
                openDates[index] = openDate;
                index++;
            }
            return index;
        }

        [DllExport]
        public static unsafe int GetReadyOrders(IntPtr hWnd, MqlStr* orderSymbols,
                                                int* orderTypes,
                                                double* orderOpenPrice,
                                                double* orderStopLoss,
                                                double* orderTakeProfit,
                                                int* closeTimes,
                                                int* hashCodes,
                                                int broketTime)
        {
            if (!IsChartServiceRegistered(hWnd))
                return 0;

            var orders = chartService.GetReadyOrders();

            var index = 0;
            foreach (var order in orders)
            {
                if (orderSymbols != null)
                    orderSymbols[index].SetString(order.Currency);
                orderTypes[index] = order.MqlOrderType;
                orderOpenPrice[index] = order.OpenPrice;
                orderStopLoss[index] = order.StopLoss;
                orderTakeProfit[index] = order.TakeProfit;
                closeTimes[index] = order.GetCloseTime(broketTime);
                hashCodes[index] = order.GetHashCode();
                index++;
            }

            return index;
        }

        [DllExport]
        public static void AddOrder(IntPtr hWnd, string recordId, int ticket, int closeDate, int hashCode)
        {
            if (!IsChartServiceRegistered(hWnd))
                return;
            chartService.RemoveOrder(hashCode);
            var ticketsOpenDatesString = ToXml.LoadRecord(AppName, recordId, ChartService.OrdersTicketsXmlName);
            ticketsOpenDatesString = string.Concat(ticketsOpenDatesString,
                                                   ticket.ToString(CultureInfo.InvariantCulture) + "-"
                                                   + closeDate.ToString(CultureInfo.InvariantCulture) + ";");
            ToXml.SaveRecord(AppName, recordId, ChartService.OrdersTicketsXmlName, ticketsOpenDatesString);
        }

        [DllExport]
        public static void RemoveOrder(IntPtr hWnd, int hashCode)
        {
            if (!IsChartServiceRegistered(hWnd))
                return;
            chartService.RemoveOrder(hashCode);
        }

        [DllExport]
        public static void RemoveOrderFromFile(IntPtr hWnd, string recordId, int ticket)
        {
            if (!IsChartServiceRegistered(hWnd))
                return;
            var ticketsOpenDatesString = ToXml.LoadRecord(AppName, recordId, ChartService.OrdersTicketsXmlName);
            var newTicketsOpenDatesString =
                ticketsOpenDatesString.Split(new[] {";"}, StringSplitOptions.RemoveEmptyEntries)
                                      .Select(
                                          ticketOpenDate =>
                                          ticketOpenDate.Split(new[] {"-"}, StringSplitOptions.RemoveEmptyEntries))
                                      .Where(data => data.Length == 2)
                                      .Where(data => data[0] != ticket.ToString(CultureInfo.InvariantCulture))
                                      .Aggregate(string.Empty,
                                                 (current, data) => current + (data[0] + "-" + data[1] + ";"));
            ToXml.SaveRecord(AppName, recordId, ChartService.OrdersTicketsXmlName, newTicketsOpenDatesString);
        }

        private static bool IsChartServiceRegistered(IntPtr hWnd)
        {
            if (chartService == null)
                return false;
            return chartService.HWnd == hWnd;
        }

        [DllExport]
        public static void DllSleep(int milliseconds)
        {
            Thread.Sleep(milliseconds);
        }
    }
}