`timescale 1ns/1ps

module fir_delay_line #(
  parameter int N = 64,
  parameter int M = 4,
  parameter int DATA_WIDTH = 12,
  parameter int SRL_REG = 0
)(
  input logic clk,
  input logic rst,
  input logic en,
  input logic [DATA_WIDTH-1:0] din,
  input logic [((N/M) > 1 ? $clog2(N/M) : 1)-1:0] tap_addr,
  output logic [M*DATA_WIDTH-1:0] taps
);

  localparam int CYCLES = N / M;

  genvar m;

  generate
    if (SRL_REG == 0) begin : g_reg
      logic [DATA_WIDTH-1:0] sr [0:N-1];
      always_ff @(posedge clk) begin
        if (rst) begin
          for (int i = 0; i < N; i++) begin
            sr[i] <= '0;
          end
        end else if (en) begin
          for (int i = N-1; i > 0; i--) begin
            sr[i] <= sr[i-1];
          end
          sr[0] <= din;
        end
      end
      for (m = 0; m < M; m++) begin : g_tap
        assign taps[m*DATA_WIDTH +: DATA_WIDTH] = sr[tap_addr + m*CYCLES];
      end
    end else begin : g_srl
      logic [DATA_WIDTH-1:0] cascade [0:M];
      assign cascade[0] = din;
      for (m = 0; m < M; m++) begin : g_segment
        (* shreg_extract = "yes", srl_style = "srl" *) logic [DATA_WIDTH-1:0] sr [0:CYCLES-1];
        initial begin
          for (int j = 0; j < CYCLES; j++) begin
            sr[j] = '0;
          end
        end
        always_ff @(posedge clk) begin
          if (en) begin
            for (int i = CYCLES-1; i > 0; i--) begin
              sr[i] <= sr[i-1];
            end
            sr[0] <= cascade[m];
          end
        end
        assign cascade[m+1] = sr[CYCLES-1];
        assign taps[m*DATA_WIDTH +: DATA_WIDTH] = sr[tap_addr];
      end
    end
  endgenerate

endmodule
