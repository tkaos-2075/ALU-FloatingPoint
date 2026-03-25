`timescale 1ns / 1ps

module fdiv_tb;
    // dut ports
    reg         clk;
    reg         rst;
    reg         start;
    reg         mode_fp;        // 0 half 16b, 1 single 32b
    reg         round_mode;     // 0 truncate, 1 nearest even
    reg  [31:0] op_a, op_b;
    wire [31:0] result;
    wire        valid_out;
    wire [4:0]  flags;          // {invalid, div0, ovf, udf, inx}
    
    integer passed_tests = 0;
    integer failed_tests = 0;
    
    // DUT
    fdiv dut (
        .clk(clk),
        .rst(rst),
        .start(start),
        .mode_fp(mode_fp),
        .op_a(op_a),
        .op_b(op_b),
        .round_mode(round_mode),
        .result(result),
        .valid_out(valid_out),
        .flags(flags)
    );
    
    // 100 MHz clock
    initial begin
        clk = 1'b0;
        forever #5 clk = ~clk;
    end
    
    // drive start and wait for the rising edge of valid_out, then SAMPLE IMMEDIATELY
    // helper. wait for valid_out and sample in the same cycle
    task drive_and_wait;
        input [31:0] A;
        input [31:0] B;
        integer cycles;
        begin
            // apply inputs stable before start
            op_a  = A;
            op_b  = B;
    
            // one clock pulse on start
            @(posedge clk);
            start = 1'b1;
            @(posedge clk);
            start = 1'b0;
    
            // wait for valid_out asserted; DO NOT add an extra clock after this
            cycles = 0;
            while (valid_out !== 1'b1 && cycles < 100000) begin
                @(posedge clk);
                cycles = cycles + 1;
            end
            if (valid_out !== 1'b1) begin
                $display("timeout waiting valid_out for A=0x%08h B=0x%08h", A, B);
            end
            // result is valid now in this same cycle
        end
    endtask
    
    // test with expected result (multiplication)
    task test_case;
        input [8*128-1:0] label_txt; // ascii label
        input [31:0] A;
        input [31:0] B;
        input [31:0] EXPECTED;
        reg   [31:0] res_sample;
        begin
            drive_and_wait(A, B);
            res_sample = result; // sample right away, same cycle as valid_out
    
            if (res_sample === EXPECTED) begin
                $display("%0s0x%08h / 0x%08h = 0x%08h =? 0x%08h [PASS]",
                         label_txt, A, B, res_sample, EXPECTED);
                passed_tests = passed_tests + 1;
            end else begin
                $display("%0s0x%08h / 0x%08h = 0x%08h =? 0x%08h [FAIL]",
                         label_txt, A, B, res_sample, EXPECTED);
                failed_tests = failed_tests + 1;
            end
        end
    endtask
    
    // stimulus
    initial begin
        // reset and cfg
        rst        = 1'b1;
        start      = 1'b0;
        mode_fp    = 1'b1;   // single 32b
        round_mode = 1'b1;   // nearest even
        op_a       = 32'h0;
        op_b       = 32'h0;
        repeat (3) @(posedge clk);
        rst = 1'b0;
    
        // examples
        test_case("Test001 numb / numb :: ", 32'h40490FDB, 32'h3F800000, 32'h40490FDB);
        test_case("Test002 numb / numb :: ", 32'hC0000000, 32'h40800000, 32'hBF000000);
        test_case("Test003 numb / numb :: ", 32'h3F400000, 32'hBFC00000, 32'hBF000000);
        test_case("Test004 inf+ / inf+ :: ", 32'h7F800000, 32'h7F800000, 32'h7FC00000);
        test_case("Test005 inf+ / inf- :: ", 32'h7F800000, 32'hFF800000, 32'h7FC00000);
        test_case("Test006 inf+ / snan :: ", 32'h7F800000, 32'h7F800001, 32'h7FC00000);
        test_case("Test007 inf+ / qnan :: ", 32'h7F800000, 32'h7FC00000, 32'h7FC00000);
        test_case("Test008 inf+ / zer+ :: ", 32'h7F800000, 32'h00000000, 32'h7F800000);
        
        test_case("Test009  inf+ / zer- :: ", 32'h7F800000, 32'h80000000, 32'hFF800000);
        test_case("Test010  inf- / inf+ :: ", 32'hFF800000, 32'h7F800000, 32'h7FC00000);
        test_case("Test011  inf- / inf- :: ", 32'hFF800000, 32'hFF800000, 32'h7FC00000);
        test_case("Test012  inf- / snan :: ", 32'hFF800000, 32'h7F800001, 32'h7FC00000);
        test_case("Test013  inf- / qnan :: ", 32'hFF800000, 32'h7FC00000, 32'h7FC00000);
        test_case("Test014  inf- / zer+ :: ", 32'hFF800000, 32'h00000000, 32'hFF800000);
        test_case("Test015  inf- / zer- :: ", 32'hFF800000, 32'h80000000, 32'h7F800000);
        test_case("Test016  snan / inf+ :: ", 32'h7F800001, 32'h7F800000, 32'h7FC00000);
        
        test_case("Test017 snan / inf- :: ", 32'h7F800001, 32'hFF800000, 32'h7FC00000);
        test_case("Test018 snan / snan :: ", 32'h7F800001, 32'h7F800001, 32'h7FC00000);
        test_case("Test019 snan / qnan :: ", 32'h7F800001, 32'h7FC00000, 32'h7FC00000);
        test_case("Test020 snan / zer+ :: ", 32'h7F800001, 32'h00000000, 32'h7FC00000);
        test_case("Test021 snan / zer- :: ", 32'h7F800001, 32'h80000000, 32'h7FC00000);
        test_case("Test022 qnan / inf+ :: ", 32'h7FC00000, 32'h7F800000, 32'h7FC00000);
        test_case("Test023 qnan / inf- :: ", 32'h7FC00000, 32'hFF800000, 32'h7FC00000);
        test_case("Test024 qnan / snan :: ", 32'h7FC00000, 32'h7F800001, 32'h7FC00000);
        
        
        test_case("Test025 qnan / qnan :: ", 32'h7FC00000, 32'h7FC00000, 32'h7FC00000);
        test_case("Test026 qnan / zer+ :: ", 32'h7FC00000, 32'h00000000, 32'h7FC00000);
        test_case("Test027 qnan / zer- :: ", 32'h7FC00000, 32'h80000000, 32'h7FC00000);
        test_case("Test028 zer+ / inf+ :: ", 32'h00000000, 32'h7F800000, 32'h00000000);
        test_case("Test029 zer+ / inf- :: ", 32'h00000000, 32'hFF800000, 32'h80000000);
        test_case("Test030 zer+ / snan :: ", 32'h00000000, 32'h7F800001, 32'h7FC00000);
        test_case("Test031 zer+ / qnan :: ", 32'h00000000, 32'h7FC00000, 32'h7FC00000);
        test_case("Test032 zer+ / zer+ :: ", 32'h00000000, 32'h00000000, 32'h7FC00000);
        
        test_case("Test033 zer+ / zer- :: ", 32'h00000000, 32'h80000000, 32'h7FC00000);
        test_case("Test034 zer- / inf+ :: ", 32'h80000000, 32'h7F800000, 32'h80000000); // -0 / +inf -> -0
        test_case("Test035 zer- / inf- :: ", 32'h80000000, 32'hFF800000, 32'h00000000); // -0 / -inf -> +0
        test_case("Test036 zer- / snan :: ", 32'h80000000, 32'h7F800001, 32'h7FC00000);
        test_case("Test037 zer- / qnan :: ", 32'h80000000, 32'h7FC00000, 32'h7FC00000);
        test_case("Test038 zer- / zer+ :: ", 32'h80000000, 32'h00000000, 32'h7FC00000);
        test_case("Test039 zer- / zer- :: ", 32'h80000000, 32'h80000000, 32'h7FC00000);
        test_case("Test040 nez+ / nez+ :: ", 32'h00800000, 32'h00800000, 32'h3F800000); // subnorm_min / subnorm_min = 1.0
        
        test_case("Test041 nez- / nez- :: ", 32'h80800000, 32'h80800000, 32'h3F800000);
        test_case("Test042 nei+ / nei+ :: ", 32'h7F7FFFFF, 32'h7F7FFFFF, 32'h3F800000);
        test_case("Test043 nei- / nei- :: ", 32'hFF7FFFFF, 32'hFF7FFFFF, 32'h3F800000);
        test_case("Test044 subn / subn :: ", 32'h00000001, 32'h00000001, 32'h3F800000);
        test_case("Test045 subn / numb :: ", 32'h00000001, 32'h40490FDB, 32'h00000000);
        test_case("Test046 gnum / gnum :: ", 32'h7F7FFFFF, 32'h7F7FFFFF, 32'h3F800000);
        test_case("Test047 snum / snum :: ", 32'h00000002, 32'h00000002, 32'h3F800000);
        test_case("Test048 numb / zer+ :: ", 32'h40800000, 32'h00000000, 32'h7F800000);



        // ---- half precision (round to nearest-even) ----
        mode_fp    = 1'b0;  // half
        round_mode = 1'b1;  // nearest-even

        test_case("Half001 numb / numb :: ", 32'h00003e00, 32'h00004080, 32'h00003955); // 1.5 / 2.25
        test_case("Half002 numb / snum :: ", 32'h00003c00, 32'h00001000, 32'h00006800);
        test_case("Half003 gnum / snum :: ", 32'h00007bff, 32'h0000fbff, 32'h0000bc00); // 65504 / (-65504)
        test_case("Half004 numb / numb :: ", 32'h00004000, 32'h00003e00, 32'h00003d55); 




        // ---- single precision (truncate / round_mode=0) ----
        mode_fp    = 1'b1;  // single
        round_mode = 1'b0;  // truncate (toward zero)

        test_case("SgTr001 numb / snum :: ", 32'h3f800000, 32'h30800000, 32'h4e800000);
        test_case("SgTr002 numb / numb :: ", 32'hc0000000, 32'h40800000, 32'hbf000000);
        test_case("SgTr003 numb / numb :: ", 32'h40600000, 32'h40880000, 32'h3f52d2d2);
        test_case("SgTr004 inf+ / inf+ :: ", 32'h7f800000, 32'h7f800000, 32'h7fc00000);
        
        
        
        // summary
        $display("PASSED TEST: %03d", passed_tests);
        $display("FAILED TEST: %03d", failed_tests);
    
        #10;
        $finish;
    end
    
endmodule
