
// Normally AXI is automatically inferred.  However, if the names of your ports do not match, you can force the
// the creation of an interface and map the physical ports to the logical ports by using the X_INTERFACE_INFO
// attribute before each physical port
// Parameters are typically computed by the Block Diagram and annotated onto the cell (no need to specify these)
// axis - AMBA AXI4-Stream Interface (slave directions)
// 
// Allowed parameters:
//  CLK_DOMAIN                - Clk Domain                (string default: <blank>) 
//  PHASE                     - Phase                     (float) 
//  FREQ_HZ                   - Frequency                 (float default: 100000000) 
//  LAYERED_METADATA          - Layered Metadata          (string default: <blank>) 
//  HAS_TLAST                 - Has Tlast                 (long) {false - 0, true - 1}
//  HAS_TKEEP                 - Has Tkeep                 (long) {false - 0, true - 1}
//  HAS_TSTRB                 - Has Tstrb                 (long) {false - 0, true - 1}
//  HAS_TREADY                - Has Tready                (long) {false - 0, true - 1}
//  TUSER_WIDTH               - Tuser Width               (long) 
//  TID_WIDTH                 - Tid Width                 (long) 
//  TDEST_WIDTH               - Tdest Width               (long) 
//  TDATA_NUM_BYTES           - Tdata Num Bytes           (long) 
module HDMI_with_AXI_STREAM (
  //(* X_INTERFACE_INFO = "xilinx.com:interface:axis:1.0 <interface_name> TID" *)
  // Uncomment the following to set interface specific parameter on the bus interface.
  //  (* X_INTERFACE_PARAMETER = "CLK_DOMAIN <value>,PHASE <value>,FREQ_HZ <value>,LAYERED_METADATA <value>,HAS_TLAST <value>,HAS_TKEEP <value>,HAS_TSTRB <value>,HAS_TREADY <value>,TUSER_WIDTH <value>,TID_WIDTH <value>,TDEST_WIDTH <value>,TDATA_NUM_BYTES <value>" *)
  //(* X_INTERFACE_PARAMETER = "ASSOCIATED_BUSIF AXI_STREAM, ASSOCIATED_RESET s_axi_aresetn, FREQ_HZ 25000000" *)
  (* X_INTERFACE_PARAMETER = "FREQ_HZ 25000000" *)
     
   (* X_INTERFACE_INFO = "xilinx.com:signal:clock:1.0 clk_25MHZ CLK" *)
   (* X_INTERFACE_PARAMETER = "ASSOCIATED_BUSIF AXI_STREAM, ASSOCIATED_RESET rst, FREQ_HZ 25000000" *)
   input wire        clk_25MHZ,
   (* X_INTERFACE_INFO = "xilinx.com:signal:reset:1.0 rst RST" *)
   (* X_INTERFACE_PARAMETER = "POLARITY ACTIVE_LOW" *)
   input wire        rstn,

  //input wire s_tid, // Transfer ID tag (optional)
  //(* X_INTERFACE_INFO = "xilinx.com:interface:axis:1.0 <interface_name> TDEST" *)
  //input wire s_tdest, // Transfer Destination (optional)
  (* X_INTERFACE_INFO = "xilinx.com:interface:axis:1.0 AXI_STREAM TDATA" *)
  input wire [31:0] s_tdata, // Transfer Data (optional)
  //(* X_INTERFACE_INFO = "xilinx.com:interface:axis:1.0 <interface_name> TSTRB" *)
  //input [<left_bound>:0] <s_tstrb>, // Transfer Data Byte Strobes (optional)
  //(* X_INTERFACE_INFO = "xilinx.com:interface:axis:1.0 <interface_name> TKEEP" *)
  //input [<left_bound>:0] <s_tkeep>, // Transfer Null Byte Indicators (optional)
  (* X_INTERFACE_INFO = "xilinx.com:interface:axis:1.0 AXI_STREAM TLAST" *)
  input wire s_tlast, // Packet Boundary Indicator (optional)
  //(* X_INTERFACE_INFO = "xilinx.com:interface:axis:1.0 <interface_name> TUSER" *)
  //input [<left_bound>:0] <s_tuser>, // Transfer user sideband (optional)
  (* X_INTERFACE_INFO = "xilinx.com:interface:axis:1.0 AXI_STREAM TVALID" *)
  input wire s_tvalid, // Transfer valid (required)
  (* X_INTERFACE_INFO = "xilinx.com:interface:axis:1.0 AXI_STREAM TREADY" *)
  output wire s_tready, // Transfer ready (optional)
//  additional ports here

   output wire       hdmi_tx_d0_p,
   output wire       hdmi_tx_d0_n,
   output wire       hdmi_tx_d1_p,
   output wire       hdmi_tx_d1_n,
   output wire       hdmi_tx_d2_p,
   output wire       hdmi_tx_d2_n,
   (* X_INTERFACE_PARAMETER = "FREQ_HZ 25125000" *)
   output wire       hdmi_tx_clk_p,
   (* X_INTERFACE_PARAMETER = "FREQ_HZ 25125000" *)
   output wire       hdmi_tx_clk_n,
   input  wire       hdmi_tx_cec,
   input  wire       hdmi_tx_hpdn,
   input  wire       hdmi_tx_scl,
   input  wire       hdmi_tx_sda
);

