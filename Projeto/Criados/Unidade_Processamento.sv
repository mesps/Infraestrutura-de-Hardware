`timescale 1ps/1ps

module Unidade_Processamento();
logic clk;
logic nrst;
logic reset;
//logic [63:0]OUT;

//mem32
logic WrInst;
logic [63:0]PC;
logic [31:0]wdaddress;
logic [31:0]data;
wire [31:0] q;

//instrucao
logic [4:0]rs1;	//[19..15]
logic [4:0]rs2;	//[24..20]
logic [4:0]WriteRegister; //[11..7]
logic [6:0]opcode; //[6..0]
logic [31:0]instruction; //[31..0]

//banco
logic RegWrite;
logic[64-1:0] datainBanco;
logic[64-1:0] outRR1;
logic[64-1:0] outRR2;
logic[64-1:0] MenorExt;
logic [1:0] selbanco;


//registradores
logic[63:0] outA;
logic[63:0] outB;
logic loadA;
logic loadB;
//logic[63:0] inA;
//logic[63:0] inB;

//mux
logic [63:0]saidaMux1, saidaMux2, Alu, saidamuxgera, saidamuxdesl, saidamuxpc, saidamuxcausa, Address;
logic [1:0]selmux4, selmuxgera, selmuxpc, selmuxmem;
logic selmuxdesl, selmuxcausa;

//ULA
logic [2:0]selULA;
logic Overflow, Negativo, z, Igual, Maior, Menor, selmux2;
logic [63:0]ALUOUT;

//Sign extended
logic [63:0]immExtended;

//UC
logic [5:0]state;
//logic [63:0]PC;

//Data Memory
logic wr;
logic [63:0]MemData;
logic loadRegMemory;
logic [63:0]MDR, MDR2;
logic [63:0]WriteDataMem;

//regPC
logic IRWrite;
logic loadPC;

//regEPC
logic loadEPC;
logic [63:0]EPC;

//regCausa
logic loadCausa;
logic [63:0]saidaCausa;

//shift
logic [1:0]shift;
logic [5:0]qtddeshifts;
logic [63:0]shiftado;

//exceções
logic [63:0]extensaoParaPC;

//PRINCIPAIS MUDANÇAS DE NOMENCLATURA

//saidamuxmem = Address
//BnoBanco = WriteDataMem
//rd = WriteRegister
//WriteDataReg eh o que pode ser escrito no RegMem, mas equivale ao fio MemData (saída da memória de dados)
//RegMemOut = MDR e RegMemOut2 = MDR2
//S = Alu
//rdaddress = PC
//loadMemory = wr
//wrreg = RegWrite
//loadPC = IRWrite (eh o mesmo load para o regPC e para o Registrador de instruções)
//saidaEPC = EPC

UC controle(	.clk(clk),
		.Instruction(instruction),
		.opcode(opcode),
		.WriteRegister(WriteRegister),
		.loadReg1(loadA),
		.loadReg2(loadB),
		.IRWrite(IRWrite),
		.loadPC(loadPC),
		.nrst(nrst), 
		.selmux2(selmux2),
		.selULA(selULA),
		.selmux4(selmux4),
		.Overflow(Overflow),
		.Negativo(Negativo),
		.Igual(Igual),
		.Maior(Maior),
		.Menor(Menor),
		.RegWrite(RegWrite),
		.selmuxbanco(selbanco),
		.loadALU(loadALU), 
		.estado(state), 
		.wr(wr),
		.Shift(shift),
		.N_shifts(qtddeshifts),
		.loadRegMemory(loadRegMemory),
		.MenorExt(MenorExt),
		.selmuxgera(selmuxgera),
		.selmuxdesl(selmuxdesl),
		.outB(outB),
		.WriteDataMem(WriteDataMem),
		.MDR(MDR),
		.MDR2(MDR2),
		.reset(reset),
		.selmuxpc(selmuxpc),
		.selmuxcausa(selmuxcausa),
		.loadCausa(loadCausa),
		.loadEPC(loadEPC),
		.selmuxmem(selmuxmem),
		.extensaoParaPC(extensaoParaPC));

Ula64 ULA( 	.A(saidaMux1), 	
	 	.B(saidaMux2), 
		.Seletor(selULA), 
		.S(Alu), 
		.Overflow(Overflow), 
		.Negativo(Negativo), 
		.z(z), 
		.Igual(Igual), 
		.Maior(Maior), 
		.Menor(Menor));

mux4x64 muxMemInst(.A(64'd254), .B(64'd255), .C(PC), .D(64'dx), .sel(selmuxmem), .out(Address));

mux2x64 muxCausa(.A(64'd0), .B(64'd1), .sel(selmuxcausa), .out(saidamuxcausa));

mux4x64 muxPC(.A(Alu), .B(ALUOUT), .C(shiftado), .D(extensaoParaPC), .sel(selmuxpc), .out(saidamuxpc));

mux2x64 muxdesl(.A(immExtended), .B(outA), .sel(selmuxdesl), .out(saidamuxdesl));

mux4x64 geraC(.A(immExtended), .B(shiftado), .C(PC), .D(64'd4), .sel(selmuxgera), .out(saidamuxgera));

mux4x64 dale4(.A(outB), .B(64'd4), .C(immExtended), .D(shiftado), .sel(selmux4), .out(saidaMux2));

mux2x64 dale2(.A(PC), .B(outA), .sel(selmux2), .out(saidaMux1));

mux4x64 muxbanco(.A(ALUOUT), .B(MDR2), .C(saidamuxgera), .D(MenorExt), .sel(selbanco), .out(datainBanco));

register regPC(.clk(clk), .reset(nrst), .regWrite(loadPC), .DadoIn(saidamuxpc), .DadoOut(PC));

register regEPC(.clk(clk), .reset(nrst), .regWrite(loadEPC), .DadoIn(PC), .DadoOut(EPC));

register regCAUSA(.clk(clk), .reset(nrst), .regWrite(loadCausa), .DadoIn(saidamuxcausa), .DadoOut(saidaCausa));

Memoria32 meminst (.raddress(Address), .waddress(wdaddress),
		.Clk(clk), .Datain(data), .Dataout(q), .Wr(WrInst));

Memoria64 datamem(.raddress(ALUOUT), .waddress(ALUOUT), .Clk(clk), .Datain(WriteDataMem), .Dataout(MemData), .Wr(wr));

Instr_Reg_RISC_V reginstr(.Load_ir(IRWrite), .Reset(reset),
		.Clk(clk), .Entrada(q), .Instr19_15(rs1), .Instr24_20(rs2), .Instr11_7(WriteRegister), .Instr6_0(opcode), .Instr31_0(instruction)); 

bancoReg Banco(.write(RegWrite), .clock(clk), .reset(nrst), .regreader1(rs1), .regreader2(rs2), .regwriteaddress(WriteRegister), .datain(datainBanco), .dataout1(outRR1), .dataout2(outRR2));

register regA(	.clk(clk),
		.reset(nrst), 
		.regWrite(loadA), 
		.DadoIn(outRR1), 
		.DadoOut(outA));

register regB(	.clk(clk), 
		.reset(nrst),
		.regWrite(loadB),
		.DadoIn(outRR2),
		.DadoOut(outB));

register regmemory (	.clk(clk),
			.reset(nrst),
			.regWrite(loadRegMemory),
			.DadoIn(MemData),
			.DadoOut(MDR));

sign_extended signExt(	.Instruction(instruction),
			.opcode(opcode),
			.immExtended(immExtended));

Deslocamento desl(	.Shift(shift),
			.Entrada(saidamuxdesl),
			.N(qtddeshifts),
			.Saida(shiftado));

register ALUOut( .clk(clk),
		 .reset(nrst), 
		 .regWrite(loadALU), 
		 .DadoIn(Alu), 
		 .DadoOut(ALUOUT));

localparam CLKPERIOD = 10000;
localparam CLKDELAY = CLKPERIOD / 2;

initial begin
	clk = 1'b1;
	reset = 1'b1;
	PC=0;
	IRWrite = 1'b1;
	#(CLKPERIOD)
	#(CLKPERIOD)
	#(CLKPERIOD)
	reset = 1'b0;
end

always #(CLKDELAY) clk = ~clk;



endmodule
