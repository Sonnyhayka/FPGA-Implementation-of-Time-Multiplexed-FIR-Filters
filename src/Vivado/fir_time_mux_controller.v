`timescale 1ns/1ps

module fir_time_mux_controller #(
  parameter N = 64,
  parameter M = 4
)(
  input wire clk,
  input wire rst,
  input wire in_valid,
  output wire in_ready,
  output wire sample_en,
  output wire [$clog2(N/M)-1:0] coeff_addr,
  output wire [$clog2(N/M)-1:0] tap_addr,
  output wire mac_clr,
  output wire mac_en,
  output wire acc_capture,
  output wire out_valid
);

  localparam CYCLES = N / M;
  localparam AW = $clog2(CYCLES);
  localparam LAST = CYCLES + 3;
  localparam SW = $clog2(LAST + 1);

  reg busy;
  reg [SW-1:0] cnt;

  always @(posedge clk) begin
    if (rst) begin
      busy <= 1'b0;
      cnt <= {SW{1'b0}};
    end else if (!busy) begin
      if (in_valid) begin
        busy <= 1'b1;
        cnt <= {{(SW-1){1'b0}}, 1'b1};
      end
    end else if (cnt == LAST[SW-1:0]) begin
      busy <= 1'b0;
      cnt <= {SW{1'b0}};
    end else begin
      cnt <= cnt + 1'b1;
    end
  end

  wire [SW-1:0] cnt_m1 = cnt - 1'b1;
  wire [SW-1:0] cnt_m2 = cnt - 2'd2;

  assign in_ready = !busy;
  assign sample_en = (!busy) & in_valid;
  assign coeff_addr = cnt_m1[AW-1:0];
  assign tap_addr = cnt_m2[AW-1:0];
  assign mac_en = busy & (cnt >= 2) & (cnt <= CYCLES + 1);
  assign mac_clr = busy & (cnt == 2);
  assign acc_capture = busy & (cnt == CYCLES + 2);
  assign out_valid = busy & (cnt == CYCLES + 3);

endmodule
