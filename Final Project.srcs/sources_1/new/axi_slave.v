`timescale 1ns / 1ps

module axi_slave(
    //WRITE ADDRESS CHANNEL
    input  [31:0] S_AXI_AWADDR,   //Write Address
    input         S_AXI_AWVALID,  //Write Address Valid
    output        S_AXI_AWREADY,  //Write Address Ready
    //WRITE DATA CHANNEL
    input  [31:0] S_AXI_WDATA,    //Write Data
    input  [3:0]  S_AXI_WSTRB,    //Write Strobe - which byte lanes of WDATA are valid
    input         S_AXI_WVALID,   //Write Data Valid 
    output        S_AXI_WREADY,   //Write Data Ready 
    //WRITE RESPONSE CHANNEL
    input         S_AXI_BREADY,   //Write Response Ready
    output [1:0]  S_AXI_BRESP,    //Write Response 
    output        S_AXI_BVALID,   //Write Response Valid 
    //READ ADDRESS CHANNEL
    input  [31:0] S_AXI_ARADDR,   //Read Address 
    input         S_AXI_ARVALID,  //Read Address Valid 
    output        S_AXI_ARREADY,  //Read Address Ready 
    //READ DATA CHANNEL
    input         S_AXI_RREADY,   //Read Data Ready 
    output [31:0] S_AXI_RDATA,    //Read Data 
    output [1:0]  S_AXI_RRESP,    //Read Response
    output        S_AXI_RVALID,   //Read Data Valid    
    //BRAM SIGNALS
    output        start,
    input         done,
        //input_bram.v
        output        input_we,
        output [5:0]  input_addr,
        output [7:0]  input_din,
        //weight_bram.v
        output        weight_we,
        output [11:0] weight_addr,
        output [7:0]  weight_din,
        //output_bram.v
        output [5:0]  output_addr,
        input  [31:0] output_dout,
    //OTHER SIGNALS
    input         S_AXI_ACLK,     //Clock    
    input         S_AXI_ARESETN   //Active-low Reset  
    
);
    
    
    
    
    
    
    
    
    
    
    
endmodule
