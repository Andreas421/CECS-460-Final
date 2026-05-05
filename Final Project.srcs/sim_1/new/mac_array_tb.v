`timescale 1ns / 1ps

module mac_array_tb;

reg clk;
reg rst_n;
reg clear_acc;
reg en;
reg signed [7:0] input_data;
reg signed [7:0] weight_data;
wire [31:0] acc_out;

// Instantiate DUT 
mac_array dut (
    .clk(clk),
    .rst_n(rst_n),
    .clear_acc(clear_acc),
    .en(en),
    .input_data(input_data),
    .weight_data(weight_data),
    .acc_out(acc_out)
);

// Clock: 10ns period
always #5 clk = ~clk;

initial begin
    // Initialize signals
    clk = 0;
    rst_n = 0;
    clear_acc = 0;
    en = 0;
    input_data = 0;
    weight_data = 0;

    // Apply reset
    #10;
    rst_n = 1;

    // --- Test 1: 2 * 3 = 6 ---
    clear_acc = 1; #10;
    clear_acc = 0;

    input_data = 2;
    weight_data = 3;
    en = 1; #10;

    // --- Test 2: accumulate 4 * 5 = 20 ? total = 26 ---
    input_data = 4;
    weight_data = 5;
    #10;

    en = 0;

    // --- Test 3: signed test (-2 * 3 = -6) ---
    clear_acc = 1; #10;
    clear_acc = 0;

    input_data = -2;
    weight_data = 3;
    en = 1; #10;
    en = 0;

    // --- Finish ---
    #20;
    $finish;
end

// Monitor output
initial begin
    $monitor("time=%0t | in=%0d w=%0d en=%b clear=%b acc=%0d",
              $time, input_data, weight_data, en, clear_acc, acc_out);
end

endmodule