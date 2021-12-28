`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: 
// 
// Create Date: 13.11.2021 07:41:34
// Design Name: 
// Module Name: custom_per
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


module custom_per #(
    //AXI interf�sz param�terek.
    parameter C_S_AXI_DATA_WIDTH = 32,
    parameter C_S_AXI_ADDR_WIDTH = 4
    )
    
    (
    //AXI �rajel �s reset jel.
    (* X_INTERFACE_INFO = "xilinx.com:signal:clock:1.0 s_axi_aclk CLK" *)
    (* X_INTERFACE_PARAMETER = "ASSOCIATED_BUSIF S_AXI, ASSOCIATED_RESET s_axi_aresetn, FREQ_HZ 100000000" *)
    input  wire                              s_axi_aclk,
    (* X_INTERFACE_INFO = "xilinx.com:signal:reset:1.0 s_axi_aresetn RST" *)
    (* X_INTERFACE_PARAMETER = "POLARITY ACTIVE_LOW" *)
    input  wire                              s_axi_aresetn,
    
    //AXI4-Lite �r�si c�m csatorna.
    (* X_INTERFACE_INFO = "xilinx.com:interface:aximm:1.0 S_AXI AWADDR" *)
    (* X_INTERFACE_PARAMETER = "PROTOCOL AXI4LITE" *)
    input  wire [C_S_AXI_ADDR_WIDTH-1:0]     s_axi_awaddr,
    (* X_INTERFACE_INFO = "xilinx.com:interface:aximm:1.0 S_AXI AWVALID" *)
    input  wire                              s_axi_awvalid,
    (* X_INTERFACE_INFO = "xilinx.com:interface:aximm:1.0 S_AXI AWREADY" *)
    output wire                              s_axi_awready,
    
    //AXI4-Lite �r�si adat csatorna.
    (* X_INTERFACE_INFO = "xilinx.com:interface:aximm:1.0 S_AXI WDATA" *)
    input  wire [C_S_AXI_DATA_WIDTH-1:0]     s_axi_wdata,
    (* X_INTERFACE_INFO = "xilinx.com:interface:aximm:1.0 S_AXI WSTRB" *)
    input  wire [(C_S_AXI_DATA_WIDTH/8)-1:0] s_axi_wstrb,
    (* X_INTERFACE_INFO = "xilinx.com:interface:aximm:1.0 S_AXI WVALID" *)
    input  wire                              s_axi_wvalid,
    (* X_INTERFACE_INFO = "xilinx.com:interface:aximm:1.0 S_AXI WREADY" *)
    output wire                              s_axi_wready,
    
    //AXI4-Lite �r�si v�lasz csatorna.
    (* X_INTERFACE_INFO = "xilinx.com:interface:aximm:1.0 S_AXI BRESP" *)
    output wire [1:0]                        s_axi_bresp,
    (* X_INTERFACE_INFO = "xilinx.com:interface:aximm:1.0 S_AXI BVALID" *)
    output wire                              s_axi_bvalid,
    (* X_INTERFACE_INFO = "xilinx.com:interface:aximm:1.0 S_AXI BREADY" *)
    input  wire                              s_axi_bready,
    
    //AXI4-Lite olvas�si c�m csatorna.
    (* X_INTERFACE_INFO = "xilinx.com:interface:aximm:1.0 S_AXI ARADDR" *)
    input  wire [C_S_AXI_ADDR_WIDTH-1:0]     s_axi_araddr,
    (* X_INTERFACE_INFO = "xilinx.com:interface:aximm:1.0 S_AXI ARVALID" *)
    input  wire                              s_axi_arvalid,
    (* X_INTERFACE_INFO = "xilinx.com:interface:aximm:1.0 S_AXI ARREADY" *)
    output wire                              s_axi_arready,
    
    //AXI4-Lite olvas�si adat csatorna.
    (* X_INTERFACE_INFO = "xilinx.com:interface:aximm:1.0 S_AXI RDATA" *)
    output wire [C_S_AXI_DATA_WIDTH-1:0]     s_axi_rdata,
    (* X_INTERFACE_INFO = "xilinx.com:interface:aximm:1.0 S_AXI RRESP" *)
    output wire [1:0]                        s_axi_rresp,
    (* X_INTERFACE_INFO = "xilinx.com:interface:aximm:1.0 S_AXI RVALID" *)
    output wire                              s_axi_rvalid,
    (* X_INTERFACE_INFO = "xilinx.com:interface:aximm:1.0 S_AXI RREADY" *)
    input  wire                              s_axi_rready,
    
    //Adat a nyom�gombokt�l.
    input  wire [3:0]                        btn_in,
        
    //Megszak�t�sk�r� kimenet.
    (* X_INTERFACE_INFO = "xilinx.com:signal:interrupt:1.0 irq INTR" *)
    (* X_INTERFACE_PARAMETER = "SENSITIVITY LEVEL_HIGH" *)
    output wire                              irq
);

//******************************************************************************
//* AXI4-Lite interf�sz.                                                       *
//******************************************************************************
wire [3:0]  wr_addr;
wire        wr_en;
wire [31:0] wr_data;
wire [3:0]  wr_strb;

wire [3:0]  rd_addr;
wire        rd_en;
wire [31:0] rd_data;

axi4_lite_if #(
    //A haszn�lt c�mbitek sz�ma.
    .ADDR_BITS(C_S_AXI_ADDR_WIDTH)
) axi4_lite_if_i (
    //�rajel �s reset.
    .clk(s_axi_aclk),                   //Rendszer�rajel
    .rst(~s_axi_aresetn),               //Akt�v magas szinkron reset
    
    //AXI4-Lite �r�si c�m csatorna.
    .s_axi_awaddr(s_axi_awaddr),
    .s_axi_awvalid(s_axi_awvalid),
    .s_axi_awready(s_axi_awready),
    
    //AXI4-Lite �r�si adat csatorna.
    .s_axi_wdata(s_axi_wdata),
    .s_axi_wstrb(s_axi_wstrb),
    .s_axi_wvalid(s_axi_wvalid),
    .s_axi_wready(s_axi_wready),
    
    //AXI4-Lite �r�si v�lasz csatorna.
    .s_axi_bresp(s_axi_bresp),
    .s_axi_bvalid(s_axi_bvalid),
    .s_axi_bready(s_axi_bready),
    
    //AXI4-Lite olvas�si c�m csatorna.
    .s_axi_araddr(s_axi_araddr),
    .s_axi_arvalid(s_axi_arvalid),
    .s_axi_arready(s_axi_arready),
    
    //AXI4-Lite olvas�si adat csatorna.
    .s_axi_rdata(s_axi_rdata),
    .s_axi_rresp(s_axi_rresp),
    .s_axi_rvalid(s_axi_rvalid),
    .s_axi_rready(s_axi_rready),
    
    //Regiszter �r�si interf�sz.
    .wr_addr(wr_addr),                  //�r�si c�m
    .wr_en(wr_en),                      //�r�s enged�lyez� jel
    .wr_data(wr_data),                  //�r�si adat
    .wr_strb(wr_strb),                  //B�jt enged�lyez� jelek
    
    //Regiszter olvas�si interf�sz.
    .rd_addr(rd_addr),                  //Olvas�si c�m
    .rd_en(rd_en),                      //Olvas�s enged�lyez� jel
    .rd_data(rd_data)                   //Olvas�si adat
);

//******************************************************************************
//* A perif�ria funkci�j�t megval�s�t� modul.                                  *
//******************************************************************************
btn_with_interrupt btn_with_interrupt_i(
    //�rajel �s reset.
    .clk(s_axi_aclk),         //100 MHz rendszer�rajel
    .rst(~s_axi_aresetn),         //Akt�v magas szinkron reset
    
    //Regiszter �r�si interf�sz.
    .wr_addr(wr_addr),     //�r�si c�m
    .wr_en(wr_en),       //�r�s enged�lyez� jel
    .wr_data(wr_data),     //�r�si adat
    .wr_strb(wr_strb),     //B�jt enged�lyez� jelek
    
    //Regiszter olvas�si interf�sz.
    .rd_addr(rd_addr),     //Olvas�si c�m
    .rd_en(rd_en),       //Olvas�s enged�lyez� jel
    .rd_data(rd_data),     //Olvas�si adat      

    .btn_in(btn_in),
    
    //Megszak�t�sk�r� kimenet.
    .irq(irq)
);
endmodule

`default_nettype wire
