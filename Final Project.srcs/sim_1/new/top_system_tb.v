`timescale 1ns / 1ps

// Full-system behavioral testbench for the NPU top module.
//
// This testbench acts like the PS/ARM CPU:
//   1. Writes 64 input bytes through AXI-Lite
//   2. Writes 4096 weight bytes through AXI-Lite
//   3. Writes START through AXI-Lite
//   4. Waits for the FSM done signal
//   5. Reads 64 output words through AXI-Lite
//   6. Compares hardware results against a software golden model
//
// Address map expected by axi_slave:
//   0x0000        control/status register
//   0x1000+i      input_bram[i], 8-bit
//   0x2000+i      weight_bram[i], 8-bit, where i = row*64 + col
//   0x3000+i*4    output_bram[i], 32-bit

module tb_top_system;

    // ------------------------------------------------------------
    // Clock/reset
    // ------------------------------------------------------------
    reg clk;
    reg rst_n;

    initial begin
        clk = 1'b0;
        forever #5 clk = ~clk; // 100 MHz
    end

    // ------------------------------------------------------------
    // AXI4-Lite signals
    // ------------------------------------------------------------
    reg  [31:0] S_AXI_AWADDR;
    reg         S_AXI_AWVALID;
    wire        S_AXI_AWREADY;

    reg  [31:0] S_AXI_WDATA;
    reg  [3:0]  S_AXI_WSTRB;
    reg         S_AXI_WVALID;
    wire        S_AXI_WREADY;

    reg         S_AXI_BREADY;
    wire [1:0]  S_AXI_BRESP;
    wire        S_AXI_BVALID;

    reg  [31:0] S_AXI_ARADDR;
    reg         S_AXI_ARVALID;
    wire        S_AXI_ARREADY;

    reg         S_AXI_RREADY;
    wire [31:0] S_AXI_RDATA;
    wire [1:0]  S_AXI_RRESP;
    wire        S_AXI_RVALID;

    // ------------------------------------------------------------
    // DUT
    // ------------------------------------------------------------
    top dut (
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

        .S_AXI_ACLK     (clk),
        .S_AXI_ARESETN  (rst_n)
    );

    // ------------------------------------------------------------
    // Test vectors and golden results
    // ------------------------------------------------------------
    reg signed [7:0]  input_vec  [0:63];
    reg signed [7:0]  weight_mem [0:4095];
    reg signed [31:0] expected   [0:63];

    integer r;
    integer c;
    integer idx;
    integer errors;
    integer timeout_count;
    reg [31:0] read_data;

    // ------------------------------------------------------------
    // AXI helper tasks
    // ------------------------------------------------------------
    task axi_write;
        input [31:0] addr;
        input [31:0] data;
        begin
            @(posedge clk);
            S_AXI_AWADDR  <= addr;
            S_AXI_AWVALID <= 1'b1;
            S_AXI_WDATA   <= data;
            S_AXI_WSTRB   <= 4'b1111;
            S_AXI_WVALID  <= 1'b1;
            S_AXI_BREADY  <= 1'b1;

            // Wait until both address and data are accepted.
            while (!(S_AXI_AWREADY && S_AXI_WREADY)) begin
                @(posedge clk);
            end

            @(posedge clk);
            S_AXI_AWVALID <= 1'b0;
            S_AXI_WVALID  <= 1'b0;

            // Wait for write response.
            while (!S_AXI_BVALID) begin
                @(posedge clk);
            end

            if (S_AXI_BRESP !== 2'b00) begin
                $display("AXI WRITE ERROR: addr=0x%08h data=0x%08h BRESP=%b", addr, data, S_AXI_BRESP);
                errors = errors + 1;
            end

            @(posedge clk);
            S_AXI_BREADY <= 1'b0;
        end
    endtask

    task axi_read;
        input  [31:0] addr;
        output [31:0] data;
        begin
            @(posedge clk);
            S_AXI_ARADDR  <= addr;
            S_AXI_ARVALID <= 1'b1;
            S_AXI_RREADY  <= 1'b1;

            while (!S_AXI_ARREADY) begin
                @(posedge clk);
            end

            @(posedge clk);
            S_AXI_ARVALID <= 1'b0;

            while (!S_AXI_RVALID) begin
                @(posedge clk);
            end

            data = S_AXI_RDATA;

            if (S_AXI_RRESP !== 2'b00) begin
                $display("AXI READ ERROR: addr=0x%08h RRESP=%b", addr, S_AXI_RRESP);
                errors = errors + 1;
            end

            @(posedge clk);
            S_AXI_RREADY <= 1'b0;
        end
    endtask

    // ------------------------------------------------------------
    // Main test
    // ------------------------------------------------------------
    initial begin
        // Optional waveform dump for simulators that support VCD.
        $dumpfile("tb_top_system.vcd");
        $dumpvars(0, tb_top_system);

        // Initial AXI values
        rst_n         = 1'b0;
        S_AXI_AWADDR  = 32'd0;
        S_AXI_AWVALID = 1'b0;
        S_AXI_WDATA   = 32'd0;
        S_AXI_WSTRB   = 4'd0;
        S_AXI_WVALID  = 1'b0;
        S_AXI_BREADY  = 1'b0;
        S_AXI_ARADDR  = 32'd0;
        S_AXI_ARVALID = 1'b0;
        S_AXI_RREADY  = 1'b0;
        errors        = 0;

        // Build deterministic signed INT8 input/weight data.
        // Values are intentionally small to make debugging easier.
        for (c = 0; c < 64; c = c + 1) begin
            input_vec[c] = (c % 8) - 4; // -4, -3, -2, -1, 0, 1, 2, 3, repeat
        end

        for (r = 0; r < 64; r = r + 1) begin
            expected[r] = 32'sd0;
            for (c = 0; c < 64; c = c + 1) begin
                idx = (r * 64) + c;
                weight_mem[idx] = ((r + c) % 5) - 2; // -2 to +2 pattern
                expected[r] = expected[r] + (weight_mem[idx] * input_vec[c]);
            end
        end

        // Reset DUT
        repeat (10) @(posedge clk);
        rst_n = 1'b1;
        repeat (5) @(posedge clk);

        $display("------------------------------------------------------------");
        $display("Loading input vector through AXI...");
        $display("------------------------------------------------------------");
        for (c = 0; c < 64; c = c + 1) begin
            axi_write(32'h0000_1000 + c, {24'd0, input_vec[c]});
        end

        $display("------------------------------------------------------------");
        $display("Loading weight matrix through AXI...");
        $display("------------------------------------------------------------");
        for (idx = 0; idx < 4096; idx = idx + 1) begin
            axi_write(32'h0000_2000 + idx, {24'd0, weight_mem[idx]});
        end

        $display("------------------------------------------------------------");
        $display("Starting accelerator...");
        $display("------------------------------------------------------------");
        axi_write(32'h0000_0000, 32'h0000_0001);

        // NOTE:
        // Your current fsm_ctrl makes done a one-clock pulse in S_DONE.
        // A real CPU polling over AXI may miss that pulse. For this simulation,
        // we wait on the internal top-level done wire directly so the testbench
        // can continue to read and verify the output BRAM.
        timeout_count = 0;
        while (dut.done !== 1'b1 && timeout_count < 20000) begin
            @(posedge clk);
            timeout_count = timeout_count + 1;
        end

        if (timeout_count >= 20000) begin
            $display("FAIL: Timed out waiting for dut.done.");
            $finish;
        end else begin
            $display("PASS: Accelerator done observed after %0d cycles.", timeout_count);
        end

        // Wait a few clocks so top.v muxes return to AXI/read mode.
        repeat (5) @(posedge clk);

        $display("------------------------------------------------------------");
        $display("Reading output vector through AXI and comparing...");
        $display("------------------------------------------------------------");
        for (r = 0; r < 64; r = r + 1) begin
            axi_read(32'h0000_3000 + (r * 4), read_data);

            if ($signed(read_data) !== expected[r]) begin
                $display("FAIL row %0d: got %0d / 0x%08h, expected %0d / 0x%08h",
                         r, $signed(read_data), read_data, expected[r], expected[r]);
                errors = errors + 1;
            end else begin
                $display("PASS row %0d: result = %0d", r, $signed(read_data));
            end
        end

        $display("------------------------------------------------------------");
        if (errors == 0) begin
            $display("SYSTEM TEST PASSED: all 64 outputs matched.");
        end else begin
            $display("SYSTEM TEST FAILED: %0d error(s).", errors);
        end
        $display("------------------------------------------------------------");

        #100;
        $finish;
    end

endmodule
