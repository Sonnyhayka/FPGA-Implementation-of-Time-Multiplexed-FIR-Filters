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
  output logic [$clog2(N/M)-1:0] coeff_addr,
  output logic [$clog2(N/M)-1:0] tap_addr,
  output logic mac_clr,
  output logic mac_en,
  output logic acc_capture,
  output logic out_valid
);

  localparam int CYCLES = N / M;
  localparam int AW = $clog2(CYCLES);
  localparam int LAST = CYCLES + 3;
  localparam int SW = $clog2(LAST + 1);

  logic busy;
  logic [SW-1:0] cnt;

  always_ff @(posedge clk) begin
    if (rst) begin
      busy <= 1'b0;
      cnt <= '0;
    end else if (!busy) begin
      if (in_valid) begin
        busy <= 1'b1;
        cnt <= SW'(1);
      end
    end else if (cnt == SW'(LAST)) begin
      busy <= 1'b0;
      cnt <= '0;
    end else begin
      cnt <= cnt + 1'b1;
    end
  end

  logic [SW-1:0] cnt_m1;
  logic [SW-1:0] cnt_m2;
  assign cnt_m1 = cnt - 1'b1;
  assign cnt_m2 = cnt - 2'd2;

  assign in_ready = !busy;
  assign sample_en = !busy & in_valid;
  assign coeff_addr = cnt_m1[AW-1:0];
  assign tap_addr = cnt_m2[AW-1:0];
  assign mac_en = busy & (cnt >= 2) & (cnt <= CYCLES + 1);
  assign mac_clr = busy & (cnt == 2);
  assign acc_capture = busy & (cnt == CYCLES + 2);
  assign out_valid = busy & (cnt == CYCLES + 3);

endmodule
