`timescale 1ns / 1ps

module OTTER_MCU(
    input RST,
    input intr,
    input clk,
    input [31:0] iobus_in,
    output [31:0] iobus_out,
    output [31:0] iobus_addr,
    output iobus_wr
    );
    
    // PC wires
    wire [31:0] pc_data;
    wire reset;
    wire PCWrite;
    wire [2:0] pcSource;
    
    // pcSource MUX inputs, branch_addr_gen outputs
    wire [31:0] jal, jalr, branch;
    
    // immediate values
    wire [31:0] I_type, J_type, B_type;
    wire [31:0] U_type, S_type;
    
    // wires for branch_cond_gen
    wire br_eq;
    wire br_lt;
    wire br_ltu;
    
    // wires for memory module
    wire memRDEN1, memRDEN2;
    wire memWE2;
    wire [31:0] memDOUT2;
    wire [31:0] ir;
    
    // wires for register file
    wire regWrite;
    wire [1:0] rf_wr_sel;
    wire [31:0] rs1, rs2;
    wire [31:0] rf_wd;
    
    // wires for ALU
    wire [31:0] srcA, srcB; // mux outputs
    wire alu_srcA; // a select
    wire [1:0] alu_srcB; // b select
    wire [3:0] alu_fun;
    wire [31:0] alu_result;
    
    // ID pipeline reg wires
    wire [31:0] id_instr;
    wire [31:0] id_pc;
    
    // EX pipeline reg wires
    wire [31:0] ex_srcA;
    wire [31:0] ex_srcB;
    wire [3:0] ex_alu_fun;
    wire [31:0] ex_pc;
    wire ex_regWrite;
    wire ex_memWE2;
    wire ex_memRDEN2;
    wire [1:0] ex_rf_wr_sel;
    wire [31:0] ex_rs1;
    wire [31:0] ex_rs2;
    wire [31:0] ex_instr;
    wire [31:0] ex_J_type;
    wire [31:0] ex_B_type;
    wire [31:0] ex_I_type;
    
    // M pipeline reg wires
    wire [31:0] m_alu_result;
    wire [31:0] m_rs2;
    wire [31:0] m_pc;
    wire m_regWrite;
    wire m_memWE2;
    wire m_memRDEN2;
    wire [1:0] m_rf_wr_sel;
    wire [31:0] m_instr;
    
    // WB pipeline reg wires
    wire [31:0] wb_pc;
    wire [31:0] wb_instr;
    wire [1:0] wb_rf_wr_sel;
    wire wb_regWrite;
    wire [31:0] wb_memDOUT2;
    
    pc_mod pc (
        .clk      (clk),
        .rst      (RST),
        .PCWrite  (1'b1),
        .pcSource (pcSource),
        .jal      (jal),
        .jalr     (jalr),
        .branch   (branch),
        .pc       (pc_data)
        );
        
    Memory OTTER_MEMORY (
        .MEM_CLK   (clk),
        .MEM_RDEN1 (1),
        .MEM_RDEN2 (m_memRDEN2),
        .MEM_WE2   (m_memWE2),
        .MEM_ADDR1 (pc_data[15:2]),
        .MEM_ADDR2 (m_alu_result),
        .MEM_DIN2  (m_rs2),
        .MEM_SIZE  (m_instr[13:12]),
        .MEM_SIGN  (m_instr[14]),
        .IO_IN     (iobus_in),
        .IO_WR     (iobus_wr),
        .MEM_DOUT1 (ir),
        .MEM_DOUT2 (memDOUT2)
        );
        
     preg_if_id if_id (
        .clk       (clk),
        .pc_in     (pc_data), 
        .instr_in  (ir),
        .pc_out    (id_pc),
        .instr_out (id_instr)
        );
        
     preg_id_ex id_ex (
        .clk           (clk),
        .instr_in      (id_instr),
        .pc_in         (id_pc),
        .regWrite_in   (regWrite),
        .memWrite_in   (memWE2),
        .memRead2_in   (memRDEN2),
        .alu_fun_in    (alu_fun),
        .alu_srcA_in   (srcA),
        .alu_srcB_in   (srcB),
        .rs1_in        (rs1),
        .rs2_in        (rs2),
        .j_type_in     (J_type),
        .b_type_in     (B_type),
        .i_type_in     (I_type),
        .rf_wr_sel_in  (rf_wr_sel),
        .instr_out     (ex_instr),
        .pc_out        (ex_pc),
        .regWrite_out  (ex_regWrite),
        .memWrite_out  (ex_memWE2),
        .memRead2_out  (ex_memRDEN2),
        .alu_fun_out   (ex_alu_fun),
        .alu_srcA_out  (ex_srcA),
        .alu_srcB_out  (ex_srcB),
        .rs1_out       (ex_rs1),
        .rs2_out       (ex_rs2),
        .rf_wr_sel_out (ex_rf_wr_sel),
        .j_type_out    (ex_J_type),
        .b_type_out    (ex_B_type),
        .i_type_out    (ex_I_type)
        );
        
     preg_ex_m ex_m (
        .clk           (clk),
        .instr_in      (ex_instr),
        .pc_in         (ex_pc),
        .regWrite_in   (ex_regWrite),
        .memWrite_in   (ex_memWE2),
        .memRead2_in   (ex_memRDEN2),
        .alu_in        (alu_result),
        .rs2_in        (ex_rs2),
        .rf_wr_sel_in  (ex_rf_wr_sel),
        .instr_out     (m_instr),
        .pc_out        (m_pc),
        .regWrite_out  (m_regWrite),
        .memWrite_out  (m_memWE2),
        .memRead2_out  (m_memRDEN2),
        .alu_out       (m_alu_result),
        .rs2_out       (m_rs2),
        .rf_wr_sel_out (m_rf_wr_sel)
        );
        
     preg_m_wb m_wb (
        .clk           (clk),
        .instr_in      (m_instr),
        .pc_in         (m_pc),
        .regWrite_in   (m_regWrite),
        .rf_wr_sel_in  (m_rf_wr_sel),
        .alu_in        (m_alu_result),
        .memdout2_in   (memDOUT2),
        .instr_out     (wb_instr),
        .pc_out        (wb_pc),
        .regWrite_out  (wb_regWrite),
        .memdout2_out  (wb_memDOUT2),
        .alu_out       (wb_alu_result),
        .rf_wr_sel_out (wb_rf_wr_sel)
        );
        
     mux_4t1_nb  #(.n(32)) rf_wd_mux (
        .SEL   (wb_rf_wr_sel),
        .D0    (wb_pc_data + 4),
        .D1    (0), // was csr_rd
        .D2    (wb_memDOUT2), 
        .D3    (wb_alu_result),
        .D_OUT (rf_wd)
        );  
        
    RegFile regfile (
        .wd   (rf_wd),
        .clk  (clk), 
        .en   (wb_regWrite),
        .adr1 (id_instr[19:15]),
        .adr2 (id_instr[24:20]),
        .wa   (wb_instr[11:7]),
        .rs1  (rs1), 
        .rs2  (rs2)
        );
        
    immed_gen ig (
        .ir     (id_instr[31:7]),
        .U_type (U_type),
        .I_type (I_type),
        .S_type (S_type),
        .J_type (J_type),
        .B_type (B_type)
        );
        
    branch_addr_gen bag (
        .J_type (ex_J_type),
        .B_type (ex_B_type),
        .I_type (ex_I_type),
        .pc     (pc_data),
        .rs1    (ex_rs1),
        .jal    (jal),
        .jalr   (jalr),
        .branch (branch)
        );
        
    mux_2t1_nb  #(.n(32)) alu_a_mux (
        .SEL   (alu_srcA), 
        .D0    (rs1), 
        .D1    (U_type), 
        .D_OUT (srcA)
        );  
        
    mux_4t1_nb  #(.n(32)) alu_b_mux (
        .SEL   (alu_srcB),
        .D0    (rs2),
        .D1    (I_type),
        .D2    (S_type), 
        .D3    (id_pc),
        .D_OUT (srcB)
        );
            
    alu ALU (
        .srcA    (ex_srcA),
        .srcB    (ex_srcB),
        .alu_fun (ex_alu_fun),
        .result  (alu_result)
        );
        
    branch_cond_gen bcg (
        .opcode   (ex_instr[6:0]),
        .func3    (ex_instr[14:12]),
        .rs1      (ex_rs1),
        .rs2      (ex_rs2),
        .pcSource (pcSource)
        );
        
    CU_DCDR cu_dcdr (
        .opcode    (id_instr[6:0]),
        .func7     (id_instr[30]),
        .func3     (id_instr[14:12]),
        .int_taken (int_taken),
        .alu_fun   (alu_fun),
        .alu_srcA  (alu_srcA),
        .alu_srcB  (alu_srcB), 
        .rf_wr_sel (rf_wr_sel),
        .pcWrite   (PCWrite),
        .regWrite  (regWrite),
        .memWE2    (memWE2),
        .memRDEN1  (memRDEN1),
        .memRDEN2  (memRDEN2),
        .reset     (reset)
        );
        
    assign iobus_out = m_rs2;
    assign iobus_addr = m_alu_result;
                
endmodule
