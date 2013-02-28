using System;

namespace MailTC.Support
{
    [AttributeUsage(AttributeTargets.Method, AllowMultiple = false)]
    public class DllExport : Attribute
    {
    }
}