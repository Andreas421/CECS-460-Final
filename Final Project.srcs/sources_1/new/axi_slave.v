`timescale 1ns / 1ps

module axi_slave(
    // WRITE ADDRESS CHANNEL
    input  [31:0] S_AXI_AWADDR,
    input         S_AXI_AWVALID,
    output        S_AXI_AWREADY,

    // WRITE DATA CHANNEL
    input  [31:0] S_AXI_WDATA,
    input  [3:0]  S_AXI_WSTRB,
    input         S_AXI_WVALID,
    output        S_AXI_WREADY,

    // WRITE RESPONSE CHANNEL
    input         S_AXI_BREADY,
    output [1:0]  S_AXI_BRESP,
    output        S_AXI_BVALID,

    // READ ADDRESS CHANNEL
    input  [31:0] S_AXI_ARADDR,
    input         S_AXI_ARVALID,
    output        S_AXI_ARREADY,

    // READ DATA CHANNEL
    input         S_AXI_RREADY,
    output [31:0] S_AXI_RDATA,
    output [1:0]  S_AXI_RRESP,
    output        S_AXI_RVALID,

    // Accelerator control/status
    output        start,
    input         done,

    // input_bram write side from AXI
    output        input_we,
    output [5:0]  input_addr,
    output [7:0]  input_din,

    // weight_bram write side from AXI
    output        weight_we,
    output [11:0] weight_addr,
    output [7:0]  weight_din,

    // output_bram read side to AXI
    output [5:0]  output_addr,
    input  [31:0] output_dout,

    // Clock/reset
    input         S_AXI_ACLK,
    input         S_AXI_ARESETN
);

// Memory map
// 0x0000        control/status register
//               write bit 0 = start pulse
//               read  bit 0 = current start pulse/debug
//               read  bit 1 = done
//
// 0x1000-0x103F input BRAM,  64 x 8-bit
//               write S_AXI_WDATA[7:0]
//
// 0x2000-0x2FFF weight BRAM, 4096 x 8-bit
//               write S_AXI_WDATA[7:0]
//
// 0x3000-0x30FF output BRAM, 64 x 32-bit
//               read one 32-bit output word per address offset of 4 bytes

// AXI output registers
reg        awready_r;
reg        wready_r;
reg        bvalid_r;
reg        arready_r;
reg        rvalid_r;
reg [1:0]  bresp_r;
reg [1:0]  rresp_r;
reg [31:0] rdata_r;

assign S_AXI_AWREADY = awready_r;
assign S_AXI_WREADY  = wready_r;
assign S_AXI_BVALID  = bvalid_r;
assign S_AXI_BRESP   = bresp_r;
assign S_AXI_ARREADY = arready_r;
assign S_AXI_RVALID  = rvalid_r;
assign S_AXI_RRESP   = rresp_r;
assign S_AXI_RDATA   = rdata_r;

// Captured write transaction
reg [31:0] awaddr_reg;
reg [31:0] wdata_reg;
reg [3:0]  wstrb_reg;
reg        aw_hold;
reg        w_hold;
reg        write_pending;

// Captured read transaction
reg [31:0] araddr_reg;
reg        read_pending;
reg        read_wait;

// Decode captured write address
wire write_ctrl   = (awaddr_reg[15:12] == 4'h0);
wire write_input  = (awaddr_reg[15:12] == 4'h1);
wire write_weight = (awaddr_reg[15:12] == 4'h2);

// Decode captured read address
wire read_ctrl    = (araddr_reg[15:12] == 4'h0);
wire read_output  = (araddr_reg[15:12] == 4'h3);


// Outputs to accelerator/BRAMs
assign start = write_pending && write_ctrl && wdata_reg[0] && wstrb_reg[0];

// Byte writes into input/weight BRAMs.
assign input_we    = write_pending && write_input  && wstrb_reg[0];
assign input_addr  = awaddr_reg[5:0];
assign input_din   = wdata_reg[7:0];

assign weight_we   = write_pending && write_weight && wstrb_reg[0];
assign weight_addr = awaddr_reg[11:0];
assign weight_din  = wdata_reg[7:0];

// Output BRAM is read as 32-bit words, so byte offsets 0,4,8,... select words.
assign output_addr = araddr_reg[7:2];

// Write channel handler
always @(posedge S_AXI_ACLK) begin
    if (!S_AXI_ARESETN) begin
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
        // Ready when we are not already holding a write transaction/response.
        awready_r <= (~aw_hold) & (~bvalid_r) & (~write_pending);
        wready_r  <= (~w_hold)  & (~bvalid_r) & (~write_pending);

        // Capture write address.
        if (S_AXI_AWVALID && awready_r) begin
            awaddr_reg <= S_AXI_AWADDR;
            aw_hold    <= 1'b1;
        end

        // Capture write data.
        if (S_AXI_WVALID && wready_r) begin
            wdata_reg <= S_AXI_WDATA;
            wstrb_reg <= S_AXI_WSTRB;
            w_hold    <= 1'b1;
        end

        // Once both address and data have arrived, create a one-cycle pending
        // phase. The combinational assigns above use write_pending to drive
        // input_we, weight_we, and start before the next clock edge.
        if (aw_hold && w_hold && ~bvalid_r && ~write_pending) begin
            write_pending <= 1'b1;
        end

        // Complete the internal write/start pulse and return OKAY.
        if (write_pending) begin
            bresp_r       <= 2'b00; // OKAY
            bvalid_r      <= 1'b1;
            write_pending <= 1'b0;
            aw_hold       <= 1'b0;
            w_hold        <= 1'b0;
        end

        // Complete AXI write response handshake.
        if (bvalid_r && S_AXI_BREADY) begin
            bvalid_r <= 1'b0;
        end
    end
end

// Read channel handler
always @(posedge S_AXI_ACLK) begin
    if (!S_AXI_ARESETN) begin
        arready_r    <= 1'b0;
        rvalid_r     <= 1'b0;
        rresp_r      <= 2'b00;
        rdata_r      <= 32'b0;
        araddr_reg   <= 32'b0;
        read_pending <= 1'b0;
        read_wait    <= 1'b0;
    end else begin
        // Accept one read at a time.
        arready_r <= (~rvalid_r) & (~read_pending) & (~read_wait);

        // Capture read address.
        if (S_AXI_ARVALID && arready_r) begin
            araddr_reg   <= S_AXI_ARADDR;
            read_pending <= 1'b1;
        end

        // Wait one cycle so synchronous output_bram can see output_addr.
        if (read_pending) begin
            read_pending <= 1'b0;
            read_wait    <= 1'b1;
        end

        // Now output_dout is valid for output_addr.
        if (read_wait) begin
            if (read_ctrl) begin
                rdata_r <= {30'b0, done, start};
            end else if (read_output) begin
                rdata_r <= output_dout;
            end else begin
                rdata_r <= 32'h0000_0000;
            end

            rresp_r   <= 2'b00; // OKAY
            rvalid_r  <= 1'b1;
            read_wait <= 1'b0;
        end

        // Complete AXI read response handshake.
        if (rvalid_r && S_AXI_RREADY) begin
            rvalid_r <= 1'b0;
        end
    end
end

endmodule
