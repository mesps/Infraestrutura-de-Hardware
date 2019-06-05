module mux2x64(input logic [63:0]A, input logic [63:0]B, input logic sel, output logic [63:0]out);

always_comb begin
	if(~sel) out = A;
	else out = B;
end

endmodule 
