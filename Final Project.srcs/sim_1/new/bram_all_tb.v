`timescale 1ns / 1ps

module bram_all_tb;

reg clk;

// input_bram signals
reg input_we;
reg [5:0] input_addr;
reg [7:0] input_din;
wire [7:0] input_dout;

// weight_bram signals
reg weight_we;
reg [11:0] weight_addr;
reg [7:0] weight_din;
wire [7:0] weight_dout;

// output_bram signals
reg output_we;
reg [5:0] output_addr;
reg [31:0] output_din;
wire [31:0] output_dout;

// Instantiate input BRAM
input_bram u_input_bram (.clk(clk), .we(input_we), .addr(input_addr), .din(input_din), .dout(input_dout));

// Instantiate weight BRAM
weight_bram u_weight_bram (.clk(clk), .we(weight_we), .addr(weight_addr), .din(weight_din), .dout(weight_dout));

// Instantiate output BRAM
output_bram u_output_bram (.clk(clk), .we(output_we), .addr(output_addr), .din(output_din), .dout(output_dout));

// 10 ns clock
always #5 clk = ~clk;

initial begin
    
    //clear all vals
    clk = 0;
    input_we = 0; input_addr = 0; input_din = 0;
    weight_we = 0;  weight_addr = 0; weight_din = 0;
    output_we = 0; output_addr = 0; output_din = 0;
    #10;

    //Input bram test
    $display("Testing input_bram:");

    input_addr = 6'd3; input_din = 8'h2A; input_we = 1; #10;
    input_we = 0; input_addr = 6'd3; #10;

    if (input_dout == 8'h2A)
        $display("PASS input_bram: expected 2A, got %h", input_dout);
    else
        $display("FAIL input_bram: expected 2A, got %h", input_dout);

    //Weight bram test
    $display("Testing weight_bram:");

    weight_addr = 12'd100; weight_din = 8'h7F; weight_we = 1; #10;
    weight_we = 0; weight_addr = 12'd100; #10;

    if (weight_dout == 8'h7F)
        $display("PASS weight_bram: expected 7F, got %h", weight_dout);
    else
        $display("FAIL weight_bram: expected 7F, got %h", weight_dout);

    //Output bram test
    $display("Testing output_bram...");

    output_addr = 6'd5; output_din = 32'h0000_1234; output_we = 1; #10;
    output_we = 0; output_addr = 6'd5; #10;

    if (output_dout == 32'h0000_1234)
        $display("PASS output_bram: expected 00001234, got %h", output_dout);
    else
        $display("FAIL output_bram: expected 00001234, got %h", output_dout);
    
    //Finished
    $display("BRAM tests complete.");
    #10;
    $finish;
end

endmodule