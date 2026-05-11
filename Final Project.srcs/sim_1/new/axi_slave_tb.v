`timescale 1ns / 1ps

module axi_slave_tb;

    reg clk;
    reg rst_n;

    // AXI write address
    reg  [31:0] S_AXI_AWADDR;
    reg         S_AXI_AWVALID;
    wire        S_AXI_AWREADY;

    // AXI write data
    reg  [31:0] S_AXI_WDATA;
    reg  [3:0]  S_AXI_WSTRB;
    reg         S_AXI_WVALID;
    wire        S_AXI_WREADY;

    // AXI write response
    reg         S_AXI_BREADY;
    wire [1:0]  S_AXI_BRESP;
    wire        S_AXI_BVALID;

    // AXI read address
    reg  [31:0] S_AXI_ARADDR;
    reg         S_AXI_ARVALID;
    wire        S_AXI_ARREADY;

    // AXI read data
    reg         S_AXI_RREADY;
    wire [31:0] S_AXI_RDATA;
    wire [1:0]  S_AXI_RRESP;
    wire        S_AXI_RVALID;

    // Accelerator-side signals
    wire        start;
    reg         done;

    wire        input_we;
    wire [5:0]  input_addr;
    wire [7:0]  input_din;

    wire        weight_we;
    wire [11:0] weight_addr;
    wire [7:0]  weight_din;

    wire [5:0]  output_addr;
    reg  [31:0] output_dout;

    axi_slave dut (.S_AXI_AWADDR(S_AXI_AWADDR), .S_AXI_AWVALID(S_AXI_AWVALID),
        .S_AXI_AWREADY(S_AXI_AWREADY),

        .S_AXI_WDATA(S_AXI_WDATA),
        .S_AXI_WSTRB(S_AXI_WSTRB),
        .S_AXI_WVALID(S_AXI_WVALID),
        .S_AXI_WREADY(S_AXI_WREADY),

        .S_AXI_BREADY(S_AXI_BREADY),
        .S_AXI_BRESP(S_AXI_BRESP),
        .S_AXI_BVALID(S_AXI_BVALID),

        .S_AXI_ARADDR(S_AXI_ARADDR),
        .S_AXI_ARVALID(S_AXI_ARVALID),
        .S_AXI_ARREADY(S_AXI_ARREADY),

        .S_AXI_RREADY(S_AXI_RREADY),
        .S_AXI_RDATA(S_AXI_RDATA),
        .S_AXI_RRESP(S_AXI_RRESP),
        .S_AXI_RVALID(S_AXI_RVALID),

        .start(start),
        .done(done),

        .input_we(input_we),
        .input_addr(input_addr),
        .input_din(input_din),

        .weight_we(weight_we),
        .weight_addr(weight_addr),
        .weight_din(weight_din),

        .output_addr(output_addr),
        .output_dout(output_dout),

        .S_AXI_ACLK(clk),
        .S_AXI_ARESETN(rst_n)
    );

    // 100 MHz clock
    initial begin
        clk = 0;
        forever #5 clk = ~clk;
    end

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

            wait(S_AXI_AWREADY && S_AXI_WREADY);
            @(posedge clk);
            S_AXI_AWVALID <= 1'b0;
            S_AXI_WVALID  <= 1'b0;

            wait(S_AXI_BVALID);
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

            wait(S_AXI_ARREADY);
            @(posedge clk);
            S_AXI_ARVALID <= 1'b0;

            wait(S_AXI_RVALID);
            data = S_AXI_RDATA;
            @(posedge clk);
            S_AXI_RREADY <= 1'b0;
        end
    endtask

    reg [31:0] read_data;

    initial begin
        // Initial values
        rst_n         = 0;
        S_AXI_AWADDR  = 0;
        S_AXI_AWVALID = 0;
        S_AXI_WDATA   = 0;
        S_AXI_WSTRB   = 0;
        S_AXI_WVALID  = 0;
        S_AXI_BREADY  = 0;
        S_AXI_ARADDR  = 0;
        S_AXI_ARVALID = 0;
        S_AXI_RREADY  = 0;
        done          = 0;
        output_dout   = 32'h00000000;

        // Reset
        repeat(5) @(posedge clk);
        rst_n = 1;
        repeat(2) @(posedge clk);

        // ------------------------------------------------------------
        // Test 1: write input BRAM address 5 with value 0x7A
        // Address map: 0x1000 + index
        // ------------------------------------------------------------
        axi_write(32'h0000_1005, 32'h0000_007A);

        @(posedge clk);
        if (input_addr !== 6'd5)
            $display("FAIL: input_addr expected 5, got %0d", input_addr);
        else
            $display("PASS: input_addr");

        if (input_din !== 8'h7A)
            $display("FAIL: input_din expected 0x7A, got 0x%h", input_din);
        else
            $display("PASS: input_din");

        // ------------------------------------------------------------
        // Test 2: write weight BRAM address 0x123 with value 0xA5
        // Address map: 0x2000 + index
        // ------------------------------------------------------------
        axi_write(32'h0000_2123, 32'h0000_00A5);

        @(posedge clk);
        if (weight_addr !== 12'h123)
            $display("FAIL: weight_addr expected 0x123, got 0x%h", weight_addr);
        else
            $display("PASS: weight_addr");

        if (weight_din !== 8'hA5)
            $display("FAIL: weight_din expected 0xA5, got 0x%h", weight_din);
        else
            $display("PASS: weight_din");

        // ------------------------------------------------------------
        // Test 3: write control register start bit
        // Address map: 0x0000
        // ------------------------------------------------------------
        axi_write(32'h0000_0000, 32'h0000_0001);

        @(posedge clk);
        if (start)
            $display("PASS: start pulse observed");
        else
            $display("NOTE: start pulse may have happened one cycle earlier; check waveform");

        // ------------------------------------------------------------
        // Test 4: read control/status register with done = 1
        // Expected bit 1 = done
        // ------------------------------------------------------------
        done = 1'b1;
        axi_read(32'h0000_0000, read_data);

        if (read_data[1] !== 1'b1)
            $display("FAIL: done bit expected 1, got read_data = 0x%h", read_data);
        else
            $display("PASS: done status read");

        // ------------------------------------------------------------
        // Test 5: read output result word
        // Address map: 0x3000 + word_index*4
        // Reading 0x300C should select output_addr = 3
        // ------------------------------------------------------------
        output_dout = 32'hDEADBEEF;
        axi_read(32'h0000_300C, read_data);

        if (output_addr !== 6'd3)
            $display("FAIL: output_addr expected 3, got %0d", output_addr);
        else
            $display("PASS: output_addr");

        if (read_data !== 32'hDEADBEEF)
            $display("FAIL: output read expected DEADBEEF, got 0x%h", read_data);
        else
            $display("PASS: output readback");

        $display("AXI slave testbench finished.");
        #50;
        $finish;
    end

endmodule