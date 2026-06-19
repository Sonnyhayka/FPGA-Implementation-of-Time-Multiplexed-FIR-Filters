`timescale 1ns/1ps

module fir_time_mux_top #(
  parameter N = 64,
  parameter M = 4,
  parameter SRL_REG = 0,
  parameter IN_WIDTH = 12,
  parameter COEFF_WIDTH = 16,
  parameter OUT_WIDTH = 12,
  parameter IN_FRAC = 10,
  parameter COEFF_FRAC = 15,
  parameter OUT_FRAC = 10,
  parameter COEFF_FILE = "h_q115.txt"
)(
  input wire clk,
  input wire rst,
  input wire in_valid,
  output wire in_ready,
  input wire signed [IN_WIDTH-1:0] x_in,
  output reg out_valid,
  output reg signed [OUT_WIDTH-1:0] y_out
);

  localparam CYCLES = N / M;
  localparam AW = $clog2(CYCLES);
  localparam ACC_WIDTH = IN_WIDTH + COEFF_WIDTH + $clog2(N);
  localparam PROD_FRAC = IN_FRAC + COEFF_FRAC;
  localparam SHIFT = PROD_FRAC - OUT_FRAC;
  localparam signed [ACC_WIDTH:0] OUT_MAX = (1 <<< (OUT_WIDTH-1)) - 1;
  localparam signed [ACC_WIDTH:0] OUT_MIN = -(1 <<< (OUT_WIDTH-1));

  initial begin
    if (N % M != 0) begin
      $display("fir_time_mux_top parameter error N=%0d must be divisible by M=%0d", N, M);
      $finish;
    end
  end

  wire sample_en;
  wire [AW-1:0] coeff_addr;
  wire [AW-1:0] tap_addr;
  wire mac_clr;
  wire mac_en;
  wire acc_capture;
  wire ctrl_out_valid;

  wire [M*IN_WIDTH-1:0] taps;
  wire [M*COEFF_WIDTH-1:0] coeffs;
  wire [M*ACC_WIDTH-1:0] acc_bus;

  fir_time_mux_controller #(
    .N(N),
    .M(M)
  ) u_ctrl (
    .clk(clk),
    .rst(rst),
    .in_valid(in_valid),
    .in_ready(in_ready),
    .sample_en(sample_en),
    .coeff_addr(coeff_addr),
    .tap_addr(tap_addr),
    .mac_clr(mac_clr),
    .mac_en(mac_en),
    .acc_capture(acc_capture),
    .out_valid(ctrl_out_valid)
  );

  fir_delay_line #(
    .N(N),
    .M(M),
    .DATA_WIDTH(IN_WIDTH),
    .SRL_REG(SRL_REG)
  ) u_delay (
    .clk(clk),
    .rst(rst),
    .en(sample_en),
    .din(x_in),
    .tap_addr(tap_addr),
    .taps(taps)
  );

  coeff_bram #(
    .N(N),
    .M(M),
    .COEFF_WIDTH(COEFF_WIDTH),
    .COEFF_FILE(COEFF_FILE)
  ) u_coeff (
    .clk(clk),
    .rd_addr(coeff_addr),
    .coeffs(coeffs)
  );

  genvar gi;
  generate
    for (gi = 0; gi < M; gi = gi + 1) begin : g_mac
      fixed_point_mac #(
        .IN_WIDTH(IN_WIDTH),
        .COEFF_WIDTH(COEFF_WIDTH),
        .ACC_WIDTH(ACC_WIDTH)
      ) u_mac (
        .clk(clk),
        .rst(rst),
        .clr(mac_clr),
        .en(mac_en),
        .x(taps[gi*IN_WIDTH +: IN_WIDTH]),
        .h(coeffs[gi*COEFF_WIDTH +: COEFF_WIDTH]),
        .acc(acc_bus[gi*ACC_WIDTH +: ACC_WIDTH])
      );
    end
  endgenerate

  integer ti;
  reg signed [ACC_WIDTH-1:0] acc_sum;
  always @* begin
    acc_sum = {ACC_WIDTH{1'b0}};
    for (ti = 0; ti < M; ti = ti + 1) begin
      acc_sum = acc_sum + $signed(acc_bus[ti*ACC_WIDTH +: ACC_WIDTH]);
    end
  end

  reg signed [ACC_WIDTH-1:0] sum_reg;
  always @(posedge clk) begin
    if (rst) begin
      sum_reg <= {ACC_WIDTH{1'b0}};
    end else if (acc_capture) begin
      sum_reg <= acc_sum;
    end
  end

  function signed [OUT_WIDTH-1:0] saturate_round;
    input signed [ACC_WIDTH-1:0] a;
    reg signed [ACC_WIDTH:0] as;
    reg [ACC_WIDTH:0] mag;
    reg [ACC_WIDTH:0] magr;
    reg signed [ACC_WIDTH:0] res;
    begin
      as = a;
      mag = as[ACC_WIDTH] ? (-as) : as;
      magr = (mag + (1 << (SHIFT-1))) >> SHIFT;
      res = as[ACC_WIDTH] ? -$signed(magr) : $signed(magr);
      if (res > OUT_MAX) begin
        saturate_round = OUT_MAX[OUT_WIDTH-1:0];
      end else if (res < OUT_MIN) begin
        saturate_round = OUT_MIN[OUT_WIDTH-1:0];
      end else begin
        saturate_round = res[OUT_WIDTH-1:0];
      end
    end
  endfunction

  always @(posedge clk) begin
    if (rst) begin
      out_valid <= 1'b0;
      y_out <= {OUT_WIDTH{1'b0}};
    end else begin
      out_valid <= ctrl_out_valid;
      if (ctrl_out_valid) begin
        y_out <= saturate_round(sum_reg);
      end
    end
  end

endmodule
