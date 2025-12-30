using System;
using System.IO.Ports;
using System.Threading;

namespace SmartHomeSystem
{
    public class HomeAutomationSystemConnection
    {
        protected SerialPort serialPort = new SerialPort();
        protected int comPort;
        protected int baudRate;

        public Action<string> Log { get; set; } = s => { };

        public void setComPort(int port)
        {
            comPort = port;
            try
            {
                serialPort.PortName = "COM" + port;
            }
            catch { }
        }

        public void setBaudRate(int rate)
        {
            baudRate = rate;
            try
            {
                serialPort.BaudRate = rate;
                serialPort.Parity = Parity.None;
                serialPort.DataBits = 8;
                serialPort.StopBits = StopBits.One;
                serialPort.Handshake = Handshake.None;
                serialPort.ReadTimeout = 500;
                serialPort.WriteTimeout = 500;
            }
            catch { }
        }

        public virtual bool open()
        {
            try
            {
                if (!serialPort.IsOpen)
                {
                    serialPort.Open();
                    serialPort.DiscardInBuffer();
                    serialPort.DiscardOutBuffer();
                }
                return true;
            }
            catch (Exception ex)
            {
                Log?.Invoke("Open error: " + ex.Message);
                return false;
            }
        }

        public virtual bool close()
        {
            try
            {
                if (serialPort.IsOpen)
                {
                    serialPort.Close();
                }
                return true;
            }
            catch (Exception ex)
            {
                Log?.Invoke("Close error: " + ex.Message);
                return false;
            }
        }

        public virtual void update()
        {
            
        }


        protected void SendByte(byte data)
        {
            try
            {
                if (serialPort.IsOpen)
                {
                    serialPort.Write(new byte[] { data }, 0, 1);
                }
            }
            catch (Exception ex)
            {
                Log?.Invoke("SendByte error: " + ex.Message);
            }
        }

        protected int ReadByte()
        {
            try
            {
                if (!serialPort.IsOpen)
                    return -1;

                int timeout = 20; 
                while (serialPort.BytesToRead == 0 && timeout > 0)
                {
                    System.Threading.Thread.Sleep(10);
                    timeout--;
                }

                if (serialPort.BytesToRead > 0)
                    return serialPort.ReadByte();

                return -1;
            }
            catch (Exception ex)
            {
                Log?.Invoke("ReadByte error: " + ex.Message);
                return -1;
            }
        }
    }
}
