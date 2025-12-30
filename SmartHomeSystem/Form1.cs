using System;
using System.Drawing;
using System.IO.Ports;
using System.Windows.Forms;

namespace SmartHomeSystem
{
    public partial class Form1 : Form
    {
        AirConditionerSystemConnection airCon = new AirConditionerSystemConnection();
        CurtainControlSystemConnection curtain = new CurtainControlSystemConnection();

        bool isConnected = false;

        // Windows Forms Timer - UI thread'de çalışır, deadlock olmaz
        private System.Windows.Forms.Timer updateTimer;

        public Form1()
        {
            InitializeComponent();
        }

        private void Form1_Load(object sender, EventArgs e)
        {
            string[] ports = SerialPort.GetPortNames();

            cboPorts.Items.AddRange(ports);
            cboCurtainPorts.Items.AddRange(ports);

            cboBaudRate.Items.Add("9600");
            cboBaudRate.SelectedIndex = 0;

            if (ports.Length > 0)
            {
                cboPorts.SelectedIndex = 0;
                cboCurtainPorts.SelectedIndex = ports.Length > 1 ? 1 : 0;
            }

            btnDisconnect.Enabled = false;

            // TrackBar event - sadece değer gösterimi için
            trackCurtain.ValueChanged += trackCurtain_ValueChanged;

            // Windows Forms Timer oluştur
            updateTimer = new System.Windows.Forms.Timer();
            updateTimer.Interval = 1000; // 1 saniye
            updateTimer.Tick += UpdateTimer_Tick;
        }

        // ================= TIMER TICK =================
        private void UpdateTimer_Tick(object sender, EventArgs e)
        {
            if (!isConnected) return;

            try
            {
                // Curtain sistemi güncelle
                curtain.update();

                lblLight.Text = $"Light: {curtain.getLightIntensity():0} Lux";
                lblPressure.Text = $"Pressure: {curtain.getOutdoorPress():0} hPa";

                int safeCurtain = (int)Math.Round(curtain.getCurtainStatus());
                safeCurtain = Math.Max(0, Math.Min(100, safeCurtain));
                lblCurtainStatus.Text = $"Curtain: %{safeCurtain}";

                // AC sistemi güncelle
                airCon.update();
                lblAmbientTemp.Text = $"Ambient: {airCon.getAmbientTemp():0.0} °C";
                lblFanSpeed.Text = $"Fan Speed: {airCon.getFanSpeed()} RPM";
            }
            catch (Exception ex)
            {
                // Hata durumunda sessizce devam et
                System.Diagnostics.Debug.WriteLine("Update error: " + ex.Message);
            }
        }

        // ================= CONNECT =================
        private void btnConnect_Click(object sender, EventArgs e)
        {
            if (cboPorts.Text == "" || cboCurtainPorts.Text == "")
            {
                MessageBox.Show("Lütfen Klima ve Perde için port seçiniz!");
                return;
            }

            try
            {
                airCon.setComPort(int.Parse(cboPorts.Text.Replace("COM", "")));
                airCon.setBaudRate(9600);

                curtain.setComPort(int.Parse(cboCurtainPorts.Text.Replace("COM", "")));
                curtain.setBaudRate(9600);

                if (!airCon.open() || !curtain.open())
                {
                    MessageBox.Show("Port açılamadı.");
                    airCon.close();
                    curtain.close();
                    return;
                }

                isConnected = true;
                lblStatus.Text = "BAĞLANDI";
                lblStatus.ForeColor = Color.Green;

                btnConnect.Enabled = false;
                btnDisconnect.Enabled = true;

                cboPorts.Enabled = false;
                cboCurtainPorts.Enabled = false;

                // Timer'ı başlat
                updateTimer.Start();
            }
            catch (Exception ex)
            {
                MessageBox.Show(ex.Message);
            }
        }

        // ================= TRACKBAR =================
        private void trackCurtain_ValueChanged(object sender, EventArgs e)
        {
            lblCurtainValShow.Text = trackCurtain.Value + " %";
        }

        // ================= BUTTONS =================
        private void btnSetTemp_Click(object sender, EventArgs e)
        {
            if (!isConnected) return;
            airCon.setDesiredTemp((float)numDesiredTemp.Value);
        }

        private void btnSetCurtain_Click(object sender, EventArgs e)
        {
            if (!isConnected) return;
            
            // Timer'ı geçici olarak durdur (çakışma olmasın)
            updateTimer.Stop();
            
            try
            {
                bool ok = curtain.setCurtainStatus(trackCurtain.Value);
                if (!ok)
                    MessageBox.Show("Perde komutu gönderilemedi.");
            }
            finally
            {
                // Timer'ı tekrar başlat
                updateTimer.Start();
            }
        }

        private void btnDisconnect_Click(object sender, EventArgs e)
        {
            updateTimer?.Stop();

            airCon.close();
            curtain.close();

            isConnected = false;
            lblStatus.Text = "Bağlantı Kesildi";
            lblStatus.ForeColor = Color.Red;

            btnConnect.Enabled = true;
            btnDisconnect.Enabled = false;

            cboPorts.Enabled = true;
            cboCurtainPorts.Enabled = true;
        }

        private void Form1_FormClosing(object sender, FormClosingEventArgs e)
        {
            updateTimer?.Stop();
            updateTimer?.Dispose();
            airCon.close();
            curtain.close();
        }

        private void tmrUpdate_Tick(object sender, EventArgs e)
        {
            // kullanılmıyor
        }
    }
}
