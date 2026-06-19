`timescale 1ns/1ps

module fir_delay_line #(
  parameter N = 64,
  parameter M = 4,
  parameter DATA_WIDTH = 12,
  parameter SRL_REG = 0
)(
  input wire clk,
  input wire rst,
  input wire en,
  input wire [DATA_WIDTH-1:0] din,
  input wire [$clog2(N/M)-1:0] tap_addr,
  output wire [M*DATA_WIDTH-1:0] taps
);

  localparam CYCLES = N / M;

  genvar m;

  generate
    if (SRL_REG == 0) begin : g_reg
      reg [DATA_WIDTH-1:0] sr [0:N-1];
      integer i;
      always @(posedge clk) begin
        if (rst) begin
          for (i = 0; i < N; i = i + 1) begin
            sr[i] <= {DATA_WIDTH{1'b0}};
          end
        end else if (en) begin
          for (i = N-1; i > 0; i = i - 1) begin
            sr[i] <= sr[i-1];
          end
          sr[0] <= din;
        end
      end
      for (m = 0; m < M; m = m + 1) begin : g_tap
        assign taps[m*DATA_WIDTH +: DATA_WIDTH] = sr[tap_addr + m*CYCLES];
      end
    end else begin : g_srl
      (* srl_style = "srl" *) reg [DATA_WIDTH-1:0] sr [0:N-1];
      integer i;
      integer j;
      initial begin
        for (j = 0; j < N; j = j + 1) begin
          sr[j] = {DATA_WIDTH{1'b0}};
        end
      end
      always @(posedge clk) begin
        if (en) begin
          for (i = N-1; i > 0; i = i - 1) begin
            sr[i] <= sr[i-1];
          end
          sr[0] <= din;
        end
      end
      for (m = 0; m < M; m = m + 1) begin : g_tap
        assign taps[m*DATA_WIDTH +: DATA_WIDTH] = sr[tap_addr + m*CYCLES];
      end
    end
  endgenerate

endmodule
