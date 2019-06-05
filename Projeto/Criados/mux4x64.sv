module mux4x64(input logic [63:0]A, 
		input logic [63:0]B,
		input logic [63:0]C,
		input logic [63:0]D,
		input logic [1:0]sel,
		output logic [63:0]out);

always_comb begin
	case(sel) 
		2'b00: out = A;
		2'b01: out = B;
		2'b10: out = C;
		2'b11: out = D;
		default: out = 64'bx;
	endcase
end

endmodule
