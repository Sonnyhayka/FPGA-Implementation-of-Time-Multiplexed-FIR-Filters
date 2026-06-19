`timescale 1ns/1ps

module fir_time_mux_top #(
  parameter int N = 64,
  parameter int M = 4,
  parameter int SRL_REG = 0,
  parameter int IN_WIDTH = 12,
  parameter int COEFF_WIDTH = 16,
  parameter int OUT_WIDTH = 12,
  parameter int IN_FRAC = 10,
  parameter int COEFF_FRAC = 15,
  parameter int OUT_FRAC = 10,
  parameter string COEFF_FILE = "h_q115.txt"
)(
  input logic clk,
  input logic rst,
  input logic in_valid,
  output logic in_ready,
  input logic signed [IN_WIDTH-1:0] x_in,
  output logic out_valid,
  output logic signed [OUT_WIDTH-1:0] y_out
);

  localparam int CYCLES = N / M;
  localparam int AW = $clog2(CYCLES);
  localparam int ACC_WIDTH = IN_WIDTH + COEFF_WIDTH + $clog2(N);
  localparam int PROD_FRAC = IN_FRAC + COEFF_FRAC;
  localparam int SHIFT = PROD_FRAC - OUT_FRAC;
  localparam logic signed [ACC_WIDTH:0] OUT_MAX = (1 <<< (OUT_WIDTH-1)) - 1;
  localparam logic signed [ACC_WIDTH:0] OUT_MIN = -(1 <<< (OUT_WIDTH-1));

  initial begin
    if (N % M != 0) begin
      $display("fir_time_mux_top parameter error N=%0d must be divisible by M=%0d", N, M);
      $finish;
    end
  end

  logic sample_en;
  logic [AW-1:0] coeff_addr;
  logic [AW-1:0] tap_addr;
  logic mac_clr;
  logic mac_en;
  logic acc_capture;
  logic ctrl_out_valid;

  logic [M*IN_WIDTH-1:0] taps;
  logic [M*COEFF_WIDTH-1:0] coeffs;
  logic [M*ACC_WIDTH-1:0] acc_bus;

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
    for (gi = 0; gi < M; gi++) begin : g_mac
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

  logic signed [ACC_WIDTH-1:0] acc_sum;
  always_comb begin
    acc_sum = '0;
    for (int ti = 0; ti < M; ti++) begin
      acc_sum = acc_sum + signed'(acc_bus[ti*ACC_WIDTH +: ACC_WIDTH]);
    end
  end

  logic signed [ACC_WIDTH-1:0] sum_reg;
  always_ff @(posedge clk) begin
    if (rst) begin
      sum_reg <= '0;
    end else if (acc_capture) begin
      sum_reg <= acc_sum;
    end
  end

  function automatic logic signed [OUT_WIDTH-1:0] saturate_round(input logic signed [ACC_WIDTH-1:0] a);
    logic signed [ACC_WIDTH:0] as;
    logic [ACC_WIDTH:0] mag;
    logic [ACC_WIDTH:0] magr;
    logic signed [ACC_WIDTH:0] res;
    begin
      as = a;
      mag = as[ACC_WIDTH] ? (-as) : as;
      magr = (mag + (1 << (SHIFT-1))) >> SHIFT;
      res = as[ACC_WIDTH] ? -signed'(magr) : signed'(magr);
      if (res > OUT_MAX) begin
        saturate_round = OUT_MAX[OUT_WIDTH-1:0];
      end else if (res < OUT_MIN) begin
        saturate_round = OUT_MIN[OUT_WIDTH-1:0];
      end else begin
        saturate_round = res[OUT_WIDTH-1:0];
      end
    end
  endfunction

  always_ff @(posedge clk) begin
    if (rst) begin
      out_valid <= 1'b0;
      y_out <= '0;
    end else begin
      out_valid <= ctrl_out_valid;
      if (ctrl_out_valid) begin
        y_out <= saturate_round(sum_reg);
      end
    end
  end

endmodule
