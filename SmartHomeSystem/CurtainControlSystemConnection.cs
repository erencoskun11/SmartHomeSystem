using System;
using System.Threading;

namespace SmartHomeSystem
{
    public class CurtainControlSystemConnection : HomeAutomationSystemConnection
    {
        private float curtainStatus;      
        private double lightIntensity;     
        private float outdoorPressure;     

        
        public override void update()
        {
            if (serialPort == null || !serialPort.IsOpen)
                return;

            try
            {
                if (serialPort.BytesToRead > 0)
                    serialPort.DiscardInBuffer();

                SendByte(0x07);  
                Thread.Sleep(30);
                int lightFrac = ReadByte();
                
                Thread.Sleep(20);
                SendByte(0x08);  
                Thread.Sleep(30);
                int lightInt = ReadByte();

                if (lightInt >= 0 && lightFrac >= 0)
                    lightIntensity = lightInt + lightFrac / 10.0;

                
                Thread.Sleep(20);
                SendByte(0x05);  
                Thread.Sleep(30);
                int pressFrac = ReadByte();
                
                Thread.Sleep(20);
                SendByte(0x06);  
                Thread.Sleep(30);
                int pressInt = ReadByte();

                if (pressInt >= 0 && pressFrac >= 0)
                    outdoorPressure = 1000 + pressInt + pressFrac / 10.0f;

                
                Thread.Sleep(20);
                SendByte(0x01);  
                Thread.Sleep(30);
                int curtFrac = ReadByte();
                
                Thread.Sleep(20);
                SendByte(0x02);  
                Thread.Sleep(30);
                int curtInt = ReadByte();

                if (curtInt >= 0)
                {
                    curtainStatus = curtInt;   
                    if (curtainStatus < 0) curtainStatus = 0;
                    if (curtainStatus > 100) curtainStatus = 100;
                }
            }
            catch
            {
                
            }
        }

        
        public bool setCurtainStatus(int percent)
        {
            if (serialPort == null || !serialPort.IsOpen)
                return false;

            try
            {
                if (percent < 0) percent = 0;
                if (percent > 100) percent = 100;

                int value63 = percent / 2;   
                if (value63 > 63) value63 = 63;

                byte intPacket = (byte)(0xC0 | (value63 & 0x3F));
                byte fracPacket = 0x80; 

                SendByte(intPacket);
                Thread.Sleep(20);
                SendByte(fracPacket);

                return true;
            }
            catch
            {
                return false;
            }
        }

       
        public float getCurtainStatus() => curtainStatus;
        public double getLightIntensity() => lightIntensity;
        public float getOutdoorPress() => outdoorPressure;
    }
}