localparam STATE_INIT = 2'd0;
localparam STATE_WAIT_VSYNC = 2'd1;
localparam STATE_SYNCED = 2'd2;

reg[1:0] state_machine = STATE_INIT;

wire mmcm_clkout0, mmcm_clkout1, mmcm_clkfb, mmcm_locked;
MMCME2_ADV #(
 .BANDWIDTH ("OPTIMIZED"),
 .CLKOUT4_CASCADE ("FALSE"),
 .COMPENSATION ("ZHOLD"),
 .STARTUP_WAIT ("FALSE"),
 .DIVCLK_DIVIDE (1), //A glob�lis oszt�s �rt�ke.
 .CLKFBOUT_MULT_F (25.125), //A glob�lis szorz�s �rt�ke.
 .CLKFBOUT_PHASE (0.000),
 .CLKFBOUT_USE_FINE_PS("FALSE"),
 .CLKOUT0_DIVIDE_F (5.0), //A CLKOUT0 kimenetre be�ll�tott oszt�s.
 .CLKOUT0_PHASE (0.000),
 .CLKOUT0_DUTY_CYCLE (0.500),
 .CLKOUT0_USE_FINE_PS ("FALSE"),
 .CLKOUT1_DIVIDE (25), //A CLKOUT1 kimenetre be�ll�tott oszt�s. best bet: 18
 .CLKOUT1_PHASE (0.000),
 .CLKOUT1_DUTY_CYCLE (0.500),
 .CLKOUT1_USE_FINE_PS ("FALSE"),
 .CLKIN1_PERIOD (40.000) //Bemeneti �rajel peri�dusid� [ns].
) mmcm_adv_inst (
 //Kimen� �rajelek.
 .CLKFBOUT (mmcm_clkfb),
 .CLKOUT0 (mmcm_clkout0),
 .CLKOUT1 (mmcm_clkout1),
 //Bemen� �rajelek.
 .CLKFBIN (mmcm_clkfb),
 .CLKIN1 (clk_25MHZ),
 .CLKIN2 (1'b0),
 //Az �rajel bemenet kiv�laszt� jele (a CLKIN1 bemenetet haszn�ljuk).
 .CLKINSEL (1'b1),
 //A dinamikos �tkonfigur�l�shoz tartoz� jelek.
 .DADDR (7'h0),
 .DCLK (1'b0),
 .DEN (1'b0),
 .DI (16'h0),
 .DO (),
  .DRDY (),
 .DWE (1'b0),
 //A dinamikos f�zis l�ptet�shez tartoz� jelek.
 .PSCLK (1'b0),
 .PSEN (1'b0),
 .PSINCDEC (1'b0),
 .PSDONE (),
 //Egy�b vez�rl� �s st�tusz jelek.
 .LOCKED (mmcm_locked),
 .PWRDWN (1'b0),
 .RST (~rstn)
);

wire rx_clk_5x, rx_clk;
BUFG BUFG_fastclk(.I(mmcm_clkout0), .O(rx_clk_5x));
BUFG BUFG_slowclk(.I(mmcm_clkout1), .O(rx_clk));
wire hdmi_reset = ~rstn | ~mmcm_locked;

wire[10:0] x;
wire[9:0] y;
wire timings_hsync;
wire timings_vsync;
wire timings_blank;
//  user logic here
vga_timing pix_tims
(
    //�rajel �s reset.
 .clk(clk_25MHZ), //Pixel �rajel bemenet.
 .rst(hdmi_reset), //Reset bemenet.

 //Az aktu�lis pixel poz�ci�.
 .h_cnt(x), //X-koordin�ta.
 .v_cnt(y), //Y-koordin�ta.

 //Szinkron �s kiolt� jelek.
 .h_sync(timings_hsync), //Horizont�lis szinkron pulzus.
 .v_sync(timings_vsync), //Vertik�lis szinkron pulzus.
 .blank(timings_blank) //Kiolt� jel.
);

always @(posedge clk_25MHZ)
begin
if (hdmi_reset)
    state_machine <= STATE_INIT;
else
case(state_machine)
     STATE_INIT:
        if (s_tlast)
            state_machine <= STATE_WAIT_VSYNC;
        else
            state_machine <= STATE_INIT;
    STATE_WAIT_VSYNC:
        if (x == 0 && y == 0)
            state_machine <= STATE_SYNCED;
        else
            state_machine <= STATE_WAIT_VSYNC;
   STATE_SYNCED:
        if(~timings_blank && ~s_tvalid)
            state_machine <= STATE_INIT;
        else 
            state_machine <= STATE_SYNCED;     
    default: state_machine <= STATE_INIT;
endcase   
end

assign s_tready = ~((state_machine == STATE_WAIT_VSYNC) || timings_blank);

wire [7:0] tx_red, tx_green, tx_blue;
wire tx_dv, tx_hs, tx_vs;
/*wire [7:0] red = {8{x[6] ^ y[6]}};
wire [7:0] green = {8{x[7] ^ y[7]}};
wire [7:0] blue = {8{x[8] ^ y[8]}};*/
assign tx_dv    = timings_blank;
assign tx_hs    = timings_hsync;
assign tx_vs    = timings_vsync;
assign tx_red   = s_tdata[23:16];
assign tx_green = s_tdata[15:8];
assign tx_blue  = s_tdata[7:0];

tmds_transmitter tmds_transmitter(
 //�rajel �s reset.
 .clk(rx_clk), //Pixel �rajel bemenet.
 .clk_5x(rx_clk_5x), //5x pixel �rajel bemenet.
 .rst(hdmi_reset), //Reset jel.
 //Bemeneti video adatok.
 .red_in(tx_red), //Piros sz�nkomponens.
 .green_in(tx_green), //Z�ld sz�nkomponens.
 .blue_in(tx_blue), //K�k sz�nkomponens.
 .blank_in(tx_dv), //A nem l�that� k�ptartom�ny jelz�se.
 .hsync_in(tx_hs), //Horizont�lis szinkronjel.
 .vsync_in(tx_vs), //Vertik�lis szinkronjel.
 //Kimen� TMDS jelek.
 .tmds_data0_out_p(hdmi_tx_d0_p), //Adat 0.
 .tmds_data0_out_n(hdmi_tx_d0_n),
 .tmds_data1_out_p(hdmi_tx_d1_p), //Adat 1.
 .tmds_data1_out_n(hdmi_tx_d1_n),
 .tmds_data2_out_p(hdmi_tx_d2_p), //Adat 2.
 .tmds_data2_out_n(hdmi_tx_d2_n),
 .tmds_clock_out_p(hdmi_tx_clk_p), //Pixel �rajel.
 .tmds_clock_out_n(hdmi_tx_clk_n)
);

endmodule