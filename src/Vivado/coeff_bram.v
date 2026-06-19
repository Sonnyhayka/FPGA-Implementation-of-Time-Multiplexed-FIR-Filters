`timescale 1ns/1ps

module coeff_bram #(
  parameter N = 64,
  parameter M = 4,
  parameter COEFF_WIDTH = 16,
  parameter COEFF_FILE = "h_q115.txt"
)(
  input wire clk,
  input wire [$clog2(N/M)-1:0] rd_addr,
  output reg [M*COEFF_WIDTH-1:0] coeffs
);

  localparam CYCLES = N / M;

  (* ram_style = "block" *) reg [M*COEFF_WIDTH-1:0] mem [0:CYCLES-1];
  reg [COEFF_WIDTH-1:0] flat [0:N-1];

  integer c;
  integer m;

  initial begin
    $readmemb(COEFF_FILE, flat);
    for (c = 0; c < CYCLES; c = c + 1) begin
      for (m = 0; m < M; m = m + 1) begin
        mem[c][m*COEFF_WIDTH +: COEFF_WIDTH] = flat[m*CYCLES + c];
      end
    end
  end

  always @(posedge clk) begin
    coeffs <= mem[rd_addr];
  end

endmodule
