`timescale 1ns/1ps

module tb_picorv32_fetch;

    reg clk = 0;
    reg resetn = 0;

    // PicoRV32 memory interface
    wire        mem_valid;
    wire        mem_instr;
    wire [31:0] mem_addr;
    wire [31:0] mem_wdata;
    wire [3:0]  mem_wstrb;
    reg         mem_ready;
    reg  [31:0] mem_rdata;

    // Clock generation (10 ns period)
    always #5 clk = ~clk;

    // Instantiate PicoRV32
    picorv32 dut (
        .clk        (clk),
        .resetn     (resetn),
        .mem_valid  (mem_valid),
        .mem_instr  (mem_instr),
        .mem_addr   (mem_addr),
        .mem_wdata  (mem_wdata),
        .mem_wstrb  (mem_wstrb),
        .mem_ready  (mem_ready),
        .mem_rdata  (mem_rdata)
    );


    always @(posedge clk) begin
        if (resetn && mem_valid && mem_instr && mem_ready) begin
            $display(
                "[FETCH] time=%0t | PC=0x%08x | instr=0x%08x",
                $time,
                mem_addr,
                mem_rdata
            );
        end
    end


    // Simple instruction memory (always returns NOP)
    always @(*) begin
        mem_ready = 0;
        mem_rdata = 32'h00000013; // ADDI x0, x0, 0 (NOP)

        if (mem_valid)
            mem_ready = 1;
    end

    // Test sequence
    initial begin
        // FETCH-only VCD
        $dumpfile("tb_picorv32_fetch.vcd");

        // Top-level
        $dumpvars(0, tb_picorv32_fetch.clk);
        $dumpvars(0, tb_picorv32_fetch.resetn);

        // Memory interface (instruction fetch)
        $dumpvars(0, tb_picorv32_fetch.mem_valid);
        $dumpvars(0, tb_picorv32_fetch.mem_instr);
        $dumpvars(0, tb_picorv32_fetch.mem_addr);
        $dumpvars(0, tb_picorv32_fetch.mem_ready);
        $dumpvars(0, tb_picorv32_fetch.mem_rdata);

        // Internal FETCH-related signals
        $dumpvars(0, tb_picorv32_fetch.dut.cpu_state);
        $dumpvars(0, tb_picorv32_fetch.dut.reg_pc);
        $dumpvars(0, tb_picorv32_fetch.dut.reg_next_pc);
        $dumpvars(0, tb_picorv32_fetch.dut.mem_do_rinst);
        $dumpvars(0, tb_picorv32_fetch.dut.mem_do_prefetch);

        // Reset sequence
        resetn = 0;
        #20;
        resetn = 1;

        // Run for a few fetch cycles
        #500;

        $finish;
    end

endmodule
