using System;
using System.Threading;

namespace SmartHomeSystem
{
    public class AirConditionerSystemConnection : HomeAutomationSystemConnection
    {
        private float desiredTemperature;
        private float ambientTemperature;
        private int fanSpeed;

        // PIC Board #1'den ortam sıcaklığı ve fan hızı verilerini okur.
        public override void update()
        {
            if (serialPort == null || !serialPort.IsOpen) return;

            try
            {
                // --- 1. Ortam Sıcaklığı Okuma ---
                SendByte(0x03); // fractional
                int ambientLow = ReadByte();

                SendByte(0x04); // integer
                int ambientHigh = ReadByte();

                if (ambientLow != -1 && ambientHigh != -1)
                {
                    ambientTemperature = ambientHigh + (float)(ambientLow / 10.0);
                }

                // --- 2. Fan Hızı Okuma ---
                SendByte(0x05);
                int speed = ReadByte();
                if (speed != -1)
                {
                    fanSpeed = speed;
                }
            }
            catch
            {
                // Haberleşme hatasında mevcut değerleri koru
            }
        }

        // Hedef sıcaklığı ayarlar ve PIC'e iki paket halinde gönderir.
        public bool setDesiredTemp(float temp)
        {
            if (serialPort == null || !serialPort.IsOpen) return false;

            try
            {
                this.desiredTemperature = temp;
                int tamKisim = (int)temp;
                int ondalikKisim = (int)Math.Round((temp - tamKisim) * 10);

                // Paket 1: Tam Kısım (11xxxxxx -> 0xC0)
                byte highBytePacket = (byte)(0xC0 | (tamKisim & 0x3F));
                SendByte(highBytePacket);

                Thread.Sleep(40); // PIC'in işlemesi için kısa gecikme

                // Paket 2: Ondalık Kısım (10xxxxxx -> 0x80)
                byte lowBytePacket = (byte)(0x80 | (ondalikKisim & 0x3F));
                SendByte(lowBytePacket);

                return true;
            }
            catch
            {
                return false;
            }
        }

        // Getter'lar
        public float getAmbientTemp() { return this.ambientTemperature; }
        public int getFanSpeed() { return this.fanSpeed; }
        public float getDesiredTemp() { return this.desiredTemperature; }
    }
}
