`timescale 1ns / 1ps

//64x1 Int8 vector
module input_bram(
    input clk,
    input we,
    input  [5:0] addr,
    input  [7:0] din,
    output [7:0] dout
    );


(* ram_style = "block" *)
reg[7:0] bram[0:63];
initial begin
//value assignments

end

endmodule