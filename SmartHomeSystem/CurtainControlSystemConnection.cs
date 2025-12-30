using System;
using System.Threading;

namespace SmartHomeSystem
{
    public class CurtainControlSystemConnection : HomeAutomationSystemConnection
    {
        private float curtainStatus;          // %
        private float outdoorTemperature;     // °C
        private float outdoorPressure;        // hPa
        private double lightIntensity;         // Lux

        // =========================================================
        // UPDATE – PIC'TEN VERİ OKUMA
        // =========================================================
        public override void update()
        {
            if (serialPort == null || !serialPort.IsOpen)
                return;

            try
            {
                // ---------- LIGHT ----------
                SendByte(0x07); // Light fractional
                int lightFrac = ReadByte();

                SendByte(0x08); // Light integer
                int lightInt = ReadByte();

                if (lightInt >= 0 && lightFrac >= 0)
                    lightIntensity = lightInt + (lightFrac / 10.0);

                // ---------- TEMPERATURE ----------
                SendByte(0x03); // Temp fractional
                int tempFrac = ReadByte();

                SendByte(0x04); // Temp integer
                int tempInt = ReadByte();

                if (tempInt >= 0 && tempFrac >= 0)
                    outdoorTemperature = tempInt + (tempFrac / 10.0f);

                // ---------- PRESSURE ----------
                SendByte(0x05); // Pressure fractional
                int pressFrac = ReadByte();

                SendByte(0x06); // Pressure integer (PIC returns last 2 digits)
                int pressInt = ReadByte();

                if (pressInt >= 0 && pressFrac >= 0)
                    outdoorPressure = (1000 + pressInt) + (pressFrac / 10.0f);

                // ---------- CURTAIN POSITION ----------
                SendByte(0x01); // Curtain fractional
                int curtFrac = ReadByte();

                SendByte(0x02); // Curtain integer
                int curtInt = ReadByte();

                if (curtInt >= 0 && curtFrac >= 0)
                    curtainStatus = curtInt + (curtFrac / 10.0f);

                // 🔴 HARD CLAMP (PIC %100 üstü raporlasa bile)
                if (curtainStatus < 0) curtainStatus = 0;
                if (curtainStatus > 100) curtainStatus = 100;

            }
            catch
            {
                // İletişim hatasında son değerler korunur
            }
        }

        // =========================================================
        // SET CURTAIN – %0–100 (MANUAL MODE)
        // =========================================================
        public bool setCurtainStatus(float status)
        {
            if (serialPort == null || !serialPort.IsOpen)
                return false;

            try
            {
                // ---- Clamp ----
                if (status < 0) status = 0;
                if (status > 100) status = 100;

                /*
                 PIC PROTOKOLÜ:
                 - INT  : 11xxxxxx → 0–63 → PIC tarafında *2 (0–100)
                 - FRAC : 10xxxxxx → 0–9
                */

                // ---- Integer kısmı (0–100 → 0–50) ----
                int intPart = (int)Math.Floor(status / 2.0);
                if (intPart > 50) intPart = 50;

                // ---- Fractional (0–9) ----
                float remainder = status - (intPart * 2);
                int fracPart = (int)Math.Round(remainder * 10.0f);
                if (fracPart < 0) fracPart = 0;
                if (fracPart > 9) fracPart = 9;

                // ---- SEND INTEGER (MANUAL MODE AKTİF OLUR) ----
                byte intPacket = (byte)(0xC0 | (intPart & 0x3F));
                SendByte(intPacket);

                Thread.Sleep(25); // PIC için zorunlu

                // ---- SEND FRACTIONAL ----
                byte fracPacket = (byte)(0x80 | (fracPart & 0x0F));
                SendByte(fracPacket);

                return true;
            }
            catch
            {
                return false;
            }
        }

        // =========================================================
        // AUTO MODE (POT + LDR KONTROLÜNE DÖN)
        // =========================================================
        public bool setAutoMode()
        {
            if (serialPort == null || !serialPort.IsOpen)
                return false;

            try
            {
                SendByte(0x09); // CMD_SET_AUTO_MODE
                return true;
            }
            catch
            {
                return false;
            }
        }

        // =========================================================
        // GETTERS
        // =========================================================
        public float getCurtainStatus() => curtainStatus;
        public float getOutdoorTemp() => outdoorTemperature;
        public float getOutdoorPress() => outdoorPressure;
        public double getLightIntensity() => lightIntensity;
    }
}
