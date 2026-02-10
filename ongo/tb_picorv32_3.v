`timescale 1ns / 1ps

module tb_picorv32_3;

    // Clock and Reset
    reg clk;
    reg resetn;
    
    // Memory Interface
    wire        mem_valid;
    wire        mem_instr;
    reg         mem_ready;
    wire [31:0] mem_addr;
    wire [31:0] mem_wdata;
    wire [ 3:0] mem_wstrb;
    reg  [31:0] mem_rdata;
    
    // Trap signal
    wire trap;
    
    // Simple memory array
    reg [31:0] memory [0:4095]; // 16KB memory
    
    // Result memory for tests (separate from instruction memory)
    reg [31:0] result_mem [0:15];
    
    // Test status
    integer test_passed = 0;
    integer test_failed = 0;
    integer cycle_count = 0;
    
    // DUT instantiation
    picorv32 #(
        .ENABLE_COUNTERS(1),
        .ENABLE_COUNTERS64(0),
        .ENABLE_REGS_16_31(1),
        .ENABLE_REGS_DUALPORT(1),
        .LATCHED_MEM_RDATA(0),
        .TWO_STAGE_SHIFT(1),
        .BARREL_SHIFTER(0),
        .TWO_CYCLE_COMPARE(0),
        .TWO_CYCLE_ALU(0),
        .COMPRESSED_ISA(0),
        .CATCH_MISALIGN(1),
        .CATCH_ILLINSN(1),
        .ENABLE_PCPI(0),
        .ENABLE_MUL(0),
        .ENABLE_FAST_MUL(0),
        .ENABLE_DIV(0),
        .ENABLE_IRQ(0),
        .PROGADDR_RESET(32'h0000_0000)
    ) dut (
        .clk(clk),
        .resetn(resetn),
        .trap(trap),
        
        .mem_valid(mem_valid),
        .mem_instr(mem_instr),
        .mem_ready(mem_ready),
        .mem_addr(mem_addr),
        .mem_wdata(mem_wdata),
        .mem_wstrb(mem_wstrb),
        .mem_rdata(mem_rdata),
        
        .mem_la_read(),
        .mem_la_write(),
        .mem_la_addr(),
        .mem_la_wdata(),
        .mem_la_wstrb(),
        
        .pcpi_valid(),
        .pcpi_insn(),
        .pcpi_rs1(),
        .pcpi_rs2(),
        .pcpi_wr(1'b0),
        .pcpi_rd(32'h0),
        .pcpi_wait(1'b0),
        .pcpi_ready(1'b0),
        
        .irq(32'h0),
        .eoi(),
        
        .trace_valid(),
        .trace_data()
    );
    
    // Clock generation - 10ns period (100MHz)
    initial begin
        clk = 0;
        forever #5 clk = ~clk;
    end
    
    // Memory interface logic with result memory at 0x2000
    always @(posedge clk) begin
        mem_ready <= 0;
        
        if (mem_valid && !mem_ready) begin
            if (mem_addr >= 32'h2000 && mem_addr < 32'h2040) begin
                // Result memory area (0x2000-0x203F)
                if (|mem_wstrb) begin
                    if (mem_wstrb[0]) result_mem[mem_addr[5:2]][7:0]   <= mem_wdata[7:0];
                    if (mem_wstrb[1]) result_mem[mem_addr[5:2]][15:8]  <= mem_wdata[15:8];
                    if (mem_wstrb[2]) result_mem[mem_addr[5:2]][23:16] <= mem_wdata[23:16];
                    if (mem_wstrb[3]) result_mem[mem_addr[5:2]][31:24] <= mem_wdata[31:24];
                end
                mem_rdata <= result_mem[mem_addr[5:2]];
                mem_ready <= 1;
            end else if (mem_addr < 32'h4000) begin
                // Regular memory (0x0000-0x3FFF)
                if (|mem_wstrb) begin
                    if (mem_wstrb[0]) memory[mem_addr[13:2]][7:0]   <= mem_wdata[7:0];
                    if (mem_wstrb[1]) memory[mem_addr[13:2]][15:8]  <= mem_wdata[15:8];
                    if (mem_wstrb[2]) memory[mem_addr[13:2]][23:16] <= mem_wdata[23:16];
                    if (mem_wstrb[3]) memory[mem_addr[13:2]][31:24] <= mem_wdata[31:24];
                end
                mem_rdata <= memory[mem_addr[13:2]];
                mem_ready <= 1;
            end else begin
                mem_rdata <= 32'hDEADBEEF;
                mem_ready <= 1;
            end
        end
    end
    
    // Cycle counter
    always @(posedge clk) begin
        if (resetn) cycle_count <= cycle_count + 1;
        else cycle_count <= 0;
    end
    
    // Check result memory value
    task check_result;
        input [3:0] index;
        input [31:0] expected;
        input [8*64:1] test_name;
        begin
            if (result_mem[index] === expected) begin
                $display("[PASS] %s: result[%0d] = 0x%08h", test_name, index, result_mem[index]);
                test_passed = test_passed + 1;
            end else begin
                $display("[FAIL] %s: result[%0d] = 0x%08h, expected 0x%08h", 
                         test_name, index, result_mem[index], expected);
                test_failed = test_failed + 1;
            end
        end
    endtask
    
    // Main test sequence
    initial begin
        // VCD dump with comprehensive coverage
        $dumpfile("tb_picorv32_3.vcd");
        $dumpvars(0, tb_picorv32_3);
        
        // Dump DUT hierarchy
        $dumpvars(1, dut);
        $dumpvars(2, dut);
        
        // Explicitly dump important internal signals
        $dumpvars(0, dut.cpu_state);
        $dumpvars(0, dut.reg_pc);
        $dumpvars(0, dut.reg_next_pc);
        $dumpvars(0, dut.decoded_rd);
        $dumpvars(0, dut.decoded_rs1);
        $dumpvars(0, dut.decoded_rs2);
        $dumpvars(0, dut.reg_op1);
        $dumpvars(0, dut.reg_op2);
        $dumpvars(0, dut.reg_out);
        $dumpvars(0, dut.mem_state);
        $dumpvars(0, dut.alu_out);
        
        // Dump first 32 memory words and result memory
        for (integer i = 0; i < 32; i = i + 1) begin
            $dumpvars(0, memory[i]);
            if (i < 16) $dumpvars(0, result_mem[i]);
        end
        
        // Dump register file if using internal registers
        `ifndef PICORV32_REGS
        for (integer i = 0; i < 32; i = i + 1) begin
            $dumpvars(0, dut.cpuregs[i]);
        end
        `endif
        
        // Initialize
        resetn = 0;
        mem_ready = 0;
        mem_rdata = 0;
        
        // Clear memory
        for (integer i = 0; i < 4096; i = i + 1) begin
            memory[i] = 32'h0000_0013; // NOP (addi x0, x0, 0)
        end
        for (integer i = 0; i < 16; i = i + 1) begin
            result_mem[i] = 32'h0;
        end
        
        $display("\n=== PicoRV32 Testbench ===\n");
        
        // Release reset
        repeat(5) @(posedge clk);
        resetn = 1;
        $display("[%0t] Reset released", $time);
        
        // TEST 1: Simple arithmetic - ADD
        $display("\n--- Test 1: Basic ADD instruction ---");
        memory[0] = 32'h00100093; // addi x1, x0, 1      (x1 = 1)
        memory[1] = 32'h00200113; // addi x2, x0, 2      (x2 = 2)
        memory[2] = 32'h002081B3; // add  x3, x1, x2     (x3 = x1 + x2 = 3)
        memory[3] = 32'h00002237; // lui  x4, 0x2        (x4 = 0x2000)
        memory[4] = 32'h00322023; // sw   x3, 0(x4)      (result[0] = x3)
        memory[5] = 32'h00000013; // nop
        memory[6] = 32'h00000013; // nop
        
        repeat(80) @(posedge clk);
        check_result(0, 32'h0000_0003, "ADD result");
        
        // TEST 2: SUB instruction
        $display("\n--- Test 2: SUB instruction ---");
        resetn = 0;
        repeat(5) @(posedge clk);
        resetn = 1;
        
        memory[0] = 32'h00500093;  // addi x1, x0, 5      (x1 = 5)
        memory[1] = 32'h00300113;  // addi x2, x0, 3      (x2 = 3)
        memory[2] = 32'h402081B3;  // sub  x3, x1, x2     (x3 = 5 - 3 = 2)
        memory[3] = 32'h00002237;  // lui  x4, 0x2        (x4 = 0x2000)
        memory[4] = 32'h00322223;  // sw   x3, 4(x4)      (result[1] = x3)
        memory[5] = 32'h00000013;  // nop
        
        repeat(80) @(posedge clk);
        check_result(1, 32'h0000_0002, "SUB result");
        
        // TEST 3: Load/Store
        $display("\n--- Test 3: Load/Store operations ---");
        resetn = 0;
        repeat(5) @(posedge clk);
        resetn = 1;
        
        memory[100] = 32'hDEADBEEF;
        memory[0]  = 32'h19000093;  // addi x1, x0, 400   (x1 = 400)
        memory[1]  = 32'h0000A103;  // lw   x2, 0(x1)     (x2 = memory[100])
        memory[2]  = 32'h00110113;  // addi x2, x2, 1     (x2 = x2 + 1)
        memory[3]  = 32'h00002237;  // lui  x4, 0x2       (x4 = 0x2000)
        memory[4]  = 32'h00222423;  // sw   x2, 8(x4)     (result[2] = x2)
        memory[5]  = 32'h00000013;  // nop
        
        repeat(100) @(posedge clk);
        check_result(2, 32'hDEADBEF0, "Load/Store result");
        
        // TEST 4: Branch instruction (BEQ)
        $display("\n--- Test 4: Branch (BEQ) ---");
        resetn = 0;
        repeat(5) @(posedge clk);
        resetn = 1;
        
        memory[0]  = 32'h00200093;  // addi x1, x0, 2     (x1 = 2)
        memory[1]  = 32'h00200113;  // addi x2, x0, 2     (x2 = 2)
        memory[2]  = 32'h00208463;  // beq  x1, x2, 8     (branch to PC+8)
        memory[3]  = 32'h00100193;  // addi x3, x0, 1     (skipped)
        memory[4]  = 32'h00000013;  // nop                (skipped)
        memory[5]  = 32'h00A00193;  // addi x3, x0, 10    (executed: x3=10)
        memory[6]  = 32'h00002237;  // lui  x4, 0x2       (x4 = 0x2000)
        memory[7]  = 32'h00322623;  // sw   x3, 12(x4)    (result[3] = x3)
        memory[8]  = 32'h00000013;  // nop
        
        repeat(100) @(posedge clk);
        check_result(3, 32'h0000_000A, "Branch taken");
        
        // TEST 5: Logical operations (AND, OR, XOR)
        $display("\n--- Test 5: Logical operations ---");
        resetn = 0;
        repeat(5) @(posedge clk);
        resetn = 1;
        
        memory[0]  = 32'h0FF00093;  // addi x1, x0, 255   (x1 = 0xFF)
        memory[1]  = 32'h05500113;  // addi x2, x0, 85    (x2 = 0x55)
        memory[2]  = 32'h0020F1B3;  // and  x3, x1, x2    (x3 = 0x55)
        memory[3]  = 32'h0020E233;  // or   x4, x1, x2    (x4 = 0xFF)
        memory[4]  = 32'h0020C2B3;  // xor  x5, x1, x2    (x5 = 0xAA)
        memory[5]  = 32'h00002337;  // lui  x6, 0x2       (x6 = 0x2000)
        memory[6]  = 32'h00332823;  // sw   x3, 16(x6)    (result[4] = x3)
        memory[7]  = 32'h00432a23;  // sw   x4, 20(x6)    (result[5] = x4)
        memory[8]  = 32'h00532c23;  // sw   x5, 24(x6)    (result[6] = x5)
        memory[9]  = 32'h00000013;  // nop
        
        repeat(150) @(posedge clk);
        check_result(4, 32'h0000_0055, "AND result");
        check_result(5, 32'h0000_00FF, "OR result");
        check_result(6, 32'h0000_00AA, "XOR result");
        
        // TEST 6: Shift operations
        $display("\n--- Test 6: Shift operations ---");
        resetn = 0;
        repeat(5) @(posedge clk);
        resetn = 1;
        
        memory[0]  = 32'h00800093;  // addi x1, x0, 8     (x1 = 8)
        memory[1]  = 32'h00200113;  // addi x2, x0, 2     (x2 = 2)
        memory[2]  = 32'h002091B3;  // sll  x3, x1, x2    (x3 = 8 << 2 = 32)
        memory[3]  = 32'h0020D233;  // srl  x4, x1, x2    (x4 = 8 >> 2 = 2)
        memory[4]  = 32'h00002337;  // lui  x6, 0x2       (x6 = 0x2000)
        memory[5]  = 32'h00332e23;  // sw   x3, 28(x6)    (result[7] = x3)
        memory[6]  = 32'h02432023;  // sw   x4, 32(x6)    (result[8] = x4)
        memory[7]  = 32'h00000013;  // nop
        
        repeat(200) @(posedge clk);
        check_result(7, 32'h0000_0020, "Shift left result");
        check_result(8, 32'h0000_0002, "Shift right result");
        
        // Print summary
        $display("\n=== Test Summary ===");
        $display("Tests Passed: %0d", test_passed);
        $display("Tests Failed: %0d", test_failed);
        $display("Total Cycles: %0d", cycle_count);
        
        if (test_failed == 0) begin
            $display("\n*** ALL TESTS PASSED ***\n");
        end else begin
            $display("\n*** SOME TESTS FAILED ***\n");
        end
        
        repeat(10) @(posedge clk);
        $finish;
    end
    
    // Timeout watchdog
    initial begin
        #200000; // 200us timeout
        $display("\n[ERROR] Simulation timeout!");
        $display("Tests Passed: %0d", test_passed);
        $display("Tests Failed: %0d", test_failed);
        $finish;
    end
    
    // Reduced instruction trace (only show every 10th instruction to reduce clutter)
    integer instr_count = 0;
    always @(posedge clk) begin
        if (mem_valid && mem_instr && mem_ready) begin
            instr_count = instr_count + 1;
            if (instr_count % 10 == 0 || mem_addr < 32'h20) begin
                $display("[%0t] Fetch: PC=0x%08h, INSTR=0x%08h", 
                         $time, mem_addr, mem_rdata);
            end
        end
    end
    
    // Trap monitor (only report first trap of each test)
    reg trap_reported;
    always @(posedge clk) begin
        if (!resetn) trap_reported <= 0;
        if (trap && !trap_reported) begin
            $display("[%0t] TRAP detected at cycle %0d, PC: 0x%08h", 
                     $time, cycle_count, mem_addr);
            trap_reported <= 1;
        end
    end

endmodule