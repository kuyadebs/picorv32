`timescale 1ns / 1ps

module tb_simple;
    reg clk;
    reg resetn;
    
    // Minimal connections
    wire trap;
    wire mem_valid;
    wire mem_instr;
    reg mem_ready;
    wire [31:0] mem_addr;
    wire [31:0] mem_wdata;
    wire [3:0] mem_wstrb;
    reg [31:0] mem_rdata;
    
    // Test signals from MODIFIED PicoRV32
    wire test_mem_la_firstword_reg;
    wire test_last_mem_valid;
    wire test_mem_la_firstword;
    
    // Clock
    always #5 clk = ~clk;
    
    // Instantiate MODIFIED PicoRV32
    picorv32 cpu (
        .clk(clk),
        .resetn(resetn),
        .trap(trap),
        
        // Memory interface
        .mem_valid(mem_valid),
        .mem_instr(mem_instr),
        .mem_ready(mem_ready),
        .mem_addr(mem_addr),
        .mem_wdata(mem_wdata),
        .mem_wstrb(mem_wstrb),
        .mem_rdata(mem_rdata),
        
        // Test signals
        .test_mem_la_firstword_reg(test_mem_la_firstword_reg),
        .test_last_mem_valid(test_last_mem_valid),
        .test_mem_la_firstword(test_mem_la_firstword),
        
        // Tie off others
        .mem_la_read(),
        .mem_la_write(),
        .mem_la_addr(),
        .mem_la_wdata(),
        .mem_la_wstrb(),
        .pcpi_valid(),
        .pcpi_insn(),
        .pcpi_rs1(),
        .pcpi_rs2(),
        .pcpi_wr(0),
        .pcpi_rd(0),
        .pcpi_wait(0),
        .pcpi_ready(0),
        .irq(0),
        .eoi(),
        .trace_valid(),
        .trace_data()
    );
    
    initial begin
        // Create VCD
        $dumpfile("tb_simple.vcd");
        $dumpvars(0, tb_simple);
        
        // Initialize
        clk = 0;
        resetn = 0;
        mem_ready = 0;
        mem_rdata = 32'h00000013; // NOP instruction
        
        // Reset
        #20; resetn = 1;
        
        // Create memory delays to trigger the logic
        #10; mem_ready = 0; // Not ready
        #10; mem_ready = 0; // Still not ready
        #10; mem_ready = 1; // Ready
        #10; mem_ready = 0; // Not ready again
        #10; mem_ready = 1; // Ready
        
        #50;
        $display("Test complete - check modified_test.vcd");
        $finish;
    end
    
    // Monitor
    always @(posedge clk) begin
        $display("[%0t] last_mem_valid=%b, mem_la_firstword_reg=%b", 
                 $time, test_last_mem_valid, test_mem_la_firstword_reg);
    end
endmodule