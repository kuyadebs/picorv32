`timescale 1ns/1ps

module tb_alu;
    // Test the ALU directly
    reg clk = 0;
    reg [31:0] reg_op1, reg_op2;
    reg instr_add, instr_sub, instr_and, instr_or, instr_xor;
    reg instr_sll, instr_srl, instr_sra;
    wire [31:0] alu_out;
    
    // Clock generation
    always #5 clk = ~clk;
    
    // Direct copy of ALU logic from picorv32
    assign alu_out = 
        instr_add ? reg_op1 + reg_op2 :
        instr_sub ? reg_op1 - reg_op2 :
        instr_and ? reg_op1 & reg_op2 :
        instr_or  ? reg_op1 | reg_op2 :
        instr_xor ? reg_op1 ^ reg_op2 :
        instr_sll ? reg_op1 << reg_op2[4:0] :
        instr_srl ? reg_op1 >> reg_op2[4:0] :
        instr_sra ? $signed(reg_op1) >>> reg_op2[4:0] :
        32'hxxxxxxxx;
    
    // Test sequence
    initial begin
        // Create VCD file for this testbench
        $dumpfile("waves_alu.vcd");
        $dumpvars(0, tb_alu);
        
        $display("=== ALU UNIT TEST ===");
        
        // Initialize
        reg_op1 = 0;
        reg_op2 = 0;
        instr_add = 0; instr_sub = 0; instr_and = 0; instr_or = 0; instr_xor = 0;
        instr_sll = 0; instr_srl = 0; instr_sra = 0;
        
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
        
        // Test 5: Shift Left
        @(posedge clk);
        reg_op1 = 32'h00000001;
        reg_op2 = 32'h00000004;
        instr_sll = 1;
        @(posedge clk);
        $display("[%0t] SLL: %h << %h = %h (expected: 10)", 
                 $time, reg_op1, reg_op2, alu_out);
        if (alu_out !== 32'h00000010) $error("SLL failed!");
        instr_sll = 0;
        
        // Test 6: Test XOR
        @(posedge clk);
        reg_op1 = 32'hF0F0F0F0;
        reg_op2 = 32'h0F0F0F0F;
        instr_xor = 1;
        @(posedge clk);
        $display("[%0t] XOR: %h ^ %h = %h (expected: FFFFFFFF)", 
                 $time, reg_op1, reg_op2, alu_out);
        if (alu_out !== 32'hFFFFFFFF) $error("XOR failed!");
        instr_xor = 0;


        // Test 7: Shift Right Logical
        @(posedge clk);
        reg_op1 = 32'hF0000000;
        reg_op2 = 32'h00000004;
        instr_srl = 1;
        @(posedge clk);
        $display("[%0t] SRL: %h >> %h = %h (expected: 0F000000)", $time, reg_op1, reg_op2, alu_out);
        if (alu_out !== 32'h0F000000) $error("SRL failed!");
        instr_srl = 0;



        #20;
        $display("ALU tests passed!");
        $finish;
    end
endmodule