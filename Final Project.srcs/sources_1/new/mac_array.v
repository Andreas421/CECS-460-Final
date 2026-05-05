`timescale 1ns / 1ps

module mac_array(
    input clk,
    input rst_n,
    input clear_acc,
    input en,
    input signed [7:0]  input_data,
    input signed [7:0]  weight_data,
    output [31:0] acc_out
    );
    
    reg signed [31:0] acc;
    
    assign acc_out = acc;
    
    always @(posedge clk or negedge rst_n) begin
        if(!rst_n)  //clear values if reset
            acc <= 0;
        else if(clear_acc) //clear values if acc_clear driven high
            acc <= 0;
        else if(en) //perform multiply accumulate if enable driven high
            acc <= acc + (input_data * weight_data);
    end
    
    
       
endmodule
