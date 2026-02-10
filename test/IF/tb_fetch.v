`timescale 1ns / 1ps

////////////////////////////////////////////////////////////////////////////////
// PicoRV32 Instruction Fetch Testbench
// 
// This testbench focuses on testing the instruction fetch mechanism of the
// PicoRV32 processor, including:
// - Basic instruction fetch from reset
// - Sequential instruction fetches
// - Branch instruction fetches
// - Memory handshaking (mem_valid/mem_ready)
// - Instruction prefetch behavior
////////////////////////////////////////////////////////////////////////////////

module tb_fetch;

    // Clock and Reset
    reg clk;
    reg resetn;
    
    // Memory Interface Signals
    wire        mem_valid;
    wire        mem_instr;
    reg         mem_ready;
    wire [31:0] mem_addr;
    wire [31:0] mem_wdata;
    wire [ 3:0] mem_wstrb;
    reg  [31:0] mem_rdata;
    
    // Look-Ahead Interface
    wire        mem_la_read;
    wire        mem_la_write;
    wire [31:0] mem_la_addr;
    wire [31:0] mem_la_wdata;
    wire [ 3:0] mem_la_wstrb;
    
    // Trap signal
    wire trap;
    
    // IRQ signals (tied off for this test)
    reg [31:0] irq;
    wire [31:0] eoi;
    
    // PCPI signals (tied off)
    wire        pcpi_valid;
    wire [31:0] pcpi_insn;
    wire [31:0] pcpi_rs1;
    wire [31:0] pcpi_rs2;
    reg         pcpi_wr;
    reg  [31:0] pcpi_rd;
    reg         pcpi_wait;
    reg         pcpi_ready;
    
    // Test control
    integer test_num;
    integer cycle_count;
    integer fetch_count;
    
    // Instruction memory - simple ROM
    reg [31:0] instr_mem [0:255];
    
    ////////////////////////////////////////////////////////////////////////////
    // DUT Instantiation
    ////////////////////////////////////////////////////////////////////////////
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
        .ENABLE_IRQ_QREGS(0),
        .ENABLE_IRQ_TIMER(0),
        .ENABLE_TRACE(0),
        .REGS_INIT_ZERO(0),
        .PROGADDR_RESET(32'h00000000),
        .PROGADDR_IRQ(32'h00000010),
        .STACKADDR(32'hFFFFFFFF)
    ) dut (
        .clk(clk),
        .resetn(resetn),
        .trap(trap),
        
        // Memory Interface
        .mem_valid(mem_valid),
        .mem_instr(mem_instr),
        .mem_ready(mem_ready),
        .mem_addr(mem_addr),
        .mem_wdata(mem_wdata),
        .mem_wstrb(mem_wstrb),
        .mem_rdata(mem_rdata),
        
        // Look-Ahead Interface
        .mem_la_read(mem_la_read),
        .mem_la_write(mem_la_write),
        .mem_la_addr(mem_la_addr),
        .mem_la_wdata(mem_la_wdata),
        .mem_la_wstrb(mem_la_wstrb),
        
        // PCPI (unused)
        .pcpi_valid(pcpi_valid),
        .pcpi_insn(pcpi_insn),
        .pcpi_rs1(pcpi_rs1),
        .pcpi_rs2(pcpi_rs2),
        .pcpi_wr(pcpi_wr),
        .pcpi_rd(pcpi_rd),
        .pcpi_wait(pcpi_wait),
        .pcpi_ready(pcpi_ready),
        
        // IRQ (unused)
        .irq(irq),
        .eoi(eoi)
    );
    
    ////////////////////////////////////////////////////////////////////////////
    // Clock Generation - 100MHz (10ns period)
    ////////////////////////////////////////////////////////////////////////////
    initial begin
        clk = 0;
        forever #5 clk = ~clk;
    end
    
    ////////////////////////////////////////////////////////////////////////////
    // Instruction Memory Model
    ////////////////////////////////////////////////////////////////////////////
    initial begin
        // Initialize instruction memory
        // Test program: Simple sequence of instructions
        
        // Address 0x00: ADDI x1, x0, 5    (x1 = 5)
        instr_mem[0]  = 32'h00500093;
        
        // Address 0x04: ADDI x2, x0, 10   (x2 = 10)
        instr_mem[1]  = 32'h00A00113;
        
        // Address 0x08: ADD x3, x1, x2    (x3 = x1 + x2 = 15)
        instr_mem[2]  = 32'h002081B3;
        
        // Address 0x0C: SUB x4, x2, x1    (x4 = x2 - x1 = 5)
        instr_mem[3]  = 32'h40110233;
        
        // Address 0x10: ADDI x5, x0, 20   (x5 = 20)
        instr_mem[4]  = 32'h01400293;
        
        // Address 0x14: JAL x0, 8         (Jump forward 8 bytes to 0x1C)
        instr_mem[5]  = 32'h008000EF;
        
        // Address 0x18: ADDI x6, x0, 99   (Should be skipped)
        instr_mem[6]  = 32'h06300313;
        
        // Address 0x1C: ADDI x7, x0, 30   (x7 = 30)
        instr_mem[7]  = 32'h01E00393;
        
        // Address 0x20: AND x8, x3, x4    (x8 = x3 & x4)
        instr_mem[8]  = 32'h00419433;
        
        // Address 0x24: OR x9, x1, x2     (x9 = x1 | x2)
        instr_mem[9]  = 32'h0020E4B3;
        
        // Fill rest with NOPs
        for (integer i = 10; i < 256; i = i + 1) begin
            instr_mem[i] = 32'h00000013;  // ADDI x0, x0, 0 (NOP)
        end
    end
    
    ////////////////////////////////////////////////////////////////////////////
    // Memory Response Logic
    ////////////////////////////////////////////////////////////////////////////
    always @(posedge clk) begin
        if (!resetn) begin
            mem_ready <= 0;
            mem_rdata <= 32'h0;
        end else begin
            // Simple memory model: 1 cycle latency
            if (mem_valid && !mem_ready) begin
                mem_ready <= 1;
                if (mem_instr) begin
                    // Instruction fetch
                    mem_rdata <= instr_mem[mem_addr[31:2]];
                    $display("[%0t] FETCH: addr=0x%08h, data=0x%08h", 
                             $time, mem_addr, instr_mem[mem_addr[31:2]]);
                end else begin
                    // Data access (not tested here, return 0)
                    mem_rdata <= 32'h0;
                end
            end else if (mem_ready) begin
                mem_ready <= 0;
            end
        end
    end
    
    ////////////////////////////////////////////////////////////////////////////
    // Monitoring and Statistics
    ////////////////////////////////////////////////////////////////////////////
    always @(posedge clk) begin
        if (resetn) begin
            cycle_count <= cycle_count + 1;
            
            // Count instruction fetches
            if (mem_valid && mem_instr && mem_ready) begin
                fetch_count <= fetch_count + 1;
            end
            
            // Monitor fetch activity
            if (mem_valid && mem_instr) begin
                $display("[%0t] [Cycle %0d] Instruction Fetch Request:", 
                         $time, cycle_count);
                $display("          Address: 0x%08h", mem_addr);
                if (mem_ready) begin
                    $display("          Data:    0x%08h (READY)", mem_rdata);
                end
            end
            
            // Monitor look-ahead signals
            if (mem_la_read) begin
                $display("[%0t] [Cycle %0d] Look-Ahead Read: addr=0x%08h", 
                         $time, cycle_count, mem_la_addr);
            end
            
            // Check for trap
            if (trap) begin
                $display("[%0t] *** TRAP DETECTED ***", $time);
            end
        end
    end
    
    ////////////////////////////////////////////////////////////////////////////
    // Test Sequence
    ////////////////////////////////////////////////////////////////////////////
    initial begin
        // Initialize signals
        resetn = 0;
        irq = 32'h0;
        pcpi_wr = 0;
        pcpi_rd = 32'h0;
        pcpi_wait = 0;
        pcpi_ready = 0;
        test_num = 0;
        cycle_count = 0;
        fetch_count = 0;
        
        // Create VCD dump - Only dump essential signals for instruction fetch
        $dumpfile("tb_fetch.vcd");
        
        // Testbench signals
        $dumpvars(0, clk);
        $dumpvars(0, resetn);
        $dumpvars(0, trap);
        $dumpvars(0, cycle_count);
        $dumpvars(0, fetch_count);
        $dumpvars(0, test_num);
        
        // Memory interface signals - PRIMARY SIGNALS FOR FETCH
        $dumpvars(0, mem_valid);
        $dumpvars(0, mem_instr);
        $dumpvars(0, mem_ready);
        $dumpvars(0, mem_addr);
        $dumpvars(0, mem_rdata);
        $dumpvars(0, mem_wdata);
        $dumpvars(0, mem_wstrb);
        
        // Look-ahead interface
        $dumpvars(0, mem_la_read);
        $dumpvars(0, mem_la_write);
        $dumpvars(0, mem_la_addr);
        
        // Key DUT internal signals for understanding fetch behavior
        $dumpvars(0, dut.cpu_state);
        $dumpvars(0, dut.reg_pc);
        $dumpvars(0, dut.reg_next_pc);
        $dumpvars(0, dut.mem_do_rinst);
        $dumpvars(0, dut.mem_do_prefetch);
        $dumpvars(0, dut.decoder_trigger);
        $dumpvars(0, dut.mem_state);
        $dumpvars(0, dut.mem_rdata_latched);
        
        // Do NOT dump:
        // - Register file (dut.cpuregs) - not needed for fetch testing
        // - ALU signals - not needed for fetch testing
        // - All other DUT internals - keeps VCD small and focused
        
        $display("================================================================================");
        $display("PicoRV32 Instruction Fetch Testbench");
        $display("================================================================================");
        
        // Wait for initial settling
        #10;
        
        ////////////////////////////////////////////////////////////////////////
        // TEST 1: Reset and First Fetch
        ////////////////////////////////////////////////////////////////////////
        test_num = 1;
        $display("\n[TEST %0d] Reset and First Instruction Fetch", test_num);
        $display("------------------------------------------------------------");
        
        // Release reset
        @(posedge clk);
        #1 resetn = 1;
        $display("[%0t] Reset released", $time);
        
        // Wait for first fetch
        wait(mem_valid && mem_instr);
        $display("[%0t] First instruction fetch detected", $time);
        
        // Verify it's fetching from reset address
        if (mem_addr == 32'h00000000) begin
            $display("[PASS] Fetching from reset address 0x00000000");
        end else begin
            $display("[FAIL] Expected fetch from 0x00000000, got 0x%08h", mem_addr);
        end
        
        ////////////////////////////////////////////////////////////////////////
        // TEST 2: Sequential Fetches
        ////////////////////////////////////////////////////////////////////////
        test_num = 2;
        $display("\n[TEST %0d] Sequential Instruction Fetches", test_num);
        $display("------------------------------------------------------------");
        
        // Let it run and fetch several sequential instructions
        repeat(10) @(posedge clk);
        
        $display("[INFO] Observed %0d instruction fetches", fetch_count);
        
        ////////////////////////////////////////////////////////////////////////
        // TEST 3: Monitor Fetch Pattern
        ////////////////////////////////////////////////////////////////////////
        test_num = 3;
        $display("\n[TEST %0d] Extended Fetch Pattern Monitoring", test_num);
        $display("------------------------------------------------------------");
        
        // Run for more cycles to observe full behavior
        repeat(100) @(posedge clk);
        
        $display("[INFO] Total cycles: %0d", cycle_count);
        $display("[INFO] Total fetches: %0d", fetch_count);
        if (fetch_count > 0) begin
            $display("[INFO] Average CPI: %0d.%02d", 
                     cycle_count / fetch_count, 
                     ((cycle_count * 100) / fetch_count) % 100);
        end
        
        ////////////////////////////////////////////////////////////////////////
        // TEST 4: Verify mem_instr Signal
        ////////////////////////////////////////////////////////////////////////
        test_num = 4;
        $display("\n[TEST %0d] Verify mem_instr Signal", test_num);
        $display("------------------------------------------------------------");
        
        // Check that mem_instr is asserted during instruction fetches
        @(posedge clk);
        wait(mem_valid);
        @(posedge clk);
        
        if (mem_valid && mem_instr) begin
            $display("[PASS] mem_instr is HIGH during instruction fetch");
        end else if (mem_valid && !mem_instr) begin
            $display("[INFO] mem_instr is LOW - this is a data access");
        end
        
        ////////////////////////////////////////////////////////////////////////
        // TEST 5: Look-Ahead Interface
        ////////////////////////////////////////////////////////////////////////
        test_num = 5;
        $display("\n[TEST %0d] Look-Ahead Interface Behavior", test_num);
        $display("------------------------------------------------------------");
        
        repeat(20) begin
            @(posedge clk);
            if (mem_la_read) begin
                $display("[INFO] Look-ahead read detected at addr 0x%08h", mem_la_addr);
            end
        end
        
        ////////////////////////////////////////////////////////////////////////
        // Final Statistics
        ////////////////////////////////////////////////////////////////////////
        #100;
        
        $display("\n================================================================================");
        $display("Test Summary");
        $display("================================================================================");
        $display("Total simulation cycles: %0d", cycle_count);
        $display("Total instruction fetches: %0d", fetch_count);
        $display("Trap occurred: %s", trap ? "YES" : "NO");
        $display("\n[INFO] All instruction fetch tests completed!");
        $display("================================================================================\n");
        
        $finish;
    end
    
    ////////////////////////////////////////////////////////////////////////////
    // Timeout Watchdog
    ////////////////////////////////////////////////////////////////////////////
    initial begin
        #100000;  // 100us timeout
        $display("\n[ERROR] Simulation timeout!");
        $finish;
    end
    
endmodule