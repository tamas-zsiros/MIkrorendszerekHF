//******************************************************************************
//* 1440 x 900 @ 60 Hz VGA idõzítés generátor. *
//******************************************************************************
module vga_timing(
 //Órajel és reset.
 input wire clk, //Pixel órajel bemenet.
 input wire rst, //Reset bemenet.

 //Az aktuális pixel pozíció.
 output reg [10:0] h_cnt = 11'd0, //X-koordináta.
 output reg [9:0] v_cnt = 10'd0, //Y-koordináta.

 //Szinkron és kioltó jelek.
 output reg h_sync = 1'b1, //Horizontális szinkron pulzus.
 output reg v_sync = 1'b0, //Vertikális szinkron pulzus.
 output wire blank //Kioltó jel.
);

//******************************************************************************
//* Idõzítési paraméterek. *
//******************************************************************************
localparam H_VISIBLE = 11'd640;
localparam H_FRONT_PORCH = 11'd16;
localparam H_SYNC_PULSE = 11'd96;
localparam H_BACK_PORCH = 11'd48;
localparam V_VISIBLE = 10'd480;
localparam V_FRONT_PORCH = 10'd10;
localparam V_SYNC_PULSE = 10'd2;
localparam V_BACK_PORCH = 10'd33;
localparam H_BLANK_BEGIN = H_VISIBLE - 1;
localparam H_SYNC_BEGIN = H_BLANK_BEGIN + H_FRONT_PORCH;
localparam H_SYNC_END = H_SYNC_BEGIN + H_SYNC_PULSE;
localparam H_BLANK_END = H_SYNC_END + H_BACK_PORCH;
localparam V_BLANK_BEGIN = V_VISIBLE - 1;
localparam V_SYNC_BEGIN = V_BLANK_BEGIN + V_FRONT_PORCH;
localparam V_SYNC_END = V_SYNC_BEGIN + V_SYNC_PULSE;
localparam V_BLANK_END = V_SYNC_END + V_BACK_PORCH;

//******************************************************************************
//* A horizontális és vertikális számlálók. *
//******************************************************************************
always @(posedge clk)
begin
 if (rst || (h_cnt == H_BLANK_END))
 h_cnt <= 12'd0;
 else
 h_cnt <= h_cnt + 12'd1;
end
always @(posedge clk)
begin
 if (rst)
 v_cnt <= 11'd0;
 else
 if (h_cnt == H_BLANK_END)
 if (v_cnt == V_BLANK_END)
 v_cnt <= 11'd0;
 else
 v_cnt <= v_cnt + 11'd1;
end

//******************************************************************************
//* A szinkron pulzusok generálása. *
//******************************************************************************
always @(posedge clk)
begin
 if (rst || (h_cnt == H_SYNC_END))
 h_sync <= 1'b1;
 else
 if (h_cnt == H_SYNC_BEGIN)
 h_sync <= 1'b0;
end
always @(posedge clk)
begin
 if (rst)
 v_sync <= 1'b0;
 else
 if (h_cnt == H_BLANK_END)
 if (v_cnt == V_SYNC_BEGIN)
 v_sync <= 1'b1;
 else
 if (v_cnt == V_SYNC_END)
 v_sync <= 1'b0;
end
//******************************************************************************
//* A kioltó jel elõállítása. *
//******************************************************************************
reg h_blank = 1'b0;
reg v_blank = 1'b0;
always @(posedge clk)
begin
 if (rst || (h_cnt == H_BLANK_END))
 h_blank <= 1'b0;
 else
 if (h_cnt == H_BLANK_BEGIN)
 h_blank <= 1'b1;
end

always @(posedge clk)
begin
 if (rst)
 v_blank <= 1'b0;
 else
 if (h_cnt == H_BLANK_END)
 if (v_cnt == V_BLANK_BEGIN)
 v_blank <= 1'b1;
 else
 if (v_cnt == V_BLANK_END)
 v_blank <= 1'b0;
end
assign blank = h_blank | v_blank;
endmodule


