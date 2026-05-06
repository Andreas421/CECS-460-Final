`timescale 1ns / 1ps

module fsm_ctrl_tb;

reg clk;
reg rst_n;
reg start;
reg [7:0] input_dout;
reg [7:0] weight_dout;
reg [31:0] mac_acc_out;

wire done;
wire output_we;
wire mac_clear;
wire mac_en;
wire [5:0] input_addr;
wire [11:0] weight_addr;
wire [5:0] output_addr;
wire [31:0] output_din;

fsm_ctrl dut (.clk(clk), .rst_n(rst_n), .start(start), .input_dout(input_dout),
    .weight_dout(weight_dout), .mac_acc_out(mac_acc_out), .done(done),
    .output_we(output_we), .mac_clear(mac_clear), .mac_en(mac_en), .input_addr(input_addr),
    .weight_addr(weight_addr), .output_addr(output_addr), .output_din(output_din));

// 10 ns clock
always #5 clk = ~clk;

initial begin
    clk = 0; rst_n = 0; start = 0; input_dout = 8'd0; 
    weight_dout = 8'd0; mac_acc_out = 32'd0;

    // reset
    #20; rst_n = 1;

    // start computation
    #10; start = 1;

    // fake accumulator changing over time
    repeat (20000) begin
        #10;
        mac_acc_out = mac_acc_out + 1;
    end

    // release start after done is seen
    start = 0; #100; $finish;
end

initial begin
    $monitor(
        "t=%0t state=%0d row=%0d col=%0d in_addr=%0d w_addr=%0d mac_clr=%b mac_en=%b out_we=%b out_addr=%0d done=%b",
        $time, dut.state, dut.row, dut.col, input_addr, weight_addr,
        mac_clear, mac_en, output_we, output_addr, done);
end

endmodule