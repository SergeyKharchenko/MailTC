using System;
using System.Collections.Generic;
using System.Globalization;
using System.Reflection;
using System.Text.RegularExpressions;
using AE.Net.Mail;
using System.Linq;
using MailTC.Support;

namespace MailTC
{
    public class MailReceiver : IDisposable
    {
        public static readonly NumberFormatInfo Provider = new NumberFormatInfo
        {
            NumberDecimalSeparator = ".",
            NumberGroupSeparator = "."
        };

        private readonly ImapClient imapClient;
        private readonly TimeSpan timeToClose;

        public MailReceiver(string server, string login, string password, TimeSpan timeToClose)
        {
            this.timeToClose = timeToClose;
            imapClient = new ImapClient(server, login, password, ImapClient.AuthMethods.Login, 993, true);
        }

        public List<Order> CheckMailInbox(string pattern, string keySubject, ref DateTime lastDate)
        {
            var orders = new List<Order>();
            var lastReadMessageDate = DateTime.MinValue;
            try
            {
                imapClient.SelectMailbox("INBOX");
                var messageCount = imapClient.GetMessageCount();
                for (var i = messageCount - 1; i >= 0; i--)
                {
                    var headerMessage = imapClient.GetMessage(i, true);
                    if (headerMessage.Date.Ticks <= lastDate.Ticks)
                        break;
                    if (lastReadMessageDate.Ticks < headerMessage.Date.Ticks)
                        lastReadMessageDate = headerMessage.Date;
                    if (!headerMessage.Subject.ToUpper().Contains(keySubject.ToUpper()))
                        continue;
                    var fullMessage = imapClient.GetMessage(i);
                    orders.AddRange(fullMessage.AlternateViews.Count > 0
                                        ? ExtractOrdersFromMailMessage(fullMessage.AlternateViews.First().Body, pattern, fullMessage.Date)
                                        : ExtractOrdersFromMailMessage(fullMessage.Body, pattern, fullMessage.Date));
                }
            }
            catch (Exception e)
            {
                //Logger.WriteLine(e.Message);
            }

            if (lastReadMessageDate > DateTime.MinValue)
                lastDate = lastReadMessageDate;
            return orders;
        }

        public List<Order> ExtractOrdersFromMailMessage(string message, string pattern, DateTime letterTime)
        {
            var orders = ExtractOrders(message, pattern);

            foreach (var order in orders)
            {
                order.CloseTime = (letterTime + timeToClose).Ticks;
                order.Raw += string.Format(" close time: {0} get time: {1}", order.CloseTime, letterTime.Ticks);
            }
            
            return orders;
        }

        public List<Order> ExtractOrders(string message, string pattern)
        {
            var orders = new List<Order>();

            var regex = new Regex(pattern, RegexOptions.Multiline);
            var matches = regex.Matches(message.ToUpper());

            try
            {
                foreach (Match match in matches)
                {
                    var order = new Order();
                    for (var i = 1; i < regex.GetGroupNames().Length; i++)
                    {
                        var name = regex.GetGroupNames()[i];
                        var property = order.GetType().GetProperty(name, BindingFlags.Public | BindingFlags.Instance);
                        if (null == property || !property.CanWrite)
                            continue;
                        var value = Convert.ChangeType(match.Groups[name].ToString(), property.PropertyType, Provider);
                        property.SetValue(order, value, null);
                    }

                    order.Raw = match.Groups[0].Value;
                    orders.Add(order);
                }
            }
            catch (Exception e)
            {
            }

            return orders;
        }

        public void Dispose()
        {
            if (imapClient != null)
            {
                imapClient.Disconnect();
                imapClient.Dispose();
            }
        }
    }
}