`timescale 1ns / 1ps

//64x1 Int32 vector
module output_bram(
    input clk,
    input we,
    input  [5:0]  addr,
    input  [31:0] din,
    output [31:0] dout
    );

(* ram_style = "block" *)
reg[31:0] bram[0:63];
reg[31:0] dout_reg; //32 bit output length

assign dout = dout_reg;

always @(posedge clk) begin
    if(we)
        bram[addr] <= din;
    dout_reg <= bram[addr];
end


endmodule