using System;
using System.Threading;

namespace MailTC.Support
{
    public static class MutexExtension
    {

        public static void Set(this WaitHandle mutex, int millisecond)
        {
            try
            {
                mutex.WaitOne(millisecond);
            }
            catch (AbandonedMutexException)
            {
            }
        }

        public static void Release(this Mutex mutex)
        {
            try
            {
                mutex.ReleaseMutex();
            }
            catch (ApplicationException)
            {
            }
        }

        public static Mutex GetMutex()
        {
            Mutex mutex;
            try
            {
                mutex = Mutex.OpenExisting(Connector.MutexName);
            }
            catch (WaitHandleCannotBeOpenedException)
            {
                mutex = new Mutex(false, Connector.MutexName);
            }
            return mutex;
        }
    }
}