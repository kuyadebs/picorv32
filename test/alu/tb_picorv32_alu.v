`timescale 1ns / 1ps

module tb_picorv32_alu;

    // =========================
    // 1. Testbench Signals
    // =========================

    reg clk;
    reg [31:0] reg_op1;
    reg [31:0] reg_op2;

    // ALU control signals (one-hot)
    reg instr_add;
    reg instr_sub;
    reg instr_and;
    reg instr_or;
    reg instr_xor;
    reg instr_sll;
    reg instr_srl;
    reg instr_sra;

    wire [31:0] alu_out;

    // =========================
    // 2. Instantiate ALU
    // =========================
    picorv32 uut (
        .clk(clk),
        .reg_op1(reg_op1),
        .reg_op2(reg_op2),
        .instr_add(instr_add),
        .instr_sub(instr_sub),
        .instr_and(instr_and),
        .instr_or(instr_or),
        .instr_xor(instr_xor),
        .instr_sll(instr_sll),
        .instr_srl(instr_srl),
        .instr_sra(instr_sra),
        .alu_out(alu_out)
    );

    // =========================
    // 3. Clock Generation
    // =========================
    always #5 clk = ~clk;   // 10 ns clock period

    // =========================
    // 4. Test Procedure
    // =========================
    initial begin
        // Initialize everything
        clk = 0;
        reg_op1 = 0;
        reg_op2 = 0;
        instr_add = 0;
        instr_sub = 0;
        instr_and = 0;
        instr_or  = 0;
        instr_xor = 0;
        instr_sll = 0;
        instr_srl = 0;
        instr_sra = 0;

        // Enable waveform dump
        $dumpfile("tb_picorv32_alu.vcd");
        $dumpvars(0, tb_picorv32_alu);

        $display("==== ALU TEST START ====");

        // =========================
        // ADD
        // =========================
        #10;
        reg_op1 = 10;
        reg_op2 = 5;
        instr_add = 1;
        #10;
        $display("ADD: %0d + %0d = %0d", reg_op1, reg_op2, alu_out);
        instr_add = 0;

        // =========================
        // SUB
        // =========================
        #10;
        reg_op1 = 20;
        reg_op2 = 8;
        instr_sub = 1;
        #10;
        $display("SUB: %0d - %0d = %0d", reg_op1, reg_op2, alu_out);
        instr_sub = 0;

        // =========================
        // AND
        // =========================
        #10;
        reg_op1 = 32'hF0F0;
        reg_op2 = 32'h0FF0;
        instr_and = 1;
        #10;
        $display("AND: %h & %h = %h", reg_op1, reg_op2, alu_out);
        instr_and = 0;

        // =========================
        // OR
        // =========================
        #10;
        instr_or = 1;
        #10;
        $display("OR : %h | %h = %h", reg_op1, reg_op2, alu_out);
        instr_or = 0;

        // =========================
        // XOR
        // =========================
        #10;
        instr_xor = 1;
        #10;
        $display("XOR: %h ^ %h = %h", reg_op1, reg_op2, alu_out);
        instr_xor = 0;

        // =========================
        // SLL (Shift Left Logical)
        // =========================
        #10;
        reg_op1 = 4;
        reg_op2 = 2;   // shift amount
        instr_sll = 1;
        #10;
        $display("SLL: %0d << %0d = %0d", reg_op1, reg_op2, alu_out);
        instr_sll = 0;

        // =========================
        // SRL (Shift Right Logical)
        // =========================
        #10;
        instr_srl = 1;
        #10;
        $display("SRL: %0d >> %0d = %0d", reg_op1, reg_op2, alu_out);
        instr_srl = 0;

        // =========================
        // SRA (Shift Right Arithmetic)
        // =========================
        #10;
        reg_op1 = -16;   // signed number
        reg_op2 = 2;
        instr_sra = 1;
        #10;
        $display("SRA: %0d >>> %0d = %0d", reg_op1, reg_op2, alu_out);
        instr_sra = 0;

        // =========================
        // END
        // =========================
        #20;
        $display("==== ALU TEST END ====");
        $finish;
    end

endmodule
