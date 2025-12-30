namespace SmartHomeSystem
{
    partial class Form1
    {
        /// <summary>
        ///  Required designer variable.
        /// </summary>
        private System.ComponentModel.IContainer components = null;

        /// <summary>
        ///  Clean up any resources being used.
        /// </summary>
        /// <param name="disposing">true if managed resources should be disposed; otherwise, false.</param>
        protected override void Dispose(bool disposing)
        {
            if (disposing && (components != null))
            {
                components.Dispose();
            }
            base.Dispose(disposing);
        }

        #region Windows Form Designer generated code

        /// <summary>
        ///  Required method for Designer support - do not modify
        ///  the contents of this method with the code editor.
        /// </summary>
        private void InitializeComponent()
        {
            components = new System.ComponentModel.Container();
            grpConnection = new GroupBox();
            lblStatus = new Label();
            btnDisconnect = new Button();
            btnConnect = new Button();
            label2 = new Label();
            cboBaudRate = new ComboBox();
            label1 = new Label();
            cboPorts = new ComboBox();
            grpAirCon = new GroupBox();
            btnSetTemp = new Button();
            numDesiredTemp = new NumericUpDown();
            label5 = new Label();
            lblFanSpeed = new Label();
            lblAmbientTemp = new Label();
            grpCurtain = new GroupBox();
            btnSetCurtain = new Button();
            lblCurtainValShow = new Label();
            trackCurtain = new TrackBar();
            lblPressure = new Label();
            lblLight = new Label();
            lblCurtainStatus = new Label();
            cboCurtainPorts = new ComboBox();
            // new debug textbox
            txtLog = new System.Windows.Forms.TextBox();

            grpConnection.SuspendLayout();
            grpAirCon.SuspendLayout();
            ((System.ComponentModel.ISupportInitialize)numDesiredTemp).BeginInit();
            grpCurtain.SuspendLayout();
            ((System.ComponentModel.ISupportInitialize)trackCurtain).BeginInit();
            SuspendLayout();
            // 
            // grpConnection
            // 
            grpConnection.Controls.Add(cboCurtainPorts);
            grpConnection.Controls.Add(lblStatus);
            grpConnection.Controls.Add(btnDisconnect);
            grpConnection.Controls.Add(btnConnect);
            grpConnection.Controls.Add(label2);
            grpConnection.Controls.Add(cboBaudRate);
            grpConnection.Controls.Add(label1);
            grpConnection.Controls.Add(cboPorts);
            grpConnection.Location = new Point(17, 20);
            grpConnection.Margin = new Padding(4, 5, 4, 5);
            grpConnection.Name = "grpConnection";
            grpConnection.Padding = new Padding(4, 5, 4, 5);
            grpConnection.Size = new Size(371, 300);
            grpConnection.TabIndex = 0;
            grpConnection.TabStop = false;
            grpConnection.Text = "Connection Settings";
            // 
            // lblStatus
            // 
            lblStatus.AutoSize = true;
            lblStatus.Font = new Font("Segoe UI", 9F, FontStyle.Bold);
            lblStatus.ForeColor = Color.Red;
            lblStatus.Location = new Point(21, 250);
            lblStatus.Margin = new Padding(4, 0, 4, 0);
            lblStatus.Name = "lblStatus";
            lblStatus.Size = new Size(140, 25);
            lblStatus.TabIndex = 6;
            lblStatus.Text = "Not Connected";
            // 
            // btnDisconnect
            // 
            btnDisconnect.Enabled = false;
            btnDisconnect.Location = new Point(191, 167);
            btnDisconnect.Margin = new Padding(4, 5, 4, 5);
            btnDisconnect.Name = "btnDisconnect";
            btnDisconnect.Size = new Size(156, 58);
            btnDisconnect.TabIndex = 5;
            btnDisconnect.Text = "DISCONNECT";
            btnDisconnect.UseVisualStyleBackColor = true;
            btnDisconnect.Click += btnDisconnect_Click;
            // 
            // btnConnect
            // 
            btnConnect.Location = new Point(21, 167);
            btnConnect.Margin = new Padding(4, 5, 4, 5);
            btnConnect.Name = "btnConnect";
            btnConnect.Size = new Size(156, 58);
            btnConnect.TabIndex = 4;
            btnConnect.Text = "CONNECT";
            btnConnect.UseVisualStyleBackColor = true;
            btnConnect.Click += btnConnect_Click;
            // 
            // label2
            // 
            label2.AutoSize = true;
            label2.Location = new Point(21, 91);
            label2.Margin = new Padding(4, 0, 4, 0);
            label2.Name = "label2";
            label2.Size = new Size(96, 25);
            label2.TabIndex = 3;
            label2.Text = "Baud Rate:";
            // 
            // cboBaudRate
            // 
            cboBaudRate.FormattingEnabled = true;
            cboBaudRate.Location = new Point(125, 88);
            cboBaudRate.Margin = new Padding(4, 5, 4, 5);
            cboBaudRate.Name = "cboBaudRate";
            cboBaudRate.Size = new Size(225, 33);
            cboBaudRate.TabIndex = 2;
            // 
            // label1
            // 
            label1.AutoSize = true;
            label1.Location = new Point(21, 50);
            label1.Margin = new Padding(4, 0, 4, 0);
            label1.Name = "label1";
            label1.Size = new Size(48, 25);
            label1.TabIndex = 1;
            label1.Text = "Port:";
            // 
            // cboPorts
            // 
            cboPorts.FormattingEnabled = true;
            cboPorts.Location = new Point(120, 45);
            cboPorts.Margin = new Padding(4, 5, 4, 5);
            cboPorts.Name = "cboPorts";
            cboPorts.Size = new Size(225, 33);
            cboPorts.TabIndex = 0;
            // 
            // grpAirCon
            // 
            grpAirCon.Controls.Add(btnSetTemp);
            grpAirCon.Controls.Add(numDesiredTemp);
            grpAirCon.Controls.Add(label5);
            grpAirCon.Controls.Add(lblFanSpeed);
            grpAirCon.Controls.Add(lblAmbientTemp);
            grpAirCon.Location = new Point(414, 20);
            grpAirCon.Margin = new Padding(4, 5, 4, 5);
            grpAirCon.Name = "grpAirCon";
            grpAirCon.Padding = new Padding(4, 5, 4, 5);
            grpAirCon.Size = new Size(371, 300);
            grpAirCon.TabIndex = 1;
            grpAirCon.TabStop = false;
            grpAirCon.Text = "Air Conditioner System";
            // 
            // btnSetTemp
            // 
            btnSetTemp.Location = new Point(214, 217);
            btnSetTemp.Margin = new Padding(4, 5, 4, 5);
            btnSetTemp.Name = "btnSetTemp";
            btnSetTemp.Size = new Size(129, 42);
            btnSetTemp.TabIndex = 4;
            btnSetTemp.Text = "SET";
            btnSetTemp.UseVisualStyleBackColor = true;
            btnSetTemp.Click += btnSetTemp_Click;
            // 
            // numDesiredTemp
            // 
            numDesiredTemp.DecimalPlaces = 1;
            numDesiredTemp.Font = new Font("Segoe UI", 12F);
            numDesiredTemp.Increment = new decimal(new int[] { 1, 0, 0, 65536 });
            numDesiredTemp.Location = new Point(29, 213);
            numDesiredTemp.Margin = new Padding(4, 5, 4, 5);
            numDesiredTemp.Name = "numDesiredTemp";
            numDesiredTemp.Size = new Size(157, 39);
            numDesiredTemp.TabIndex = 3;
            numDesiredTemp.Value = new decimal(new int[] { 250, 0, 0, 65536 });
            // 
            // label5
            // 
            label5.AutoSize = true;
            label5.Location = new Point(29, 183);
            label5.Margin = new Padding(4, 0, 4, 0);
            label5.Name = "label5";
            label5.Size = new Size(173, 25);
            label5.TabIndex = 2;
            label5.Text = "Set Desired Temp °C";
            // 
            // lblFanSpeed
            // 
            lblFanSpeed.AutoSize = true;
            lblFanSpeed.Font = new Font("Segoe UI", 11F);
            lblFanSpeed.Location = new Point(29, 108);
            lblFanSpeed.Margin = new Padding(4, 0, 4, 0);
            lblFanSpeed.Name = "lblFanSpeed";
            lblFanSpeed.Size = new Size(194, 30);
            lblFanSpeed.TabIndex = 1;
            lblFanSpeed.Text = "Fan Speed: -- RPM";
            // 
            // lblAmbientTemp
            // 
            lblAmbientTemp.AutoSize = true;
            lblAmbientTemp.Font = new Font("Segoe UI", 11F);
            lblAmbientTemp.Location = new Point(29, 50);
            lblAmbientTemp.Margin = new Padding(4, 0, 4, 0);
            lblAmbientTemp.Name = "lblAmbientTemp";
            lblAmbientTemp.Size = new Size(166, 30);
            lblAmbientTemp.TabIndex = 0;
            lblAmbientTemp.Text = "Ambient: --.- °C";
            // 
            // grpCurtain
            // 
            grpCurtain.Controls.Add(btnSetCurtain);
            grpCurtain.Controls.Add(lblCurtainValShow);
            grpCurtain.Controls.Add(trackCurtain);
            grpCurtain.Controls.Add(lblPressure);
            grpCurtain.Controls.Add(lblLight);
            grpCurtain.Controls.Add(lblCurtainStatus);
            grpCurtain.Location = new Point(17, 350);
            grpCurtain.Margin = new Padding(4, 5, 4, 5);
            grpCurtain.Name = "grpCurtain";
            grpCurtain.Padding = new Padding(4, 5, 4, 5);
            grpCurtain.Size = new Size(769, 267);
            grpCurtain.TabIndex = 2;
            grpCurtain.TabStop = false;
            grpCurtain.Text = "Curtain Control & Environment";
            // 
            // btnSetCurtain
            // 
            btnSetCurtain.Location = new Point(617, 183);
            btnSetCurtain.Margin = new Padding(4, 5, 4, 5);
            btnSetCurtain.Name = "btnSetCurtain";
            btnSetCurtain.Size = new Size(129, 50);
            btnSetCurtain.TabIndex = 5;
            btnSetCurtain.Text = "SET CURTAIN";
            btnSetCurtain.UseVisualStyleBackColor = true;
            btnSetCurtain.Click += btnSetCurtain_Click;
            // 
            // lblCurtainValShow
            // 
            lblCurtainValShow.AutoSize = true;
            lblCurtainValShow.Location = new Point(643, 142);
            lblCurtainValShow.Margin = new Padding(4, 0, 4, 0);
            lblCurtainValShow.Name = "lblCurtainValShow";
            lblCurtainValShow.Size = new Size(42, 25);
            lblCurtainValShow.TabIndex = 4;
            lblCurtainValShow.Text = "0 %";
            // 
            // trackCurtain
            // 
            trackCurtain.Location = new Point(29, 183);
            trackCurtain.Margin = new Padding(4, 5, 4, 5);
            trackCurtain.Maximum = 100;
            trackCurtain.Name = "trackCurtain";
            trackCurtain.Size = new Size(571, 69);
            trackCurtain.TabIndex = 3;
            trackCurtain.TickFrequency = 10;
            // 
            // lblPressure
            // 
            lblPressure.AutoSize = true;
            lblPressure.Font = new Font("Segoe UI", 10F);
            lblPressure.Location = new Point(429, 67);
            lblPressure.Margin = new Padding(4, 0, 4, 0);
            lblPressure.Name = "lblPressure";
            lblPressure.Size = new Size(145, 28);
            lblPressure.TabIndex = 2;
            lblPressure.Text = "Pressure: -- hPa";
            // 
            // lblLight
            // 
            lblLight.AutoSize = true;
            lblLight.Font = new Font("Segoe UI", 10F);
            lblLight.Location = new Point(229, 67);
            lblLight.Margin = new Padding(4, 0, 4, 0);
            lblLight.Name = "lblLight";
            lblLight.Size = new Size(115, 28);
            lblLight.TabIndex = 1;
            lblLight.Text = "Light: -- Lux";
            // 
            // lblCurtainStatus
            // 
            lblCurtainStatus.AutoSize = true;
            lblCurtainStatus.Font = new Font("Segoe UI", 10F, FontStyle.Bold);
            lblCurtainStatus.ForeColor = Color.DarkBlue;
            lblCurtainStatus.Location = new Point(29, 67);
            lblCurtainStatus.Margin = new Padding(4, 0, 4, 0);
            lblCurtainStatus.Name = "lblCurtainStatus";
            lblCurtainStatus.Size = new Size(132, 28);
            lblCurtainStatus.TabIndex = 0;
            lblCurtainStatus.Text = "Curtain: -- %";
            // 
            // cboCurtainPorts
            // 
            cboCurtainPorts.FormattingEnabled = true;
            cboCurtainPorts.Location = new Point(125, 129);
            cboCurtainPorts.Name = "cboCurtainPorts";
            cboCurtainPorts.Size = new Size(222, 33);
            cboCurtainPorts.TabIndex = 7;
            // 
            // txtLog (debug textbox)
            // 
            txtLog.Location = new Point(17, 630);
            txtLog.Multiline = true;
            txtLog.Name = "txtLog";
            txtLog.ReadOnly = true;
            txtLog.ScrollBars = ScrollBars.Vertical;
            txtLog.Size = new Size(769, 180);
            txtLog.TabIndex = 8;
            // 
            // Form1
            // 
            AutoScaleDimensions = new SizeF(10F, 25F);
            AutoScaleMode = AutoScaleMode.Font;
            ClientSize = new Size(820, 840);
            Controls.Add(txtLog);
            Controls.Add(grpCurtain);
            Controls.Add(grpAirCon);
            Controls.Add(grpConnection);
            Margin = new Padding(4, 5, 4, 5);
            Name = "Form1";
            Text = "Smart Home Control Panel";
            FormClosing += Form1_FormClosing;
            Load += Form1_Load;
            grpConnection.ResumeLayout(false);
            grpConnection.PerformLayout();
            grpAirCon.ResumeLayout(false);
            grpAirCon.PerformLayout();
            ((System.ComponentModel.ISupportInitialize)numDesiredTemp).EndInit();
            grpCurtain.ResumeLayout(false);
            grpCurtain.PerformLayout();
            ((System.ComponentModel.ISupportInitialize)trackCurtain).EndInit();
            ResumeLayout(false);
        }

        #endregion

        private System.Windows.Forms.GroupBox grpConnection;
        private System.Windows.Forms.Label label2;
        private System.Windows.Forms.ComboBox cboBaudRate;
        private System.Windows.Forms.Label label1;
        private System.Windows.Forms.ComboBox cboPorts;
        private System.Windows.Forms.Button btnDisconnect;
        private System.Windows.Forms.Button btnConnect;
        private System.Windows.Forms.Label lblStatus;
        private System.Windows.Forms.GroupBox grpAirCon;
        private System.Windows.Forms.Label lblFanSpeed;
        private System.Windows.Forms.Label lblAmbientTemp;
        private System.Windows.Forms.Button btnSetTemp;
        private System.Windows.Forms.NumericUpDown numDesiredTemp;
        private System.Windows.Forms.Label label5;
        private System.Windows.Forms.GroupBox grpCurtain;
        private System.Windows.Forms.TrackBar trackCurtain;
        private System.Windows.Forms.Label lblPressure;
        private System.Windows.Forms.Label lblLight;
        private System.Windows.Forms.Label lblCurtainStatus;
        private System.Windows.Forms.Button btnSetCurtain;
        private System.Windows.Forms.Label lblCurtainValShow;
        // removed WinForms timer field (we use System.Threading.Timer in Form1.cs now)
        private System.Windows.Forms.TextBox txtLog;
        private System.Windows.Forms.ComboBox cboCurtainPorts;
    }
}
