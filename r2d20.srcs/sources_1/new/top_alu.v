`timescale 1ns / 1ps

module top_alu(
  input  clk, rst,              // Reloj y reinicio
  input  [7:0] chrg_part,       // Carga parcial (8 bits)
  input  chrg_a, chrg_b,        // Selección de carga para A o B
  input  [1:0] op_code,         // Operación: 00=sum, 01=res, 10=mul, 11=div
  input  mode_fp,               // Precisión: 0=half, 1=single
  input  round_mode,            // Redondeo: 0=trunc, 1=nearest even
  input  start,                 // Inicio de operación
  input  out_part,              // Parte de salida: 0=baja, 1=alta
  output wire clk_led,          // Reloj dividido (LED)
  output wire valid_out,        // Operación finalizada
  output wire [4:0] flags,      // Banderas: {invalid, div0, ovf, undf, inexact}
  output wire [6:0] seg,        // Segmentos del display
  output wire [3:0] an,         // Ánodos del display
  output wire dp                // Punto decimal
);
  
  // ====== Debouncing de botones (solo en síntesis) ======
  wire start_db, rst_db;
  `ifdef SYNTHESIS
    debouncer db_start(.clk(clk), .btn_in(start), .btn_out(start_db));
    debouncer db_rst  (.clk(clk), .btn_in(rst),   .btn_out(rst_db));
  `else
    assign start_db = start;
    assign rst_db   = rst;
  `endif

  // ====== Reloj lento ======
  clockdivider dut1(
    .in_clk  (clk),
    .reset_clk(rst_db),
    .out_clk (clk_led)
  );

  // ====== Operandos internos (ya no salen a pines) ======
  wire [31:0] op_a, op_b;

  // ====== Concatenador de operandos ======
  concat_in dut2(
    .clk       (clk_led),
    .rst       (rst_db),
    .chrg_part (chrg_part),
    .chrg_a    (chrg_a),
    .chrg_b    (chrg_b),
    .op_a      (op_a),
    .op_b      (op_b)
  );

  // ====== Salidas intermedias ======
  wire [31:0] res_add, res_sub, res_mul, res_div;
  wire        valid_add, valid_sub, valid_mul, valid_div;
  wire [4:0]  flags_add, flags_sub, flags_mul, flags_div;

  // ====== Instancias de las ALUs ======
  fadd u_add (
    .clk(clk_led), .rst(rst_db), .start(start_db),
    .mode_fp(mode_fp), .round_mode(round_mode),
    .op_a(op_a), .op_b(op_b),
    .result(res_add), .valid_out(valid_add), .flags(flags_add)
  );

  fsub u_sub (
    .clk(clk_led), .rst(rst_db), .start(start_db),
    .mode_fp(mode_fp), .round_mode(round_mode),
    .op_a(op_a), .op_b(op_b),
    .result(res_sub), .valid_out(valid_sub), .flags(flags_sub)
  );

  fmul u_mul (
    .clk(clk_led), .rst(rst_db), .start(start_db),
    .mode_fp(mode_fp), .round_mode(round_mode),
    .op_a(op_a), .op_b(op_b),
    .result(res_mul), .valid_out(valid_mul), .flags(flags_mul)
  );

  fdiv u_div (
    .clk(clk_led), .rst(rst_db), .start(start_db),
    .mode_fp(mode_fp), .round_mode(round_mode),
    .op_a(op_a), .op_b(op_b),
    .result(res_div), .valid_out(valid_div), .flags(flags_div)
  );

  // ====== Selección de resultado según op_code ======
  reg [31:0] result_sel;
  reg [4:0]  flags_sel;
  reg        valid_sel;

  always @(*) begin
    case (op_code)
      2'b00: begin result_sel = res_add; flags_sel = flags_add; valid_sel = valid_add; end
      2'b01: begin result_sel = res_sub; flags_sel = flags_sub; valid_sel = valid_sub; end
      2'b10: begin result_sel = res_mul; flags_sel = flags_mul; valid_sel = valid_mul; end
      2'b11: begin result_sel = res_div; flags_sel = flags_div; valid_sel = valid_div; end
      default: begin result_sel = 32'h0; flags_sel = 5'h0; valid_sel = 1'b0; end
    endcase
  end

  assign flags     = flags_sel;
  assign valid_out = valid_sel;

  // ====== Display con memoria de última fuente ======
  reg [1:0]  last_source;      // 00=result, 01=op_a, 10=op_b
  reg [31:0] display_source;

  always @(posedge clk_led or posedge rst_db) begin
    if (rst_db) begin
      last_source <= 2'b00; // Por defecto mostrar resultado
    end else begin
      if (chrg_a && !chrg_b)      last_source <= 2'b01; // A
      else if (chrg_b && !chrg_a) last_source <= 2'b10; // B
      // valid_out se prioriza en la lógica combinacional
    end
  end

  // Prioridad: valid_out > last_source (carga reciente)
  always @(*) begin
    if (valid_out) begin
      display_source = result_sel;
    end else begin
      case (last_source)
        2'b01: display_source = op_a;
        2'b10: display_source = op_b;
        default: display_source = result_sel;
      endcase
    end
  end

  // Durante carga activa, mostrar parte alta; sino respetar out_part
  wire        display_loading = chrg_a | chrg_b;
  wire [15:0] display_val     = display_loading
                                ? display_source[31:16]
                                : (out_part ? display_source[31:16] : display_source[15:0]);

  display_driver disp (
    .clk  (clk),
    .rst  (rst_db),
    .value(display_val),
    .seg  (seg),
    .an   (an),
    .dp   (dp)
  );

