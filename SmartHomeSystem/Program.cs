using System;
using System.Windows.Forms;

namespace SmartHomeSystem
{
    internal static class Program
    {
        /// <summary>
        /// Uygulamanın ana giriş noktası.
        /// </summary>
        [STAThread]
        static void Main()
        {
            // Yüksek DPI ayarları ve varsayılan yazı tipi gibi uygulama yapılandırmalarını başlatır
            ApplicationConfiguration.Initialize();

            // Ana form olan Form1'i belleğe yükler ve çalıştırır
            // Form1 açıldığında Klima ve Perde nesneleri birbirinden bağımsız olarak oluşturulacaktır.
            Application.Run(new Form1());
        }
    }
}