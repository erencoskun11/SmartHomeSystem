using System;
using System.Drawing;
using System.IO.Ports;
using System.Threading;
using System.Windows.Forms;

namespace SmartHomeSystem
{
    public partial class Form1 : Form
    {
        AirConditionerSystemConnection airCon = new AirConditionerSystemConnection();
        CurtainControlSystemConnection curtain = new CurtainControlSystemConnection();

        bool isConnected = false;
        bool userDraggingCurtain = false; // 🔴 KRİTİK FLAG

        private System.Threading.Timer acTimer;
        private System.Threading.Timer curtainTimer;

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

            // 🔹 TrackBar eventleri
            trackCurtain.ValueChanged += trackCurtain_ValueChanged;
            trackCurtain.MouseDown += (s, ev) => userDraggingCurtain = true;
            trackCurtain.MouseUp += trackCurtain_MouseUp;

            // Log callback (opsiyonel)
            airCon.Log = s =>
            {
                if (!IsHandleCreated) return;
                BeginInvoke(new Action(() =>
                {
                    var arr = Controls.Find("txtLog", true);
                    if (arr.Length > 0 && arr[0] is TextBox tb)
                        tb.AppendText(s + Environment.NewLine);
                }));
            };

            curtain.Log = airCon.Log;
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

                acTimer = new System.Threading.Timer(AcTimerCallback, null, 0, 700);
                curtainTimer = new System.Threading.Timer(CurtainTimerCallback, null, 0, 900);
            }
            catch (Exception ex)
            {
                MessageBox.Show(ex.Message);
            }
        }

        // ================= AC TIMER =================
        private void AcTimerCallback(object state)
        {
            try
            {
                airCon.update();
                BeginInvoke(new Action(() =>
                {
                    lblAmbientTemp.Text = $"Ambient: {airCon.getAmbientTemp():0.0} °C";
                    lblFanSpeed.Text = $"Fan Speed: {airCon.getFanSpeed()} RPM";
                }));
            }
            catch { }
        }

        // ================= CURTAIN TIMER =================
        private void CurtainTimerCallback(object state)
        {
            try
            {
                curtain.update();

                BeginInvoke(new Action(() =>
                {
                    lblLight.Text = $"Light: {curtain.getLightIntensity():0} Lux";
                    lblPressure.Text = $"Pressure: {curtain.getOutdoorPress():0} hPa";

                    // ✅ TEK NOKTADA GÜVENLİ DEĞER
                    int safeCurtain = (int)Math.Round(curtain.getCurtainStatus());
                    safeCurtain = Math.Max(0, Math.Min(100, safeCurtain));

                    lblCurtainStatus.Text = $"Curtain: %{safeCurtain}";

                    // 🔴 Kullanıcı sürüklemiyorsa UI senkronla
                    if (!userDraggingCurtain)
                    {
                        trackCurtain.Value = safeCurtain;
                        lblCurtainValShow.Text = safeCurtain + " %";
                    }
                }));
            }
            catch { }
        }

        // ================= TRACKBAR =================
        private void trackCurtain_ValueChanged(object sender, EventArgs e)
        {
            lblCurtainValShow.Text = trackCurtain.Value + " %";
        }

        private void trackCurtain_MouseUp(object sender, MouseEventArgs e)
        {
            userDraggingCurtain = false;

            if (!isConnected) return;

            bool ok = curtain.setCurtainStatus(trackCurtain.Value);
            if (!ok)
                MessageBox.Show("Perde komutu gönderilemedi.");
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
            curtain.setCurtainStatus(trackCurtain.Value);
        }

        private void btnDisconnect_Click(object sender, EventArgs e)
        {
            acTimer?.Dispose();
            curtainTimer?.Dispose();

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
            acTimer?.Dispose();
            curtainTimer?.Dispose();
            airCon.close();
            curtain.close();
        }

        private void tmrUpdate_Tick(object sender, EventArgs e)
        {
            // kullanılmıyor
        }
    }
}
