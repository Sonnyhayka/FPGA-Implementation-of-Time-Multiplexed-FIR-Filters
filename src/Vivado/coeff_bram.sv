`timescale 1ns/1ps

module coeff_bram #(
  parameter int N = 64,
  parameter int M = 4,
  parameter int COEFF_WIDTH = 16,
  parameter COEFF_FILE = "h_q115_packed.txt"
)(
  input logic clk,
  input logic [((N/M) > 1 ? $clog2(N/M) : 1)-1:0] rd_addr,
  output logic [M*COEFF_WIDTH-1:0] coeffs
);

  localparam int CYCLES = N / M;

  (* rom_style = "block" *) logic [M*COEFF_WIDTH-1:0] mem [0:CYCLES-1];

  initial begin
    $readmemb(COEFF_FILE, mem);
  end

  always_ff @(posedge clk) begin
    coeffs <= mem[rd_addr];
  end

endmodule
