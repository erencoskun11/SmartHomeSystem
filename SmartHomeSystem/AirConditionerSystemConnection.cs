using System;
using System.Threading;

namespace SmartHomeSystem
{
    public class AirConditionerSystemConnection : HomeAutomationSystemConnection
    {
        private float desiredTemperature;
        private float ambientTemperature;
        private int fanSpeed;

        public override void update()
        {
            if (serialPort == null || !serialPort.IsOpen) return;

            try
            {
                SendByte(0x03); 
                int ambientLow = ReadByte();

                SendByte(0x04); 
                int ambientHigh = ReadByte();

                if (ambientLow != -1 && ambientHigh != -1)
                {
                    ambientTemperature = ambientHigh + (float)(ambientLow / 10.0);
                }

                SendByte(0x05);
                int speed = ReadByte();
                if (speed != -1)
                {
                    fanSpeed = speed;
                }
            }
            catch
            {
            }
        }

        public bool setDesiredTemp(float temp)
        {
            if (serialPort == null || !serialPort.IsOpen) return false;

            try
            {
                this.desiredTemperature = temp;
                int tamKisim = (int)temp;
                int ondalikKisim = (int)Math.Round((temp - tamKisim) * 10);

                byte highBytePacket = (byte)(0xC0 | (tamKisim & 0x3F));
                SendByte(highBytePacket);

                Thread.Sleep(40); 

                
                byte lowBytePacket = (byte)(0x80 | (ondalikKisim & 0x3F));
                SendByte(lowBytePacket);

                return true;
            }
            catch
            {
                return false;
            }
        }

        public float getAmbientTemp() { return this.ambientTemperature; }
        public int getFanSpeed() { return this.fanSpeed; }
        public float getDesiredTemp() { return this.desiredTemperature; }
    }
}
