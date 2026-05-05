`timescale 1ns / 1ps

module mac_array(
    input clk,
    input rst_n,
    input clear_acc,
    input en,
    input  [7:0]  input_data,
    input  [7:0]  weight_data,
    output [31:0] acc_out
    );
endmodule
