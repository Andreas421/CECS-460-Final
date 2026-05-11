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
    
//internal registers    
reg awready_r, wready_r, bvalid_r, arready_r, rvalid_r;
reg [1:0] rresp_r, bresp_r;
reg [31:0] rdata_r; //might need to change due to data size

//Reassign outputs - check if necessary
assign S_AXI_AWREADY = awready_r;
assign S_AXI_WREADY  = wready_r;
assign S_AXI_BVALID  = bvalid_r;
assign S_AXI_BRESP   = bresp_r;
assign S_AXI_ARREADY = arready_r;
assign S_AXI_RVALID  = rvalid_r;
assign S_AXI_RRESP   = rresp_r;
assign S_AXI_RDATA   = rdata_r;
    
//Write regs 
reg [31:0] awaddr_reg;      
reg [31:0] wdata_reg;       
reg [3:0]  wstrb_reg;       
reg        aw_hold;        
reg        w_hold;        
reg        write_pending;  
    
//Read regs
reg [31:0] araddr_reg;      
reg        read_pending;    
reg        read_wait;       
    
//BRAM connections - NEEDS MODIFICATION
//replicate for each of the 3 bram modules    
parameter ADDR_WIDTH = 8; 
reg  [ADDR_WIDTH-1:0] bram_addr_rd;
wire [ADDR_WIDTH-1:0] bram_addr;
wire [7:0]            bram_din, bram_dout;
// Drive BRAM din from CAPTURED write data 
assign bram_din = wdata_reg[7:0];
// BRAM write enable must be visible BEFORE posedge
wire bram_we;
assign bram_we = write_pending & wstrb_reg[0];

// mux: during a pending write, use captured write address
assign bram_addr = write_pending ? awaddr_reg[ADDR_WIDTH-1:0] : bram_addr_rd;

input_bram uut1(.clk(S_AXI_ACLK), .we(input_we), .addr(input_addr),
                .din(input_din), .dout(input_dout));

// Write handler
always @ (posedge S_AXI_ACLK) begin
  if(!S_AXI_ARESETN) begin
    // Clear regs and flags
    awready_r     <= 1'b0;
    wready_r      <= 1'b0;
    bvalid_r      <= 1'b0; 
    bresp_r       <= 2'b00;

    awaddr_reg    <= 32'b0;
    wdata_reg     <= 32'b0;
    wstrb_reg     <= 4'b0;

    aw_hold       <= 1'b0;
    w_hold        <= 1'b0;
    write_pending <= 1'b0;
  end else begin
    // READY logic
    awready_r <= (~aw_hold) & (~bvalid_r) & (~write_pending);
    wready_r  <= (~w_hold)  & (~bvalid_r) & (~write_pending);

    // Capture write address
    if (S_AXI_AWVALID && awready_r) begin
      awaddr_reg <= S_AXI_AWADDR;
      aw_hold    <= 1'b1;
    end
    
    // Capture write data + strobe
    if (S_AXI_WVALID && wready_r) begin
      wdata_reg <= S_AXI_WDATA;
      wstrb_reg <= S_AXI_WSTRB;
      w_hold    <= 1'b1;
    end

    // When both captured, arm the BRAM write for the NEXT cycle
    if (aw_hold && w_hold && ~bvalid_r && ~write_pending) begin
      write_pending <= 1'b1;
    end

    // BRAM write edge occurs 
    // issue write response and clear flags.
    if (write_pending) begin
      bresp_r       <= 2'b00;  // OKAY
      bvalid_r      <= 1'b1;

      write_pending <= 1'b0;
      aw_hold       <= 1'b0;
      w_hold        <= 1'b0;
    end

    // Complete write response handshake
    if (bvalid_r && S_AXI_BREADY) begin
      bvalid_r <= 1'b0;
    end
  end
end


//Read handler
always @ (posedge S_AXI_ACLK) begin
  if(!S_AXI_ARESETN) begin
    arready_r    <= 1'b0;
    rvalid_r     <= 1'b0;
    rresp_r      <= 2'b00; 
    rdata_r      <= 32'b0;
    araddr_reg   <= 32'b0;

    read_pending <= 1'b0;
    read_wait    <= 1'b0;
    bram_addr_rd <= {ADDR_WIDTH{1'b0}};
  end else begin
    // ARREADY when not holding a response
    arready_r <= (~rvalid_r) & (~read_pending) & (~read_wait);

    // Accept read address 
    if (S_AXI_ARVALID && arready_r) begin
      araddr_reg    <= S_AXI_ARADDR;
      bram_addr_rd  <= S_AXI_ARADDR[ADDR_WIDTH-1:0];
      read_pending  <= 1'b1;
    end

    //wait one cycle so BRAM updates dout on next posedge
    if (read_pending) begin
      read_pending <= 1'b0;
      read_wait    <= 1'b1;
    end

    //now bram_dout is valid for the requested address
    if (read_wait) begin
      rdata_r   <= {24'b0, bram_dout};
      rresp_r   <= 2'b00; // OKAY
      rvalid_r  <= 1'b1;
      read_wait <= 1'b0;
    end

    // Complete read response handshake
    if (rvalid_r && S_AXI_RREADY) begin
      rvalid_r <= 1'b0;
    end
  end
end

    
    
    
endmodule
