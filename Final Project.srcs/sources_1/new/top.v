`timescale 1ns / 1ps

// Top-level wrapper for the NPU accelerator.
//
// Address map handled inside axi_slave:
//   0x0000        control/status
//   0x1000-0x103F input BRAM writes, 64 x 8-bit
//   0x2000-0x2FFF weight BRAM writes, 4096 x 8-bit
//   0x3000-0x30FF output BRAM reads, 64 x 32-bit

module top(
    // AXI4-Lite write address channel
    input  wire [31:0] S_AXI_AWADDR,
    input  wire        S_AXI_AWVALID,
    output wire        S_AXI_AWREADY,

    // AXI4-Lite write data channel
    input  wire [31:0] S_AXI_WDATA,
    input  wire [3:0]  S_AXI_WSTRB,
    input  wire        S_AXI_WVALID,
    output wire        S_AXI_WREADY,

    // AXI4-Lite write response channel
    input  wire        S_AXI_BREADY,
    output wire [1:0]  S_AXI_BRESP,
    output wire        S_AXI_BVALID,

    // AXI4-Lite read address channel
    input  wire [31:0] S_AXI_ARADDR,
    input  wire        S_AXI_ARVALID,
    output wire        S_AXI_ARREADY,

    // AXI4-Lite read data channel
    input  wire        S_AXI_RREADY,
    output wire [31:0] S_AXI_RDATA,
    output wire [1:0]  S_AXI_RRESP,
    output wire        S_AXI_RVALID,

    // Clock/reset
    input  wire        S_AXI_ACLK,
    input  wire        S_AXI_ARESETN
);

    // ------------------------------------------------------------
    // AXI slave <-> control/status wires
    // ------------------------------------------------------------
    wire start;
    wire done;

    // ------------------------------------------------------------
    // AXI slave <-> BRAM side wires
    // These are used while the CPU/PS is loading or reading memory.
    // ------------------------------------------------------------
    wire        input_we_axi;
    wire [5:0]  input_addr_axi;
    wire [7:0]  input_din_axi;

    wire        weight_we_axi;
    wire [11:0] weight_addr_axi;
    wire [7:0]  weight_din_axi;

    wire [5:0]  output_addr_axi;
    wire [31:0] output_dout;

    // ------------------------------------------------------------
    // FSM <-> BRAM/MAC wires
    // These are used while the accelerator is computing.
    // ------------------------------------------------------------
    wire        fsm_busy;
    wire        compute_mode;

    wire [5:0]  input_addr_fsm;
    wire [7:0]  input_dout;

    wire [11:0] weight_addr_fsm;
    wire [7:0]  weight_dout;

    wire        output_we_fsm;
    wire [5:0]  output_addr_fsm;
    wire [31:0] output_din_fsm;

    wire        mac_clear;
    wire        mac_en;
    wire signed [31:0] mac_acc_out;

    // ------------------------------------------------------------
    // Shared BRAM address/write wires after muxing
    // ------------------------------------------------------------
    wire        input_we_bram;
    wire [5:0]  input_addr_bram;

    wire        weight_we_bram;
    wire [11:0] weight_addr_bram;

    wire        output_we_bram;
    wire [5:0]  output_addr_bram;

    // FSM controls BRAM addresses during computation.
    // AXI controls BRAM addresses while idle/done.
    assign compute_mode = fsm_busy;

    assign input_addr_bram  = compute_mode ? input_addr_fsm  : input_addr_axi;
    assign weight_addr_bram = compute_mode ? weight_addr_fsm : weight_addr_axi;
    assign output_addr_bram = compute_mode ? output_addr_fsm : output_addr_axi;

    // Prevent accidental CPU writes from corrupting input/weight BRAMs
    // while the FSM is using the shared address ports.
    assign input_we_bram  = (!compute_mode) && input_we_axi;
    assign weight_we_bram = (!compute_mode) && weight_we_axi;

    // Only the FSM writes output BRAM.
    assign output_we_bram = output_we_fsm;

    // ------------------------------------------------------------
    // AXI slave
    // ------------------------------------------------------------
    axi_slave u_axi_slave (
        .S_AXI_AWADDR   (S_AXI_AWADDR),
        .S_AXI_AWVALID  (S_AXI_AWVALID),
        .S_AXI_AWREADY  (S_AXI_AWREADY),

        .S_AXI_WDATA    (S_AXI_WDATA),
        .S_AXI_WSTRB    (S_AXI_WSTRB),
        .S_AXI_WVALID   (S_AXI_WVALID),
        .S_AXI_WREADY   (S_AXI_WREADY),

        .S_AXI_BREADY   (S_AXI_BREADY),
        .S_AXI_BRESP    (S_AXI_BRESP),
        .S_AXI_BVALID   (S_AXI_BVALID),

        .S_AXI_ARADDR   (S_AXI_ARADDR),
        .S_AXI_ARVALID  (S_AXI_ARVALID),
        .S_AXI_ARREADY  (S_AXI_ARREADY),

        .S_AXI_RREADY   (S_AXI_RREADY),
        .S_AXI_RDATA    (S_AXI_RDATA),
        .S_AXI_RRESP    (S_AXI_RRESP),
        .S_AXI_RVALID   (S_AXI_RVALID),

        .start          (start),
        .done           (done),

        .input_we       (input_we_axi),
        .input_addr     (input_addr_axi),
        .input_din      (input_din_axi),

        .weight_we      (weight_we_axi),
        .weight_addr    (weight_addr_axi),
        .weight_din     (weight_din_axi),

        .output_addr    (output_addr_axi),
        .output_dout    (output_dout),

        .S_AXI_ACLK     (S_AXI_ACLK),
        .S_AXI_ARESETN  (S_AXI_ARESETN)
    );

    // ------------------------------------------------------------
    // FSM controller
    // ------------------------------------------------------------
    fsm_ctrl u_fsm_ctrl (
        .clk            (S_AXI_ACLK),
        .rst_n          (S_AXI_ARESETN),
        .start          (start),

        .input_dout     (input_dout),
        .weight_dout    (weight_dout),
        .mac_acc_out    (mac_acc_out),

        .done           (done),
        .busy           (fsm_busy),

        .output_we      (output_we_fsm),
        .mac_clear      (mac_clear),
        .mac_en         (mac_en),

        .input_addr     (input_addr_fsm),
        .weight_addr    (weight_addr_fsm),
        .output_addr    (output_addr_fsm),
        .output_din     (output_din_fsm)
    );

    // ------------------------------------------------------------
    // MAC datapath
    // ------------------------------------------------------------
    mac_array u_mac_array (
        .clk            (S_AXI_ACLK),
        .rst_n          (S_AXI_ARESETN),
        .clear_acc      (mac_clear),
        .en             (mac_en),
        .input_data     (input_dout),
        .weight_data    (weight_dout),
        .acc_out        (mac_acc_out)
    );

    // ------------------------------------------------------------
    // Input BRAM: CPU writes, FSM reads
    // ------------------------------------------------------------
    input_bram u_input_bram (
        .clk            (S_AXI_ACLK),
        .we             (input_we_bram),
        .addr           (input_addr_bram),
        .din            (input_din_axi),
        .dout           (input_dout)
    );

    // ------------------------------------------------------------
    // Weight BRAM: CPU writes, FSM reads
    // ------------------------------------------------------------
    weight_bram u_weight_bram (
        .clk            (S_AXI_ACLK),
        .we             (weight_we_bram),
        .addr           (weight_addr_bram),
        .din            (weight_din_axi),
        .dout           (weight_dout)
    );

    // ------------------------------------------------------------
    // Output BRAM: FSM writes, CPU reads
    // ------------------------------------------------------------
    output_bram u_output_bram (
        .clk            (S_AXI_ACLK),
        .we             (output_we_bram),
        .addr           (output_addr_bram),
        .din            (output_din_fsm),
        .dout           (output_dout)
    );

endmodule
