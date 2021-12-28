`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: 
// 
// Create Date: 13.11.2021 07:46:41
// Design Name: 
// Module Name: axi4_lite_if
// Project Name: 
// Target Devices: 
// Tool Versions: 
// Description: 
// 
// Dependencies: 
// 
// Revision:
// Revision 0.01 - File Created
// Additional Comments:
// 
//////////////////////////////////////////////////////////////////////////////////


//******************************************************************************
//* AXI4-Lite interfész.                                                       *
//******************************************************************************
module axi4_lite_if #(
    //A használt címbitek száma.
    parameter ADDR_BITS = 8
) (
    //Órajel és reset.
    input  wire                 clk,            //Rendszerórajel
    input  wire                 rst,            //Aktív magas szinkron reset
    
    //AXI4-Lite írási cím csatorna.
    input  wire [ADDR_BITS-1:0] s_axi_awaddr,
    input  wire                 s_axi_awvalid,
    output wire                 s_axi_awready,
    
    //AXI4-Lite írási adat csatorna.
    input  wire [31:0]          s_axi_wdata,
    input  wire [3:0]           s_axi_wstrb,
    input  wire                 s_axi_wvalid,
    output wire                 s_axi_wready,
    
    //AXI4-Lite írási válasz csatorna.
    output wire [1:0]           s_axi_bresp,
    output wire                 s_axi_bvalid,
    input  wire                 s_axi_bready,
    
    //AXI4-Lite olvasási cím csatorna.
    input  wire [ADDR_BITS-1:0] s_axi_araddr,
    input  wire                 s_axi_arvalid,
    output wire                 s_axi_arready,
    
    //AXI4-Lite olvasási adat csatorna.
    output reg  [31:0]          s_axi_rdata,
    output wire [1:0]           s_axi_rresp,
    output wire                 s_axi_rvalid,
    input  wire                 s_axi_rready,
    
    //Regiszter írási interfész.
    output reg  [3:0]           wr_addr,        //Írási cím
    output wire                 wr_en,          //Írás engedélyezõ jel
    output reg  [31:0]          wr_data,        //Írási adat
    output reg  [3:0]           wr_strb,        //Bájt engedélyezõ jelek
    
    //Regiszter olvasási interfész.
    output reg  [3:0]           rd_addr,        //Olvasási cím
    output wire                 rd_en,          //Olvasás engedélyezõ jel
    input  wire [31:0]          rd_data         //Olvasási adat
);

//******************************************************************************
//* Írási állapotgép.                                                          *
//******************************************************************************
localparam WR_ADDR_WAIT = 2'd0;
localparam WR_DATA_WAIT = 2'd1;
localparam WR_EXECUTE   = 2'd2;
localparam WR_RESPONSE  = 2'd3;

reg [1:0] wr_state;

always @(posedge clk)
begin
    if (rst)
        wr_state <= WR_ADDR_WAIT;
    else
        case (wr_state)
            //Váraozás az írási címre.
            WR_ADDR_WAIT: if (s_axi_awvalid)
                          begin
                             wr_addr  <= s_axi_awaddr[3:0];
                             wr_state <= WR_DATA_WAIT;
                          end
                          else
                             wr_state <= WR_ADDR_WAIT;
            
            //Várakozás az írási adatra.                
            WR_DATA_WAIT: if (s_axi_wvalid)
                          begin
                             wr_data  <= s_axi_wdata;
                             wr_strb  <= s_axi_wstrb;
                             wr_state <= WR_EXECUTE;
                          end
                          else
                             wr_state <= WR_DATA_WAIT;
            
            //Az írási mûvelet végrehajtása.
            WR_EXECUTE  : wr_state <= WR_RESPONSE;
            
            //A nyugtázás elküldése.
            WR_RESPONSE : if (s_axi_bready)
                             wr_state <= WR_ADDR_WAIT;
                          else
                             wr_state <= WR_RESPONSE;
        endcase
end

//Az írási cím csatorna READY jelzésének elõállítása.
assign s_axi_awready = (wr_state == WR_ADDR_WAIT);
//Az írási adat csatorna READY jelzésének elõállítása.
assign s_axi_wready  = (wr_state == WR_DATA_WAIT);
//Az írási válasz csatorna VALID jelzésének elõállítása.
assign s_axi_bvalid  = (wr_state == WR_RESPONSE);
//Mindog OKAY (00) nyugtát küldünk.
assign s_axi_bresp   = 2'b00;

//A regiszerek írás engedélyezõ jelének elõállítása.
assign wr_en = (wr_state == WR_EXECUTE);


//******************************************************************************
//* Olvasási állapotgép.                                                       *
//******************************************************************************
localparam RD_ADDR_WAIT = 2'd0;
localparam RD_EXECUTE   = 2'd1;
localparam RD_SEND_DATA = 2'd2;

reg [1:0] rd_state;

always @(posedge clk)
begin
    if (rst)
        rd_state <= RD_ADDR_WAIT;
    else
        case (rd_state)
            //Váraozás az olvasási címre.
            RD_ADDR_WAIT: if (s_axi_arvalid)
                          begin
                             rd_addr  <= s_axi_araddr[3:0];
                             rd_state <= RD_EXECUTE;
                          end
                          else
                             rd_state <= RD_ADDR_WAIT;
            
            //Az olvasási mûvelet végrehajtása.
            RD_EXECUTE  : begin
                             s_axi_rdata <= rd_data;
                             rd_state <= RD_SEND_DATA;
                          end
            
            //A beolvasott adat elküldése.
            RD_SEND_DATA: if (s_axi_rready)
                          begin
                             s_axi_rdata <= 32'd0;
                             rd_state <= RD_ADDR_WAIT;
                          end
                          else
                             rd_state <= RD_SEND_DATA;
            
            //Érvénytelen állapotok.
            default     : rd_state <= RD_ADDR_WAIT;
        endcase
end

//Az olvasási cím csatorna READY jelzésének elõállítása.
assign s_axi_arready = (rd_state == RD_ADDR_WAIT);
//Az olvasási adat csatorna VALID jelzésének elõállítása.
assign s_axi_rvalid  = (rd_state == RD_SEND_DATA);
//Mindog OKAY (00) nyugtát küldünk.
assign s_axi_rresp   = 2'b00;

//A regiszerek olvasás engedélyezõ jelének elõállítása.
assign rd_en = (rd_state == RD_EXECUTE);

endmodule

`default_nettype wire
