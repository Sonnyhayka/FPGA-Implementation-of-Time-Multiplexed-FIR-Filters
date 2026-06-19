`timescale 1ns/1ps

module fixed_point_mac #(
  parameter IN_WIDTH = 12,
  parameter COEFF_WIDTH = 16,
  parameter ACC_WIDTH = 34
)(
  input wire clk,
  input wire rst,
  input wire clr,
  input wire en,
  input wire signed [IN_WIDTH-1:0] x,
  input wire signed [COEFF_WIDTH-1:0] h,
  output reg signed [ACC_WIDTH-1:0] acc
);

  localparam PROD_WIDTH = IN_WIDTH + COEFF_WIDTH;

  wire signed [PROD_WIDTH-1:0] prod = x * h;

  always @(posedge clk) begin
    if (rst) begin
      acc <= {ACC_WIDTH{1'b0}};
    end else if (en) begin
      if (clr) begin
        acc <= $signed(prod);
      end else begin
        acc <= acc + $signed(prod);
      end
    end
  end

endmodule
