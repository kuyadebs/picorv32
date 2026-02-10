`timescale 1ns/1ps

module testbench;
    reg clk = 0;
    reg resetn = 0;
    wire trap;
    
    // Memory signals
    wire        mem_valid;
    wire        mem_instr;
    reg         mem_ready = 0;
    wire [31:0] mem_addr;
    wire [31:0] mem_wdata;
    wire [ 3:0] mem_wstrb;
    reg  [31:0] mem_rdata = 0;
    
    // Memory array
    reg [31:0] memory [0:1023];
    
    // Instantiate PicoRV32
    picorv32 #(
        .ENABLE_COUNTERS(1),
        .ENABLE_MUL(0),
        .ENABLE_IRQ(0),
        .COMPRESSED_ISA(0),
        .PROGADDR_RESET(32'h00000000)
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
        .mem_rdata(mem_rdata)
    );
    
    // Clock generation
    always #5 clk = ~clk;
    
    // Simple memory model
    always @(posedge clk) begin
        if (!resetn) begin
            mem_ready <= 0;
        end else if (mem_valid) begin
            // Simulate 1-cycle memory latency
            mem_ready <= 1;
            
            if (mem_wstrb != 0) begin
                // Store operation
                case (mem_wstrb)
                    4'b1111: memory[mem_addr[11:2]] <= mem_wdata;
                    4'b0011: memory[mem_addr[11:2]][15:0] <= mem_wdata[15:0];
                    4'b1100: memory[mem_addr[11:2]][31:16] <= mem_wdata[31:16];
                    // ... handle other cases
                endcase
                $display("[%0t] MEM WRITE: addr=%h data=%h strb=%b", 
                         $time, mem_addr, mem_wdata, mem_wstrb);
            end else begin
                // Load operation
                mem_rdata <= memory[mem_addr[11:2]];
                $display("[%0t] MEM READ: addr=%h data=%h", 
                         $time, mem_addr, memory[mem_addr[11:2]]);
            end
        end else begin
            mem_ready <= 0;
        end
    end
    
    // Monitor signals
    always @(posedge clk) begin
        if (resetn) begin
            // Monitor CPU state
            $display("[%0t] PC=%h State=%h", $time, dut.reg_pc, dut.cpu_state);
            
            // Monitor register writes
            if (dut.cpuregs_write && dut.latched_rd != 0) begin
                $display("  REG WRITE: x%0d = %h", dut.latched_rd, dut.cpuregs_wrdata);
            end
        end
    end
    
    // Initialize memory with test program
    initial begin
        // Enable VCD dump for waveform viewing
        $dumpfile("waves.vcd");
        $dumpvars(0, testbench);
        
        // Initialize memory with simple test program
        // ADDI x1, x0, 5
        memory[0] = 32'h00500093;  // addi x1, x0, 5
        // ADDI x2, x0, 3  
        memory[1] = 32'h00300113;  // addi x2, x0, 3
        // ADD x3, x1, x2
        memory[2] = 32'h002081b3;  // add x3, x1, x2
        // SW x3, 0(x0)
        memory[3] = 32'h00302023;  // sw x3, 0(x0)
        // LW x4, 0(x0)
        memory[4] = 32'h00002203;  // lw x4, 0(x0)
        // EBREAK (end test)
        memory[5] = 32'h00100073;  // ebreak
        
        // Reset sequence
        resetn = 0;
        #100 resetn = 1;
        
        // Run for some cycles
        #1000;
        
        // Check results
        $display("\n=== TEST RESULTS ===");
        $display("x1 (reg5) = %h (expected: 5)", dut.cpuregs[1]);
        $display("x2 (reg6) = %h (expected: 3)", dut.cpuregs[2]);
        $display("x3 (reg7) = %h (expected: 8)", dut.cpuregs[3]);
        $display("x4 (reg8) = %h (expected: 8)", dut.cpuregs[4]);
        $display("Memory[0] = %h (expected: 8)", memory[0]);
        
        if (trap) begin
            $display("CPU trapped (expected for ebreak)");
        end
        
        $finish;
    end
endmodule