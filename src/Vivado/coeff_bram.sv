`timescale 1ns/1ps

module coeff_bram #(
  parameter int N = 64,
  parameter int M = 4,
  parameter int COEFF_WIDTH = 16,
  parameter string COEFF_FILE = "h_q115.txt"
)(
  input logic clk,
  input logic [$clog2(N/M)-1:0] rd_addr,
  output logic [M*COEFF_WIDTH-1:0] coeffs
);

  localparam int CYCLES = N / M;

  (* ram_style = "block" *) logic [M*COEFF_WIDTH-1:0] mem [0:CYCLES-1];
  logic [COEFF_WIDTH-1:0] flat [0:N-1];

  initial begin
    $readmemb(COEFF_FILE, flat);
    for (int c = 0; c < CYCLES; c++) begin
      for (int m = 0; m < M; m++) begin
        mem[c][m*COEFF_WIDTH +: COEFF_WIDTH] = flat[m*CYCLES + c];
      end
    end
  end

  always_ff @(posedge clk) begin
    coeffs <= mem[rd_addr];
  end

endmodule