endmodule


// ====== MÓDULO DEBOUNCER ======
module debouncer(
    input clk,
    input btn_in,
    output reg btn_out
);
    parameter DELAY = 500000; // ~5ms a 100MHz (ajustar según necesidad)
    
    reg [19:0] counter; // Ajustar tamaño según DELAY
    reg btn_sync_0, btn_sync_1;
    
    // Sincronización de 2 etapas para evitar metaestabilidad
    always @(posedge clk) begin
        btn_sync_0 <= btn_in;
        btn_sync_1 <= btn_sync_0;
    end
    
    // Lógica de debouncing
    always @(posedge clk) begin
        if (btn_sync_1 != btn_out) begin
            counter <= counter + 1;
            if (counter >= DELAY) begin
                btn_out <= btn_sync_1;
                counter <= 0;
            end
        end else begin
            counter <= 0;
        end
    end
endmodule

module concat_in(
    input  clk,
    input  rst,            // activo en 1
    input  [7:0] chrg_part,
    input  chrg_a,
    input  chrg_b,
    output reg [31:0] op_a,
    output reg [31:0] op_b
);

    always @(posedge clk or posedge rst) begin
      if (rst) begin
        op_a <= 0;
        op_b <= 0;
      end else begin
        op_a <= op_a;
        op_b <= op_b;

        case ({chrg_a, chrg_b})
          2'b10: op_a <= {op_a[23:0], chrg_part};
          2'b01: op_b <= {op_b[23:0], chrg_part};
        endcase
      end
    end
endmodule


module display_driver(
    input clk,
    input rst,
    input [15:0] value,
    output reg [6:0] seg,
    output reg [3:0] an,
    output wire dp
);
    // Separar los 4 dígitos
    wire [3:0] digit0 = value[3:0];
    wire [3:0] digit1 = value[7:4];
    wire [3:0] digit2 = value[11:8];
    wire [3:0] digit3 = value[15:12];

    // Contador de refresco
    `ifdef SYNTHESIS
      reg [17:0] refresh_counter;
    `else
      reg [0:0] refresh_counter; // Para simulación más rápida
    `endif
    reg [1:0] current_digit;

    always @(posedge clk or posedge rst) begin
        if (rst) begin
            refresh_counter <= 0;
            current_digit <= 0;
        end else begin
            refresh_counter <= refresh_counter + 1;
            if (refresh_counter == 0)
                current_digit <= current_digit + 1;
        end
    end

    // Selección de dígito activo
    reg [3:0] current_value;
    always @(*) begin
        case (current_digit)
            2'b00: begin an = 4'b1110; current_value = digit0; end
            2'b01: begin an = 4'b1101; current_value = digit1; end
            2'b10: begin an = 4'b1011; current_value = digit2; end
            2'b11: begin an = 4'b0111; current_value = digit3; end
            default: begin an = 4'b1111; current_value = 4'h0; end
        endcase
    end

    // Decodificador hexadecimal a 7 segmentos
    always @(*) begin
        case (current_value)
            4'h0: seg = 7'b0000001;  // A-B-C-D-E-F encendidos, G apagado
            4'h1: seg = 7'b1001111;  // B-C encendidos
            4'h2: seg = 7'b0010010;  // A-B-D-E-G encendidos
            4'h3: seg = 7'b0000110;  // A-B-C-D-G encendidos
            4'h4: seg = 7'b1001100;  // B-C-F-G encendidos
            4'h5: seg = 7'b0100100;  // A-C-D-F-G encendidos
            4'h6: seg = 7'b0100000;  // A-C-D-E-F-G encendidos
            4'h7: seg = 7'b0001111;  // A-B-C encendidos
            4'h8: seg = 7'b0000000;  // Todos encendidos
            4'h9: seg = 7'b0000100;  // A-B-C-D-F-G encendidos
            4'hA: seg = 7'b0001000;  // A-B-C-E-F-G encendidos
            4'hB: seg = 7'b1100000;  // C-D-E-F-G encendidos
            4'hC: seg = 7'b0110001;  // A-D-E-F encendidos
            4'hD: seg = 7'b1000010;  // B-C-D-E-G encendidos
            4'hE: seg = 7'b0110000;  // A-D-E-F-G encendidos
            4'hF: seg = 7'b0111000;  // A-E-F-G encendidos
            default: seg = 7'b1111111; // todo apagado
        endcase
    end

    assign dp = 1;
endmodule


module clockdivider(
  input in_clk,
  input reset_clk,
  output reg out_clk
);
  `ifdef SYNTHESIS
    reg [26:0] counter;
  `else
    reg [0:0] counter;  // Para simulación más rápida
  `endif

  always @(posedge in_clk or posedge reset_clk) begin
    if (reset_clk) begin
      counter <= 0;
      out_clk <= 0;        
    end
    else begin
      counter <= counter + 1;
      if (counter == 0)
        out_clk <= ~out_clk;
    end
  end
endmodule
