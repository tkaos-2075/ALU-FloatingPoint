module fsub(
  input clk,
  input rst,
  input start,
  input mode_fp, // 0=half(16), 1=single(32)
  input [31:0] op_a,
  input [31:0] op_b,
  input round_mode, // 0=truncate, 1=nearest even
  output reg [31:0] result,
  output reg valid_out,
  output reg [4:0] flags // {invalid, div0, ovf, udf, inx}
);

  // ---------- SINGLE (32b) ----------
  wire [31:0] y32;
  wire [4:0] f32;
  wire [31:0] b32_neg = {~op_b[31], op_b[30:0]}; // -b (32b): invierte signo

  fadd_core #(.NEXP(8), .NSIG(23)) u_add_single(
    .a(op_a[31:0]),
    .b(b32_neg),
    .round_mode(round_mode),
    .y(y32),
    .flags(f32)
  );

  // ---------- HALF (16b) ----------
  wire [15:0] y16;
  wire [4:0] f16;
  wire [15:0] b16_neg = {~op_b[15], op_b[14:0]}; // -b (16b): invierte signo

  fadd_core #(.NEXP(5), .NSIG(10)) u_add_half(
    .a(op_a[15:0]),
    .b(b16_neg),
    .round_mode(round_mode),
    .y(y16),
    .flags(f16)
  );

  // ---------- Registro de salida ----------
  always @(posedge clk or posedge rst) begin
    if (rst) begin
      result <= 32'b0;
      flags <= 5'b0;
      valid_out <= 1'b0;
    end else begin
      if (start) begin
        if (mode_fp) begin
          result <= y32;
          flags <= f32;
        end else begin
          result <= {16'b0, y16};
          flags <= f16;
        end
        valid_out <= 1'b1;
      end
    end
  end
endmodule
