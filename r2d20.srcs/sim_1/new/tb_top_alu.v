`timescale 1ns / 1ps

module tb_top_alu();

  // ====== Señales base ======
  reg clk, rst;

  // ====== Carga de operandos ======
  reg [7:0] chrg_part;
  reg chrg_a, chrg_b;

  // ====== Control de ALU ======
  reg [1:0] op_code;
  reg mode_fp;
  reg round_mode;
  reg start;
  reg out_part;

  // ====== Salidas visibles ======
  wire clk_led;
  wire valid_out;
  wire [4:0] flags;
  wire [6:0] seg;
  wire [3:0] an;
  wire dp;

  // ====== DUT (sin .result, sin .op_a, sin .op_b) ======
  top_alu dut (
    .clk(clk),
    .rst(rst),
    .chrg_part(chrg_part),
    .chrg_a(chrg_a),
    .chrg_b(chrg_b),
    .op_code(op_code),
    .mode_fp(mode_fp),
    .round_mode(round_mode),
    .start(start),
    .out_part(out_part),
    .clk_led(clk_led),
    .valid_out(valid_out),
    .flags(flags),
    .seg(seg),
    .an(an),
    .dp(dp)
  );

  // ====== Taps jerárquicos (solo simulación) ======
  // Ajusta los nombres si cambian dentro de top_alu
  wire [31:0] op_a_mon   = dut.op_a;
  wire [31:0] op_b_mon   = dut.op_b;
  wire [31:0] result_mon = dut.result_sel;

  // ====== Reloj 100 MHz ======
  initial clk = 0;
  always #5 clk = ~clk;

  // ====== Estímulos ======
  initial begin
    // ===== INICIALIZACIÓN =====
    rst = 1;
    chrg_part = 8'h00;
    chrg_a = 0;
    chrg_b = 0;
    start = 0;
    mode_fp = 1;        // usar 32 bits
    round_mode = 1;     // RN-even
    out_part = 0;
    op_code = 2'b00;    // ADD
    repeat (2) @(posedge clk);

    // ===== CARGAR OPERANDO A =====
    $display("\n[TIEMPO %0t] Iniciando carga de operando A", $time);
    rst = 0;  // liberar reset
    chrg_a = 1;
    chrg_part = 8'h12; @(posedge clk_led); #1;
    chrg_part = 8'h34; @(posedge clk_led); #1;
    chrg_part = 8'h56; @(posedge clk_led); #1;
    chrg_part = 8'h78; @(posedge clk_led); #1;
    chrg_a = 0;
    $display("[TIEMPO %0t] Operando A cargado: %h", $time, op_a_mon);
    @(posedge clk_led); @(posedge clk_led); #1;

    // ===== CARGAR OPERANDO B =====
    $display("\n[TIEMPO %0t] Iniciando carga de operando B", $time);
    chrg_b = 1;
    chrg_part = 8'h9A; @(posedge clk_led); #1;
    chrg_part = 8'hBC; @(posedge clk_led); #1;
    chrg_part = 8'hDE; @(posedge clk_led); #1;
    chrg_part = 8'hF0; @(posedge clk_led); #1;
    chrg_b = 0;
    $display("[TIEMPO %0t] Operando B cargado: %h", $time, op_b_mon);
    @(posedge clk_led); @(posedge clk_led); #1;

    // ===== EJECUTAR OPERACIÓN =====
    $display("\n[TIEMPO %0t] Ejecutando FADD (32 bits, round=nearest)", $time);
    start = 1; @(posedge clk_led); #1; start = 0;

    if (valid_out) begin
      $display("[TIEMPO %0t] RESULTADO DISPONIBLE", $time);
      $display("  Result = %h", result_mon);
      $display("  Flags  = {inv=%b, div0=%b, ovf=%b, udf=%b, inx=%b}",
               flags[4], flags[3], flags[2], flags[1], flags[0]);
    end else begin
      $display("[TIEMPO %0t] ADVERTENCIA: resultado no disponible", $time);
    end

    @(posedge clk_led); @(posedge clk_led); #1;

    // ===== RE-INICIALIZACIÓN / MODO 16b =====
    rst = 1;
    chrg_part = 8'h00;
    chrg_a = 0;
    chrg_b = 0;
    start = 0;
    mode_fp = 0;        // 16 bits
    round_mode = 1;
    out_part = 0;
    op_code = 2'b00;    // ADD
    repeat (2) @(posedge clk);

    // A (16b)
    $display("\n[TIEMPO %0t] Iniciando carga de operando A (16b)", $time);
    rst = 0;
    chrg_a = 1;
    chrg_part = 8'h12; @(posedge clk_led); #1;
    chrg_part = 8'h34; @(posedge clk_led); #1;
    chrg_a = 0;
    $display("[TIEMPO %0t] Operando A cargado: %h", $time, op_a_mon);
    @(posedge clk_led); @(posedge clk_led); #1;

    // B (16b)
    $display("\n[TIEMPO %0t] Iniciando carga de operando B (16b)", $time);
    chrg_b = 1;
    chrg_part = 8'h9A; @(posedge clk_led); #1;
    chrg_part = 8'hBC; @(posedge clk_led); #1;
    chrg_b = 0;
    $display("[TIEMPO %0t] Operando B cargado: %h", $time, op_b_mon);
    @(posedge clk_led); @(posedge clk_led); #1;

    // Ejecutar
    $display("\n[TIEMPO %0t] Ejecutando FADD (16 bits, round=nearest)", $time);
    start = 1; @(posedge clk_led); #1; start = 0;

    if (valid_out) begin
      $display("[TIEMPO %0t] RESULTADO DISPONIBLE", $time);
      $display("  Result = %h", result_mon);
      $display("  Flags  = {inv=%b, div0=%b, ovf=%b, udf=%b, inx=%b}",
               flags[4], flags[3], flags[2], flags[1], flags[0]);
    end else begin
      $display("[TIEMPO %0t] ADVERTENCIA: resultado no disponible", $time);
    end

    @(posedge clk_led); @(posedge clk_led); #1;
    $finish;
  end

  // ====== Monitor ======
  initial begin
    $monitor("[%0t] clk=%b clk_led=%b | A=%h B=%h | result=%h valid=%b flags=%b | an=%b seg=%b",
             $time, clk, clk_led, op_a_mon, op_b_mon, result_mon, valid_out, flags, an, seg);
  end

endmodule
