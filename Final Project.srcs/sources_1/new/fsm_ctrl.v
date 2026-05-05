`timescale 1ns / 1ps

module fsm_ctrl(
    input clk,
    input rst_n,
    input start,
    input  [7:0]  input_dout,
    input  [7:0]  weight_dout,
    input  [31:0] mac_acc_out,
    output done,
    output output_we,
    output mac_clear,
    output mac_en,
    output [5:0]  input_addr,
    output [11:0] weight_addr,
    output [5:0]  output_addr,
    output [31:0] output_din
    );
    
endmodule
