module btn_with_interrupt(
    //�rajel �s reset.
    input  wire        clk,         //100 MHz rendszer�rajel
    input  wire        rst,         //Akt�v magas szinkron reset
    
    //Regiszter �r�si interf�sz.
    input  wire [3:0]  wr_addr,     //�r�si c�m
    input  wire        wr_en,       //�r�s enged�lyez� jel
    input  wire [31:0] wr_data,     //�r�si adat
    input  wire [3:0]  wr_strb,     //B�jt enged�lyez� jelek
    
    //Regiszter olvas�si interf�sz.
    input  wire [3:0]  rd_addr,     //Olvas�si c�m
    input  wire        rd_en,       //Olvas�s enged�lyez� jel
    output reg  [31:0] rd_data,     //Olvas�si adat      
    
    //Adat a folyad�k �rz�kel�kt�l.
    input  wire [3:0]  btn_in,
    
    //Megszak�t�sk�r� kimenet.
    output wire        irq
);

//******************************************************************************
//* A szenzor bemeneteket 10 Hz frekvenci�val mintav�telezz�k. Az �temez� jel  *
//* egy 24 bites sz�ml�l�val �ll�that� el� (9999999 - 0 => 24 bit).            *
//******************************************************************************
reg  [23:0] clk_div;
wire        clk_div_tc = (clk_div == 24'd0);

always @(posedge clk)
begin
   if (rst || clk_div_tc)
      clk_div <= 24'd9999999;
   else
      clk_div <= clk_div - 24'd1;
end

reg [3:0] btn_reg;

always @(posedge clk)
begin
   if (rst)
      btn_reg <= 8'd0;
   else
      if (clk_div_tc)
         btn_reg <= btn_in;
end

//******************************************************************************
//* A szenzor bemenet alapj�n a folyad�kszintet egy priorit�s enk�derrel       *
//* �ll�thatjuk el�. A legnagyobb sorsz�m� akt�v bit hat�rozza meg a           *
//* folyad�kszint �rt�k�t.                                                     *
//******************************************************************************
//kinda useless
reg [3:0] fluid_level;

always @(posedge clk)
begin
   if (rst)
      fluid_level <= 4'd0;
   else
      casex (btn_reg)
         8'b0000_0000: fluid_level <= 4'd0;
         8'b0000_0001: fluid_level <= 4'd1;
         8'b0000_001x: fluid_level <= 4'd2;
         8'b0000_01xx: fluid_level <= 4'd3;
         8'b0000_1xxx: fluid_level <= 4'd4;
         8'b0001_xxxx: fluid_level <= 4'd5;
         8'b001x_xxxx: fluid_level <= 4'd6;
         8'b01xx_xxxx: fluid_level <= 4'd7;
         8'b1xxx_xxxx: fluid_level <= 4'd8;
      endcase
end

reg [3:0] dir_reg; // which direction to go = which button was button was pushod

always @(posedge clk)
begin
   if (rst)
      dir_reg <= 4'd0;
   else
      casex (btn_reg)
         4'b0000: dir_reg <= 4'd0;
         4'b0001: dir_reg <= 4'd1;
         4'b0010: dir_reg <= 4'd2;
         4'b0011: dir_reg <= 4'd0;  // both pushed, keep going straight
         4'b01xx: dir_reg <= 4'd4;  // speed up?
         4'b1xxx: dir_reg <= 4'd8;
         default: dir_reg <= 4'd0;
      endcase
end

//******************************************************************************
//* A hibajelz�s el��ll�t�sa. �rv�nyes a szenzor bemeneten l�v� adat, ha       *
//* a legnagyobb sorsz�m� akt�v bemeneti bit alatti �sszes bit is akt�v.       *
//******************************************************************************
wire error = btn_reg == 4'b0111; // all button was pushed

//******************************************************************************
//* A regiszterek �r�si �s olvas�si enged�lyez� jeleinek el��ll�t�sa.          *
//*                                                                            *
//* Folyad�kszint regiszter     : BASEADDR+0x00, 32 bites, RD                  *
//* Megszak�t�s enged�lyez� reg.: BASEADDR+0x04, 32 bites, R/W                 *
//* Megszak�t�s flag regiszter  : BASEADDR+0x08, 32 bites, R/W1C               *
//******************************************************************************
//A folyad�kszint regiszter olvas�s enged�lyez� jele.
wire lvl_rd = rd_en & (rd_addr[3:2] == 2'd0);

//A megszak�t�s enged�lyez� regiszter �r�s �s olvas�s enged�lyez� jele.
wire ier_wr = wr_en & (wr_addr[3:2] == 2'd1) & (wr_strb == 4'b1111);
wire ier_rd = rd_en & (rd_addr[3:2] == 2'd1);

//A megszak�t�s flag regiszter �r�s �s olvas�s enged�lyez� jele.
wire ifr_wr = wr_en & (wr_addr[3:2] == 2'd2) & (wr_strb == 4'b1111);
wire ifr_rd = rd_en & (rd_addr[3:2] == 2'd2);

//******************************************************************************
//* Folyad�kszint regiszter: BASEADDR+0x00, 32 bites, csak olvashat�           *
//*                                                                            *
//*    31    30          4     3     2     1     0                             *
//*  -----------------------------------------------                           *
//* |ERROR|  0   ....    0  |  folyad�kszint (0-8)  |                          *
//*  -----------------------------------------------                           * 
//******************************************************************************
wire [31:0] lvl;

assign lvl[3:0]  = btn_reg;
assign lvl[30:4] = 27'd0;
assign lvl[31]   = error;

//******************************************************************************
//* Megszak�t�s enged�lyez� reg.: BASEADDR+0x04, 32 bites, �rhat�/olvashat�    *
//*                                                                            *
//*    31          5     4     3     2     1     0                             *
//*  -----------------------------------------------                           *
//* |  x    ....   x     x    x   |ERROR|EMPTY| FULL|                          *
//*  -----------------------------------------------                           *
//******************************************************************************
reg [2:0] ier;

// error, game reset, speedup

always @(posedge clk)
begin
   if (rst)
      ier <= 3'b000;
   else
      if (ier_wr)
         ier <= wr_data[2:0];
end

//******************************************************************************
//* Megszak�t�s flag regiszter: BASEADDR+0x08, 32 bites, olvashat� �s a jelz�s *
//*                             '1' be�r�s�val t�r�lhet�                       *
//*                                                                            *
//*    31          5     4     3     2     1     0                             *
//*  -----------------------------------------------                           *
//* |  x    ....   x     x    x   |ERROR|EMPTY| FULL|                          *
//*  -----------------------------------------------                           *
//******************************************************************************
//Mintav�telez�s a felfut� �l detekt�l�s�hoz.
reg [1:0] speedup_samples;
reg [1:0] gamereset_samples;
reg [1:0] err_samples;

always @(posedge clk)
begin
   if (rst)
   begin
      speedup_samples <= 2'b11;
      gamereset_samples <= 2'b11;
      err_samples  <= 2'b11;
   end
   else
   begin
      speedup_samples <= {speedup_samples[0], (dir_reg == 4'd8)};
      gamereset_samples <= {gamereset_samples[0], (dir_reg == 4'd4)};
      err_samples  <= {err_samples[0], error};
   end
end

reg  [2:0] ifr;
wire [2:0] ifr_set;

//A tart�ly �ppen megtelt (FULL): a folyad�kszint 8-ra v�lt -> felfut� �l detekt�l�s.
assign ifr_set[0] = (speedup_samples == 2'b01);
//A tart�ly �ppen ki�r�lt (EMPTY): a folyad�kszint 0-ra v�lt -> felfut� �l detekt�l�s.
assign ifr_set[1] = (gamereset_samples == 2'b01);
//Hiba t�rt�nt (ERROR): felfut� �l a hibajelz�sen.
assign ifr_set[2] = (err_samples == 2'b01);

integer i;

//A megszak�t�s flag regisztert egyetlen always blokkban �rjuk le, FOR
//ciklussal indexelve a biteket. A bitek be�ll�t�sa nagyobb priorit�s�
//az '1' be�r�s�nak hat�s�ra megt�rt�n� t�rl�sn�l.
always @(posedge clk)
begin
   for (i = 0; i < 3; i = i + 1)
      if (rst)
         ifr[i] <= 1'b0;
      else
         if (ifr_set[i])
            ifr[i] <= 1'b1;
         else
            if (ifr_wr && wr_data[i])
               ifr[i] <= 1'b0;
end

//Jelezz�k a megszak�t�sk�r�st, ha van akt�v esem�ny, amely enged�lyezett is.
assign irq = |(ier & ifr);

//******************************************************************************
//* Az olvas�si adatbusz meghajt�sa.                                           *
//******************************************************************************
always @(*)
begin
	case ({ifr_rd, ier_rd, lvl_rd})
		3'b001 : rd_data <= lvl;
		3'b010 : rd_data <= {29'd0, ier};
		3'b100 : rd_data <= {29'd0, ifr};
		default: rd_data <= 32'd0;
	endcase
end

endmodule

`default_nettype wire