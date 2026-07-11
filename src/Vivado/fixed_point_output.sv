`timescale 1ns/1ps

(* use_dsp = "no" *)
module fixed_point_output #(
  parameter int ACC_WIDTH = 34,
  parameter int OUT_WIDTH = 12,
  parameter int SHIFT = 15
)(
  input logic signed [ACC_WIDTH-1:0] acc,
  output logic signed [OUT_WIDTH-1:0] value
);

  localparam logic signed [ACC_WIDTH:0] OUT_MAX = (1 <<< (OUT_WIDTH-1)) - 1;
  localparam logic signed [ACC_WIDTH:0] OUT_MIN = -(1 <<< (OUT_WIDTH-1));
  localparam int QUOTIENT_WIDTH = ACC_WIDTH - SHIFT;
  localparam int MAG_WIDTH = QUOTIENT_WIDTH + 1;

  logic signed [QUOTIENT_WIDTH-1:0] shifted_value;
  logic signed [MAG_WIDTH-1:0] shifted_extended;
  logic [SHIFT-1:0] low_magnitude;
  logic [MAG_WIDTH-1:0] integer_magnitude;
  logic [MAG_WIDTH-1:0] rounded_magnitude;
  logic signed [MAG_WIDTH:0] rounded_value;
  logic remainder_nonzero;
  logic round_up;

  always @* begin
    shifted_value = acc >>> SHIFT;
    shifted_extended = shifted_value;
    remainder_nonzero = |acc[SHIFT-1:0];
    if (acc[ACC_WIDTH-1]) begin
      low_magnitude = ~acc[SHIFT-1:0] + 1'b1;
      integer_magnitude = -shifted_extended - remainder_nonzero;
      round_up = low_magnitude[SHIFT-1];
    end else begin
      low_magnitude = acc[SHIFT-1:0];
      integer_magnitude = shifted_extended;
      round_up = acc[SHIFT-1];
    end
    rounded_magnitude = integer_magnitude + round_up;
    rounded_value = acc[ACC_WIDTH-1] ? -signed'(rounded_magnitude) : signed'(rounded_magnitude);
    if (rounded_value > OUT_MAX) begin
      value = OUT_MAX[OUT_WIDTH-1:0];
    end else if (rounded_value < OUT_MIN) begin
      value = OUT_MIN[OUT_WIDTH-1:0];
    end else begin
      value = rounded_value[OUT_WIDTH-1:0];
    end
  end

endmodule