//******************************************************************************
//* TMDS kódoló. *
//******************************************************************************
module tmds_encoder(
 //Órajel és reset.
 input wire clk, //Pixel órajel bemenet.
 input wire rst, //Aszinkron reset bemenet.

 //Bemenõ adat.
 input wire [7:0] data_in, //A kódolandó pixel adat.
 input wire data_en, //A látható képtartomány jelzése.
 input wire ctrl0_in, //Vezérlõjelek.
 input wire ctrl1_in,

 //Kimenõ adat.
 output reg [9:0] tmds_out
);
//*****************************************************************************
//* Az "1" értékû bitek számának meghatározása a bejövõ pixel adatokban. *
//* A pipeline fokozatok száma: 1 *
//*****************************************************************************
reg [7:0] data_in_reg;
reg [3:0] din_num_1s;
always @(posedge clk)
begin
 data_in_reg <= data_in;
 din_num_1s <= ((data_in[0] + data_in[1]) + (data_in[2] + data_in[3])) +
 ((data_in[4] + data_in[5]) + (data_in[6] + data_in[7]));
end
//*****************************************************************************
//* A TMDS kódolás elsõ lépése: 8 bitrõl 9 bitre történõ átalakítás. *
//* A pipeline fokozatok száma: 1 *
//*****************************************************************************
wire [8:0] stage1;
reg [8:0] stage1_out;
//Az elsõ döntési feltétel:
//- az "1" bitek száma nagyobb 4-nél vagy
//- az "1" bitek száma 4 és a bejövõ adat LSb-je 0.
wire decision1 = (din_num_1s > 4'd4) | ((din_num_1s == 4'd4) & ~data_in_reg[0]);
assign stage1[0] = data_in_reg[0];
assign stage1[1] = (stage1[0] ^ data_in_reg[1]) ^ decision1;
assign stage1[2] = (stage1[1] ^ data_in_reg[2]) ^ decision1;
assign stage1[3] = (stage1[2] ^ data_in_reg[3]) ^ decision1;
assign stage1[4] = (stage1[3] ^ data_in_reg[4]) ^ decision1;
assign stage1[5] = (stage1[4] ^ data_in_reg[5]) ^ decision1;
assign stage1[6] = (stage1[5] ^ data_in_reg[6]) ^ decision1;
assign stage1[7] = (stage1[6] ^ data_in_reg[7]) ^ decision1;
assign stage1[8] = ~decision1;
always @(posedge clk)
begin
 stage1_out <= stage1;
end
//*****************************************************************************
//* Az "1" értékû bitek számának meghatározása az elsõ lépés kimenetében. *
//* A pipeline fokozatok száma: 1 *
//*****************************************************************************
reg [8:0] stage2_in;
reg [3:0] s1_num_1s;
always @(posedge clk)
begin
 stage2_in <= stage1_out;
 s1_num_1s <= ((stage1_out[0] + stage1_out[1]) + (stage1_out[2] + stage1_out[3])) +
 ((stage1_out[4] + stage1_out[5]) + (stage1_out[6] + stage1_out[7]));
end
//*****************************************************************************
//* Pipeline regiszterek az engedélyezõ és a vezérlõ jelek számára. *
//*****************************************************************************
reg [2:0] data_en_reg;
reg [5:0] ctrl_reg;
always @(posedge clk)
begin
 if (rst)
 data_en_reg <= 3'd0;
 else
 data_en_reg <= {data_en_reg[1:0], data_en};
end
always @(posedge clk)
begin
 if (rst)
 ctrl_reg <= 6'd0;
 else
 ctrl_reg <= {ctrl_reg[3:0], ctrl1_in, ctrl0_in};
