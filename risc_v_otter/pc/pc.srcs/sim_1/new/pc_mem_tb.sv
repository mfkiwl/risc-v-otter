`timescale 1ns / 1ps

/*
  Test pc_mod along with memory
  to ensure proper operation
*/
module pc_mem_tb();

    // Declare in/out connections
    reg clk;
    reg rst;
    reg PCWrite;
    reg [1:0] pcSource;
    wire [31:0] ir;
    
    // Run clock
    initial begin
        clk = 0;
        forever #10 clk = ~clk;
    end
    
    // Instantiate module
    pc_mem_top_level UUT (
        .clk      (clk),
        .rst      (rst),
        .PCWrite  (PCWrite),
        .pcSource (pcSource),
        .ir       (ir)
    );
    
    // Simulate
    initial begin
        // Start with incremental instructions (pcWrite = 2'b00)
        rst = 1'b1;
        #21;
        rst = 1'b0;
        PCWrite = 1'b1;
        pcSource = 2'b00;
        #32;
        rst = 1'b0;
        #5;
        pcSource = 2'b00;
        #30;
        PCWrite = 1'b0;
        #30;
        // Now simulate the jumps. Go through pcSource with values 1-3
        for (int i = 1; i < 4; i++) begin
            rst = 1'b1;
            #20;
            rst = 1'b0;
            #10;
            pcSource = i;
            #20;
            PCWrite = 1'b1;
            #20;
            PCWrite = 1'b0;
            #20;
        end
    end

endmodule
