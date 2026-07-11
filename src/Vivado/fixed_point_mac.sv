`timescale 1ns/1ps

module fixed_point_mac #(
  parameter int IN_WIDTH = 12,
  parameter int COEFF_WIDTH = 16,
  parameter int ACC_WIDTH = 34
)(
  input logic clk,
  input logic rst,
  input logic clr,
  input logic en,
  input logic signed [IN_WIDTH-1:0] x,
  input logic signed [COEFF_WIDTH-1:0] h,
  output logic signed [ACC_WIDTH-1:0] acc
);

  localparam int PROD_WIDTH = IN_WIDTH + COEFF_WIDTH;

  logic signed [PROD_WIDTH-1:0] x_extended;
  logic signed [PROD_WIDTH-1:0] h_extended;
  logic signed [PROD_WIDTH-1:0] prod;
  assign x_extended = {{COEFF_WIDTH{x[IN_WIDTH-1]}}, x};
  assign h_extended = {{IN_WIDTH{h[COEFF_WIDTH-1]}}, h};
  assign prod = x_extended * h_extended;

  always_ff @(posedge clk) begin
    if (rst) begin
      acc <= '0;
    end else if (en) begin
      if (clr) begin
        acc <= ACC_WIDTH'(prod);
      end else begin
        acc <= acc + ACC_WIDTH'(prod);
      end
    end
  end

endmodule
