using System;
using System.Collections.Generic;
using MailTC.Support;

namespace MailTC
{
    public class Order
    {
        public string Currency
        {
            get { return string.Concat(CurrencyStart, CurrencyEnd); }
        }

        public int MqlOrderType
        {
            get { return OrderType == "ПОКУПКА" ? 0 : 1; }
        }

        public string CurrencyStart { get; set; }
        public string CurrencyEnd { get; set; }
        public string OrderType { get; set; }
        public double OpenPrice { get; set; }
        public double StopLoss { get; set; }
        public double TakeProfit { get; set; }
        public string Raw { get; set; }
        public long CloseTime { get; set; }
        public long GetTime { get; set; }

        public int GetCloseTime(int broketTime)
        {
            var closeDate = DateTime.FromBinary(CloseTime);
            var now = ToUnixTime(DateTime.Now);
            return ToUnixTime(closeDate) + (broketTime - now);
        }

        private static int ToUnixTime(DateTime date)
        {
            var dateTime = new DateTime(1970, 1, 1, 0, 0, 0, DateTimeKind.Utc);
            return Convert.ToInt32((date.ToUniversalTime() - dateTime).TotalSeconds);
        }

        public override bool Equals(object obj)
        {
            if (ReferenceEquals(null, obj)) return false;
            if (ReferenceEquals(this, obj)) return true;
            if (obj.GetType() != GetType()) return false;
            return Equals((Order) obj);
        }

        protected bool Equals(Order order)
        {
            return string.Equals(OrderType, order.OrderType)
                   && OpenPrice.Equals(order.OpenPrice)
                   && StopLoss.Equals(order.StopLoss)
                   && TakeProfit.Equals(order.TakeProfit)
                   && string.Equals(CurrencyEnd, order.CurrencyEnd)
                   && string.Equals(CurrencyStart, order.CurrencyStart);
        }

        public override int GetHashCode()
        {
            unchecked
            {
                int hashCode = (OrderType != null ? OrderType.GetHashCode() : 0);
                hashCode = (hashCode*397) ^ OpenPrice.GetHashCode();
                hashCode = (hashCode*397) ^ StopLoss.GetHashCode();
                hashCode = (hashCode*397) ^ TakeProfit.GetHashCode();
                hashCode = (hashCode*397) ^ (CurrencyEnd != null ? CurrencyEnd.GetHashCode() : 0);
                hashCode = (hashCode*397) ^ (CurrencyStart != null ? CurrencyStart.GetHashCode() : 0);
                return hashCode;
            }
        }
    }
}