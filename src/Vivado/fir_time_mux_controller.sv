`timescale 1ns/1ps

module fir_time_mux_controller #(
  parameter int N = 64,
  parameter int M = 4
)(
  input logic clk,
  input logic rst,
  input logic in_valid,
  output logic in_ready,
  output logic sample_en,
  output logic [((N/M) > 1 ? $clog2(N/M) : 1)-1:0] coeff_addr,
  output logic [((N/M) > 1 ? $clog2(N/M) : 1)-1:0] tap_addr,
  output logic mac_clr,
  output logic mac_en,
  output logic out_valid
);

  localparam int CYCLES = N / M;
  localparam int AW = CYCLES > 1 ? $clog2(CYCLES) : 1;

  logic active;
  logic [AW-1:0] cycle;

  always_ff @(posedge clk) begin
    if (rst) begin
      active <= 1'b0;
      cycle <= '0;
      out_valid <= 1'b0;
    end else begin
      out_valid <= active && (cycle == CYCLES-1);
      if (!active) begin
        if (in_valid) begin
          active <= 1'b1;
          cycle <= '0;
        end
      end else if (cycle == CYCLES-1) begin
        if (in_valid) begin
          active <= 1'b1;
          cycle <= '0;
        end else begin
          active <= 1'b0;
          cycle <= '0;
        end
      end else begin
        cycle <= cycle + 1'b1;
      end
    end
  end

  assign in_ready = !active || (cycle == CYCLES-1);
  assign sample_en = in_ready && in_valid;
  assign coeff_addr = (!active || (cycle == CYCLES-1)) ? '0 : cycle + 1'b1;
  assign tap_addr = cycle;
  assign mac_en = active;
  assign mac_clr = active && (cycle == 0);

endmodule