end
//*****************************************************************************
//* A TMDS kódolás második lépése: 9 bitrõl 10 bitre történõ átalakítás. *
//*****************************************************************************
localparam CTRL_TOKEN_0 = 10'b1101010100;
localparam CTRL_TOKEN_1 = 10'b0010101011;
localparam CTRL_TOKEN_2 = 10'b0101010100;
localparam CTRL_TOKEN_3 = 10'b1010101011;
//A kimeneti "0" és "1" bitek számának különbsége (MSb az elõjel bit).
reg [4:0] cnt;
//A második döntési feltétel:
//- az eddig kiadott "0" és "1" bitek száma azonos vagy
//- az elsõ lépés kimenetének alsó 8 bitjén a "0" és az "1" bitek száma azonos.
wire decision2 = (cnt == 5'd0) | (s1_num_1s == 4'd4);
//A harmadik döntési feltétel:
//- eddig több "1" bit került elküldésre, mint "0" és az elsõ lépés kimenetében
// az "1" értékû bitek száma a nagyobb vagy
//- eddig több "0" bit került elküldésre, mint "1" és az elsõ lépés kimenetében
// a "0" értékû bitek száma a nagyobb
wire decision3 = (~cnt[4] & (s1_num_1s > 4'd4)) | (cnt[4] & (s1_num_1s < 4'd4));
always @(posedge clk or posedge rst)
begin
 if (rst || (data_en_reg[2] == 0))
 cnt <= 5'd0;
 else
 
  if (decision2)
 if (stage2_in[8])
 //cnt = cnt + (#1s - #0s)
 cnt <= cnt + ({s1_num_1s, 1'b0} - 5'd8);
 else
 //cnt = cnt + (#0s - #1s)
 cnt <= cnt + (5'd8 - {s1_num_1s, 1'b0});
 else
 if (decision3)
 //cnt = cnt + 2*stage2_in[8] + (#0s - #1s)
 cnt <= (cnt + {stage2_in[8], 1'b0}) + (5'd8 - {s1_num_1s, 1'b0});
 else
 //cnt = cnt - 2*(~stage2_in[8]) + (#1s - #0s)
 cnt <= (cnt - {~stage2_in[8], 1'b0}) + ({s1_num_1s, 1'b0} - 5'd8);
end
always @(posedge clk or posedge rst)
begin
 if (rst)
 tmds_out <= 10'd0;
 else
 if (data_en_reg[2])
 if (decision2)
 tmds_out <= {~stage2_in[8], stage2_in[8], stage2_in[7:0] ^ {8{~stage2_in[8]}}};
 else
 if (decision3)
 tmds_out <= {1'b1, stage2_in[8], ~stage2_in[7:0]};
 else
 tmds_out <= {1'b0, stage2_in[8], stage2_in[7:0]};
 else
 case (ctrl_reg[5:4])
 2'b00: tmds_out <= CTRL_TOKEN_0;
 2'b01: tmds_out <= CTRL_TOKEN_1;
 2'b10: tmds_out <= CTRL_TOKEN_2;
 2'b11: tmds_out <= CTRL_TOKEN_3;
 endcase
end
endmodule

//******************************************************************************
//* 10:1 párhuzamos-soros átalakító differenciális kimenettel. *
//******************************************************************************
module oserdes_10to1(
 //Órajel és reset.
 input wire clk, //1x órajel bemenet.
 input wire clk_5x, //5x órajel bemenet (DDR mód).
 input wire rst, //Aszinkron reset jel.

 //10 bites adat bemenet.
 input wire [9:0] data_in,

 //Differenciális soros adat kimenet.
 output wire dout_p,
 output wire dout_n
);

//*****************************************************************************
//* Master OSERDES. *
//*****************************************************************************
wire data_to_iob, master_shiftin1, master_shiftin2;
OSERDESE2 #(
 .DATA_RATE_OQ("DDR"),
 .DATA_RATE_TQ("DDR"),
 .DATA_WIDTH(10),
 .INIT_OQ(1'b0),
 .INIT_TQ(1'b0),
 .SERDES_MODE("MASTER"),
 .SRVAL_OQ(1'b0),
 .SRVAL_TQ(1'b0),
 .TBYTE_CTL("FALSE"),
 .TBYTE_SRC("FALSE"),
 .TRISTATE_WIDTH(1)
) master_oserdes (
 .OFB(),
 .OQ(data_to_iob),
 .SHIFTOUT1(),
 .SHIFTOUT2(),
 .TBYTEOUT(),
 .TFB(),
 .TQ(),
 .CLK(clk_5x),
 .CLKDIV(clk),
 .D1(data_in[0]),
 .D2(data_in[1]),
 .D3(data_in[2]),
 .D4(data_in[3]),
 .D5(data_in[4]),
 .D6(data_in[5]),
 .D7(data_in[6]),
 .D8(data_in[7]),
 .OCE(1'b1),
 .RST(rst),
 .SHIFTIN1(master_shiftin1),
 .SHIFTIN2(master_shiftin2),
 .T1(1'b0),
 .T2(1'b0),
 .T3(1'b0),
 .T4(1'b0),
 .TBYTEIN(1'b0),
 .TCE(1'b0)
);
//*****************************************************************************
//* Slave OSERDES. *
//*****************************************************************************
OSERDESE2 #(
 .DATA_RATE_OQ("DDR"),
 .DATA_RATE_TQ("DDR"),
 .DATA_WIDTH(10),
 .INIT_OQ(1'b0),
 .INIT_TQ(1'b0),
 .SERDES_MODE("SLAVE"),
 .SRVAL_OQ(1'b0),
 .SRVAL_TQ(1'b0),
 .TBYTE_CTL("FALSE"),
 .TBYTE_SRC("FALSE"),
 .TRISTATE_WIDTH(1)
) slave_oserdes (
 .OFB(),
 .OQ(),
 .SHIFTOUT1(master_shiftin1),
 .SHIFTOUT2(master_shiftin2),
 .TBYTEOUT(),
 .TFB(),
 .TQ(),
 .CLK(clk_5x),
 .CLKDIV(clk),
 .D1(1'b0),
 .D2(1'b0),
 .D3(data_in[8]),
  .D4(data_in[9]),
 .D5(1'b0),
 .D6(1'b0),
 .D7(1'b0),
 .D8(1'b0),
 .OCE(1'b1),
 .RST(rst),
 .SHIFTIN1(1'b0),
 .SHIFTIN2(1'b0),
 .T1(1'b0),
 .T2(1'b0),
 .T3(1'b0),
 .T4(1'b0),
 .TBYTEIN(1'b0),
 .TCE(1'b0)
);
//*****************************************************************************
//* Differenciális kimeneti buffer. *
//*****************************************************************************
OBUFDS #(
 .IOSTANDARD("TMDS_33"),
 .SLEW("FAST")
) output_buffer (
 .I(data_to_iob),
 .O(dout_p),
 .OB(dout_n)
);
endmodule

//******************************************************************************
//* TMDS adó. *
//******************************************************************************
module tmds_transmitter(
 //Órajel és reset.
 input wire clk, //Pixel órajel bemenet.
 input wire clk_5x, //5x pixel órajel bemenet.
 input wire rst, //Reset jel.

 //Bemeneti video adatok.
 input wire [7:0] red_in, //Piros színkomponens.
 input wire [7:0] green_in, //Zöld színkomponens.
 input wire [7:0] blue_in, //Kék színkomponens.
 input wire blank_in, //A nem látható képtartomány jelzése.
 input wire hsync_in, //Horizontális szinkronjel.
 input wire vsync_in, //Vertikális szinkronjel.

 //Kimenõ TMDS jelek.
 output wire tmds_data0_out_p, //Adat 0.
 output wire tmds_data0_out_n,
 output wire tmds_data1_out_p, //Adat 1.
 output wire tmds_data1_out_n,
 output wire tmds_data2_out_p, //Adat 2.
 output wire tmds_data2_out_n,
 output wire tmds_clock_out_p, //Pixel órajel.
 output wire tmds_clock_out_n
);
//*****************************************************************************
//* A TMDS kódolók példányosítása. *
//*****************************************************************************
wire [9:0] tmds_red, tmds_green, tmds_blue;
tmds_encoder encoder_r(
 //Órajel és reset.
 .clk(clk), //Pixel órajel bemenet.
 .rst(rst), //Aszinkron reset bemenet.

 //Bemenõ adat.
 .data_in(red_in), //A kódolandó pixel adat.
 .data_en(~blank_in), //A látható képtartomány jelzése.
 .ctrl0_in(1'b0), //Vezérlõjelek.
 .ctrl1_in(1'b0),

 //Kimenõ adat.
 .tmds_out(tmds_red)
);
tmds_encoder encoder_g(
 //Órajel és reset.
 .clk(clk), //Pixel órajel bemenet.
 .rst(rst), //Aszinkron reset bemenet.

 //Bemenõ adat.
 .data_in(green_in), //A kódolandó pixel adat.
 .data_en(~blank_in), //A látható képtartomány jelzése.
 .ctrl0_in(1'b0), //Vezérlõjelek.
 .ctrl1_in(1'b0),

 //Kimenõ adat
 .tmds_out(tmds_green)
);
tmds_encoder encoder_b(
 //Órajel és reset.
 .clk(clk), //Pixel órajel bemenet.
 .rst(rst), //Aszinkron reset bemenet.

 //Bemenõ adat.
 .data_in(blue_in), //A kódolandó pixel adat.
 .data_en(~blank_in), //A látható képtartomány jelzése.
 .ctrl0_in(hsync_in), //Vezérlõjelek.
 .ctrl1_in(vsync_in),

 //Kimenõ adat
 .tmds_out(tmds_blue)
);
//*****************************************************************************
//* A párhuzamos-soros átalakítok példányosítása. *
//*****************************************************************************
oserdes_10to1 oserdes0(
 //Órajel és reset.
 .clk(clk), //1x órajel bemenet.
 .clk_5x(clk_5x), //5x órajel bemenet (DDR mód).
 .rst(rst), //Aszinkron reset jel.

 //10 bites adat bemenet.
 .data_in(tmds_blue),

 //Differenciális soros adat kimenet.
 .dout_p(tmds_data0_out_p),
 .dout_n(tmds_data0_out_n)
);
oserdes_10to1 oserdes1(
 //Órajel és reset.
 .clk(clk), //1x órajel bemenet.
 .clk_5x(clk_5x), //5x órajel bemenet (DDR mód).
 .rst(rst), //Aszinkron reset jel.

 //10 bites adat bemenet.
 .data_in(tmds_green),

 //Sifferenciális soros adat kimenet.
 .dout_p(tmds_data1_out_p),
 .dout_n(tmds_data1_out_n)
 );
oserdes_10to1 oserdes2(
 //Órajel és reset.
 .clk(clk), //1x órajel bemenet.
 .clk_5x(clk_5x), //5x órajel bemenet (DDR mód).
 .rst(rst), //Asynchronous reset signal.

 //10 bites adat bemenet.
 .data_in(tmds_red),

 //Differenciális soros adat kimenet.
 .dout_p(tmds_data2_out_p),
 .dout_n(tmds_data2_out_n)
);
//*****************************************************************************
//* TMDS pixel órajel csatorna. *
//*****************************************************************************
wire clk_out;
ODDR #(
 .DDR_CLK_EDGE("OPPOSITE_EDGE"), // "OPPOSITE_EDGE" vagy "SAME_EDGE".
 .INIT(1'b0), // A Q kimenet kezdeti értéke.
 .SRTYPE("ASYNC") // "SYNC" vagy "ASYNC" beállítás/törlés.
) ODDR_clk (
 .Q(clk_out), // 1 bites DDR kimenet.
 .C(clk), // 1 bites órajel bemenet.
 .CE(1'b1), // 1 bites órajel engedélyezõ bemenet.
 .D1(1'b1), // 1 bites adat bemenet (felfutó él).
 .D2(1'b0), // 1 bites adat bemenet (lefutó él).
 .R(rst), // 1 bites törlõ bemenet.
 .S(1'b0) // 1 bites 1-be állító bemenet.
);
OBUFDS #(
 .IOSTANDARD("TMDS_33"),
 .SLEW("FAST")
) OBUFDS_clk (
 .I(clk_out),
 .O(tmds_clock_out_p),
 .OB(tmds_clock_out_n)
);
endmodule