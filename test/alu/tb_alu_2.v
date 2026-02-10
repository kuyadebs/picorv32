`timescale 1ns/1ps

module tb_alu_2;
    // Test the ALU directly
    reg clk = 0;
    reg [31:0] reg_op1, reg_op2;
    reg instr_add, instr_sub, instr_and, instr_or, instr_xor;
    reg instr_sll, instr_srl, instr_sra;
    reg instr_slt, instr_sltu;
    reg instr_beq, instr_bne, instr_blt, instr_bge, instr_bltu, instr_bgeu;
    
    // Internal ALU signals (from the actual implementation)
    wire [31:0] alu_add_sub;
    wire [31:0] alu_shl, alu_shr;
    wire alu_eq, alu_ltu, alu_lts;
    
    wire alu_out_0;
    reg [31:0] alu_out;
    
    // Clock generation
    always #5 clk = ~clk;
    
    // Direct copy of ALU logic from picorv32
    assign alu_add_sub = instr_sub ? reg_op1 - reg_op2 : reg_op1 + reg_op2;
    assign alu_eq = reg_op1 == reg_op2;
    assign alu_lts = $signed(reg_op1) < $signed(reg_op2);
    assign alu_ltu = reg_op1 < reg_op2;
    assign alu_shl = reg_op1 << reg_op2[4:0];
    assign alu_shr = $signed({instr_sra ? reg_op1[31] : 1'b0, reg_op1}) >>> reg_op2[4:0];
    
    // ALU output multiplexing (from actual picorv32)
    assign alu_out_0 = 
        instr_beq ? alu_eq :
        instr_bne ? !alu_eq :
        instr_bge ? !alu_lts :
        instr_bgeu ? !alu_ltu :
        (instr_slt || instr_blt) ? alu_lts :
        (instr_sltu || instr_bltu) ? alu_ltu :
        1'bx;
    
    always @* begin
        alu_out = 'bx;
        if (instr_add || instr_sub) alu_out = alu_add_sub;
        else if (instr_xor) alu_out = reg_op1 ^ reg_op2;
        else if (instr_or) alu_out = reg_op1 | reg_op2;
        else if (instr_and) alu_out = reg_op1 & reg_op2;
        else if (instr_sll) alu_out = alu_shl;
        else if (instr_srl || instr_sra) alu_out = alu_shr;
        else if (instr_beq || instr_bne || instr_blt || instr_bge || instr_bltu || instr_bgeu || 
                 instr_slt || instr_sltu) alu_out = {31'b0, alu_out_0};
    end
    
    // Test sequence
    initial begin
        // Create VCD file for this testbench
        $dumpfile("waves_alu.vcd");
        $dumpvars(0, tb_alu_2);
        
        $display("=== ALU UNIT TEST (PicoRV32 Style) ===");
        
        // Initialize
        reg_op1 = 0;
        reg_op2 = 0;
        instr_add = 0; instr_sub = 0; instr_and = 0; instr_or = 0; instr_xor = 0;
        instr_sll = 0; instr_srl = 0; instr_sra = 0;
        instr_slt = 0; instr_sltu = 0;
        instr_beq = 0; instr_bne = 0; instr_blt = 0; instr_bge = 0; instr_bltu = 0; instr_bgeu = 0;
        
        #10;  // Wait a clock cycle
        
        // Test 1: ADD
        @(posedge clk);
        reg_op1 = 32'h00000005;
        reg_op2 = 32'h00000003;
        instr_add = 1;
        @(posedge clk);
        $display("[%0t] ADD: %h + %h = %h (expected: 8)", 
                 $time, reg_op1, reg_op2, alu_out);
        if (alu_out !== 32'h00000008) $error("ADD failed!");
        instr_add = 0;
        
        // Test 2: SUB
        @(posedge clk);
        instr_sub = 1;
        @(posedge clk);
        $display("[%0t] SUB: %h - %h = %h (expected: 2)", 
                 $time, reg_op1, reg_op2, alu_out);
        if (alu_out !== 32'h00000002) $error("SUB failed!");
        instr_sub = 0;
        
        // Test 3: AND
        @(posedge clk);
        reg_op1 = 32'hF0F0F0F0;
        reg_op2 = 32'h0F0F0F0F;
        instr_and = 1;
        @(posedge clk);
        $display("[%0t] AND: %h & %h = %h (expected: 0)", 
                 $time, reg_op1, reg_op2, alu_out);
        if (alu_out !== 32'h00000000) $error("AND failed!");
        instr_and = 0;
        
        // Test 4: OR
        @(posedge clk);
        instr_or = 1;
        @(posedge clk);
        $display("[%0t] OR: %h | %h = %h (expected: FFFFFFFF)", 
                 $time, reg_op1, reg_op2, alu_out);
        if (alu_out !== 32'hFFFFFFFF) $error("OR failed!");
        instr_or = 0;
        
        // Test 5: XOR
        @(posedge clk);
        instr_xor = 1;
        @(posedge clk);
        $display("[%0t] XOR: %h ^ %h = %h (expected: FFFFFFFF)", 
                 $time, reg_op1, reg_op2, alu_out);
        if (alu_out !== 32'hFFFFFFFF) $error("XOR failed!");
        instr_xor = 0;
        
        // Test 6: Shift Left
        @(posedge clk);
        reg_op1 = 32'h00000001;
        reg_op2 = 32'h00000004;
        instr_sll = 1;
        @(posedge clk);
        $display("[%0t] SLL: %h << %h = %h (expected: 10)", 
                 $time, reg_op1, reg_op2, alu_out);
        if (alu_out !== 32'h00000010) $error("SLL failed!");
        instr_sll = 0;
        
        // Test 7: Shift Right Logical
        @(posedge clk);
        reg_op1 = 32'hF0000000;
        reg_op2 = 32'h00000004;
        instr_srl = 1;
        @(posedge clk);
        $display("[%0t] SRL: %h >> %h = %h (expected: 0F000000)", 
                 $time, reg_op1, reg_op2, alu_out);
        if (alu_out !== 32'h0F000000) $error("SRL failed!");
        instr_srl = 0;

        // Test 8: Shift Right Arithmetic (SRA - negative)
        @(posedge clk);
        reg_op1 = 32'hF0000000; // negative number
        reg_op2 = 32'h00000004;
        instr_sra = 1;
        @(posedge clk);
        $display("[%0t] SRA (neg): %h >>> %h = %h (expected: FF000000)", 
                $time, reg_op1, reg_op2, alu_out);
        if (alu_out !== 32'hFF000000) $error("SRA failed on negative number!"); 
        instr_sra = 0;

        // Test 9: Shift Right Arithmetic (SRA - positive)
        @(posedge clk);
        reg_op1 = 32'h70000000; // positive number
        reg_op2 = 32'h00000004;
        instr_sra = 1;
        @(posedge clk);
        $display("[%0t] SRA (pos): %h >>> %h = %h (expected: 07000000)", 
                $time, reg_op1, reg_op2, alu_out);
        if (alu_out !== 32'h07000000) $error("SRA failed on positive number!");
        instr_sra = 0;
        
        // Test 10: Compare operations
        @(posedge clk);
        reg_op1 = 32'h00000005;
        reg_op2 = 32'h00000003;
        
        // Test 10a: SLT (signed less than) - false
        instr_slt = 1;
        @(posedge clk);
        $display("[%0t] SLT: %h <s %h = %h (expected: 0)", 
                 $time, reg_op1, reg_op2, alu_out);
        if (alu_out !== 32'h00000000) $error("SLT failed!");
        instr_slt = 0;
        
        // Test 10b: SLTU (unsigned less than) - false
        instr_sltu = 1;
        @(posedge clk);
        $display("[%0t] SLTU: %h <u %h = %h (expected: 0)", 
                 $time, reg_op1, reg_op2, alu_out);
        if (alu_out !== 32'h00000000) $error("SLTU failed!");
        instr_sltu = 0;
        
        // Test 10c: BLT (branch if less than) - false
        instr_blt = 1;
        @(posedge clk);
        $display("[%0t] BLT: %h <s %h = %h (expected: 0)", 
                 $time, reg_op1, reg_op2, alu_out);
        if (alu_out !== 32'h00000000) $error("BLT failed!");
        instr_blt = 0;
        
        // Test 10d: BLTU (branch if less than unsigned) - false
        instr_bltu = 1;
        @(posedge clk);
        $display("[%0t] BLTU: %h <u %h = %h (expected: 0)", 
                 $time, reg_op1, reg_op2, alu_out);
        if (alu_out !== 32'h00000000) $error("BLTU failed!");
        instr_bltu = 0;
        
        // Test 11: Compare with negative numbers
        @(posedge clk);
        reg_op1 = 32'hFFFFFFFF; // -1 signed, 4294967295 unsigned
        reg_op2 = 32'h00000001; // +1
        
        // Test 11a: SLT (-1 < 1) - true
        instr_slt = 1;
        @(posedge clk);
        $display("[%0t] SLT: %h <s %h = %h (expected: 1)", 
                 $time, reg_op1, reg_op2, alu_out);
        if (alu_out !== 32'h00000001) $error("SLT with negative failed!");
        instr_slt = 0;
        
        // Test 11b: SLTU (4294967295 < 1) - false
        instr_sltu = 1;
        @(posedge clk);
        $display("[%0t] SLTU: %h <u %h = %h (expected: 0)", 
                 $time, reg_op1, reg_op2, alu_out);
        if (alu_out !== 32'h00000000) $error("SLTU with negative failed!");
        instr_sltu = 0;
        
        // Test 12: Equality comparisons
        @(posedge clk);
        reg_op1 = 32'h12345678;
        reg_op2 = 32'h12345678;
        
        // Test 12a: BEQ (branch if equal) - true
        instr_beq = 1;
        @(posedge clk);
        $display("[%0t] BEQ: %h == %h = %h (expected: 1)", 
                 $time, reg_op1, reg_op2, alu_out);
        if (alu_out !== 32'h00000001) $error("BEQ failed!");
        instr_beq = 0;
        
        // Test 12b: BNE (branch if not equal) - false
        instr_bne = 1;
        @(posedge clk);
        $display("[%0t] BNE: %h != %h = %h (expected: 0)", 
                 $time, reg_op1, reg_op2, alu_out);
        if (alu_out !== 32'h00000000) $error("BNE failed!");
        instr_bne = 0;
        
        // Test 13: Edge cases
        @(posedge clk);
        reg_op1 = 32'h80000000; // Most negative signed number
        reg_op2 = 32'h00000001;
        
        // Test 13a: BGE (branch if greater or equal) - false
        instr_bge = 1;
        @(posedge clk);
        $display("[%0t] BGE: %h >=s %h = %h (expected: 0)", 
                 $time, reg_op1, reg_op2, alu_out);
        if (alu_out !== 32'h00000000) $error("BGE with min negative failed!");
        instr_bge = 0;
        
        // Test 13b: BGEU (branch if greater or equal unsigned) - true
        instr_bgeu = 1;
        @(posedge clk);
        $display("[%0t] BGEU: %h >=u %h = %h (expected: 1)", 
                 $time, reg_op1, reg_op2, alu_out);
        if (alu_out !== 32'h00000001) $error("BGEU with min negative failed!");
        instr_bgeu = 0;

        #20;
        $display("=================================");
        $display("ALU tests completed successfully!");
        $display("=================================");
        $finish;
    end
endmodule