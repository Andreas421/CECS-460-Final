`timescale 1ns / 1ps

module fsm_ctrl(
    input clk,
    input rst_n,
    input start,
    input  [7:0]  input_dout,
    input  [7:0]  weight_dout,
    input  [31:0] mac_acc_out,
    output reg done,
    output wire busy,
    output reg output_we,
    output reg mac_clear,
    output reg mac_en,
    output [5:0]  input_addr,
    output [11:0] weight_addr,
    output [5:0]  output_addr,
    output [31:0] output_din
);

reg [5:0] row;   reg [5:0] col;   
reg [3:0] state, nextstate;

//states
parameter IDLE         = 4'b0000;
parameter CLEAR_ACC    = 4'b0001;
parameter SET_ADDR     = 4'b0010;
parameter MAC          = 4'b0011;
parameter NEXT_COL     = 4'b0100;
parameter WAIT_ACC     = 4'b0101;
parameter WRITE_OUTPUT = 4'b0110;
parameter NEXT_ROW     = 4'b0111;
parameter S_DONE       = 4'b1000;

assign input_addr  = col;
assign weight_addr = {row, col};
assign output_addr = row;
assign output_din  = mac_acc_out;

assign busy = (state != IDLE) && (state != S_DONE);

//Sequential block for state updates
always @(posedge clk or negedge rst_n) begin
    if(!rst_n) begin
        state <= IDLE;
        row <= 0;
        col <= 0;
    end else begin
        state <= nextstate;
       
        //update row and col values based on state
         case (state)
            IDLE: begin
                row <= 0;
                col <= 0;
            end

            NEXT_COL: begin
                if (col < 6'd63)
                    col <= col + 1;
            end

            NEXT_ROW: begin
                if (row < 6'd63) begin
                    row <= row + 1;
                    col <= 0;
                end
            end
        endcase
        
    end //if-else
end //always@
 
//Combinational block for state transitions
always @(*) begin
  // default assignments
  nextstate = state; mac_en = 0; mac_clear = 0;
  output_we = 0; done = 0;
  
    case(state)
    
        IDLE: begin //if start go to CLEAR_ACC else stay
            if(start)
                nextstate = CLEAR_ACC;
            else
                nextstate = IDLE;          
        end
        
        CLEAR_ACC: begin //mac_clear = 1 next SET_ADDR
            mac_clear = 1'b1;
            nextstate = SET_ADDR;
        end
        
        SET_ADDR: begin
            //1 clk cycle buffer
            nextstate = MAC;
        end
        
        MAC: begin
            mac_en = 1;
            nextstate = NEXT_COL;
        end
        
        NEXT_COL: begin
            if(col == 6'd63)
                nextstate = WAIT_ACC;
            else
                nextstate = SET_ADDR;
        end
        
        WAIT_ACC: begin
            //wait 1 cycle for accumulator to settle
            nextstate = WRITE_OUTPUT;
        end
        
        WRITE_OUTPUT: begin
            output_we = 1;
            nextstate = NEXT_ROW;
        end
        
        NEXT_ROW: begin
            if(row == 6'd63)
                nextstate = S_DONE;
            else
                nextstate = CLEAR_ACC;
        end
                
        S_DONE: begin
            done = 1;
            if(start)
                nextstate = S_DONE;                               
            else
                nextstate = IDLE;
        end
        
        default: nextstate = IDLE;
        
    endcase
end

endmodule
