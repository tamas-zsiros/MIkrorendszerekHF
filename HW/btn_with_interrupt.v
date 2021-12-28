module btn_with_interrupt(
    //Órajel és reset.
    input  wire        clk,         //100 MHz rendszerórajel
    input  wire        rst,         //Aktív magas szinkron reset
    
    //Regiszter írási interfész.
    input  wire [3:0]  wr_addr,     //Írási cím
    input  wire        wr_en,       //Írás engedélyezõ jel
    input  wire [31:0] wr_data,     //Írási adat
    input  wire [3:0]  wr_strb,     //Bájt engedélyezõ jelek
    
    //Regiszter olvasási interfész.
    input  wire [3:0]  rd_addr,     //Olvasási cím
    input  wire        rd_en,       //Olvasás engedélyezõ jel
    output reg  [31:0] rd_data,     //Olvasási adat      
    
    //Adat a folyadék érzékelõktõl.
    input  wire [3:0]  btn_in,
    
    //Megszakításkérõ kimenet.
    output wire        irq
);

//******************************************************************************
//* A szenzor bemeneteket 10 Hz frekvenciával mintavételezzük. Az ütemezõ jel  *
//* egy 24 bites számlálóval állítható elõ (9999999 - 0 => 24 bit).            *
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

wire error = btn_reg == 4'b0111; // all button was pushed

//******************************************************************************
//* A regiszterek írási és olvasási engedélyezõ jeleinek elõállítása.          *
//*                                                                            *
//* Folyadékszint regiszter     : BASEADDR+0x00, 32 bites, RD                  *
//* Megszakítás engedélyezõ reg.: BASEADDR+0x04, 32 bites, R/W                 *
//* Megszakítás flag regiszter  : BASEADDR+0x08, 32 bites, R/W1C               *
//******************************************************************************
//A folyadékszint regiszter olvasás engedélyezõ jele.
wire lvl_rd = rd_en & (rd_addr[3:2] == 2'd0);

//A megszakítás engedélyezõ regiszter írás és olvasás engedélyezõ jele.
wire ier_wr = wr_en & (wr_addr[3:2] == 2'd1) & (wr_strb == 4'b1111);
wire ier_rd = rd_en & (rd_addr[3:2] == 2'd1);

//A megszakítás flag regiszter írás és olvasás engedélyezõ jele.
wire ifr_wr = wr_en & (wr_addr[3:2] == 2'd2) & (wr_strb == 4'b1111);
wire ifr_rd = rd_en & (rd_addr[3:2] == 2'd2);


wire [31:0] lvl;

assign lvl[3:0]  = btn_reg;
assign lvl[30:4] = 27'd0;
assign lvl[31]   = error;

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

assign ifr_set[0] = (speedup_samples == 2'b01);

assign ifr_set[1] = (gamereset_samples == 2'b01);

assign ifr_set[2] = (err_samples == 2'b01);

integer i;

//A megszakítás flag regisztert egyetlen always blokkban írjuk le, FOR
//ciklussal indexelve a biteket. A bitek beállítása nagyobb prioritású
//az '1' beírásának hatására megtörténõ törlésnél.
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

//Jelezzük a megszakításkérést, ha van aktív esemény, amely engedélyezett is.
assign irq = |(ier & ifr);

//******************************************************************************
//* Az olvasási adatbusz meghajtása.                                           *
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