module UC(input clk, 
		input logic [31:0]Instruction,
		input logic [6:0]opcode,
		input logic [4:0]WriteRegister,
		output logic loadReg1, loadALU, loadCausa, loadEPC,
		output logic loadReg2,
		output logic [63:0]MenorExt, WriteDataMem, MDR2, extensaoParaPC,
		output logic IRWrite, loadPC, nrst, selmux2, RegWrite, wr, loadRegMemory, selmuxdesl, selmuxcausa,
		input logic [63:0] outB, MDR,
		output logic [2:0]selULA,
		output logic [1:0]selmux4, selmuxbanco, selmuxgera, selmuxpc, selmuxmem,
		input logic Overflow, Negativo, Igual, Maior, Menor, reset,
		output logic [5:0]estado,
		output logic [1:0] Shift,
		output logic [5:0] N_shifts);

enum logic [5:0]{reset_fase = 6'b000000, incrementar_pc = 6'b000001, decode_op=6'b000010, excecoes1 = 6'b000011, tipo_R = 6'b000100, tipo_I1 = 6'b000101, 
loads = 6'b000110, tipo_S = 6'b000111, tipo_SB = 6'b001000, continua_SB1 = 6'b001001, getMemory = 6'b001010, salvar_resultado = 6'b001011, store_double = 6'b001100,
store_intermediario2 = 6'b001101, continua_SB2 = 6'b001110, atualizar_pc = 6'b001111, shift_esquerda = 6'b010000, shift_direita = 6'b010001, store_byte = 6'b010010, store_hw = 6'b010011,
store_word = 6'b010100, end_fase = 6'b010101, jal = 6'b010110, jalr = 6'b010111, continua_SB3 = 6'b011000, continua_SB4 = 6'b011001, slti = 6'b011010,
MemToBanco1 = 6'b011011, MemToBanco2 = 6'b011100, AntesDeInc = 6'b011101, store_intermediario = 6'b011110, excecoes2 = 6'b011111, atualiza2 = 6'b100000,
atualiza3 = 6'b100001, esperaDado = 6'b100010, excecoes0 = 6'b100011} state;

logic [63:0]complemento;
//logic reset;
logic [1:0] flag_SB;
logic flag_excecoes;
logic [9:0] funct10;


always_ff@(posedge clk, posedge reset) begin
	if(reset) state <= reset_fase;

	case(state)
		reset_fase: begin		//0
			estado = state;
			IRWrite = 0; //wr do regist. de instrucoes
			loadPC = 1;
			nrst = 1;
			flag_excecoes = 0;
			selmuxmem = 2'b10;
			//state = decode_op;
			state = atualizar_pc;
		end
		incrementar_pc: begin		//1
			flag_excecoes = 0;
			selmuxmem = 2'b10;
			loadCausa = 0;
			loadEPC = 0;
			selmuxcausa = 0;
			selmuxgera = 2'b00;
			selmuxdesl = 0;
			wr = 0;
			RegWrite = 0;
			loadRegMemory = 0;
			estado = state;
			loadALU = 0;
			nrst = 0;
			selmux2 = 1'b0; //PC
			selmux4 = 2'b01; //4
			selULA = 3'b001; //soma
			selmuxpc = 2'b00; //entra S no regPC
			loadPC = 1;
			state = atualizar_pc;
		end
		atualizar_pc: begin		//15
			estado = state;
			loadPC = 0; //estado para concluir atualizacao de PC
			state = atualiza2;
		end
		atualiza2: begin		//32
			estado = state;
			IRWrite = 1; //regist. de instrucoes recebe instrucao q ta no endereco PC
			state = atualiza3;
		end
		atualiza3: begin		//33
			estado = state;
			IRWrite = 0; //estado para concluir a atualizacao do regist. de instrucoes
			if(!flag_excecoes) state = decode_op;
			else state = end_fase;
		end
		decode_op: begin		//2
			selmuxmem = 2'b10;
			estado = state;
			Shift = 2'b00;
			N_shifts = 6'd0;
			loadPC = 0;
			RegWrite = 0;
			IRWrite = 0;
			nrst = 0;
			case(opcode)
				7'b0110011: begin	//Tipo R - add, sub, and, slt - 4
					loadReg1 = 1;
					loadReg2 = 1;
					state = tipo_R;	
				end
				7'b0010011: begin	//Tipo I - addi, shifts, slti, nop
					case(Instruction[14:12])
						3'b000: state = tipo_I1; //addi
						3'b101: state = shift_direita;
						3'b001: state = shift_esquerda;
						3'b010: state = slti;
						//O nop volta a incrementar pc
						default: state = incrementar_pc;
					endcase
					loadReg1 = 1;
				end
				7'b0000011: begin	//Tipo I - lb, lh, lw, ld, lbu, lhu, lwu - 6
					loadReg1 = 1;
					state = loads;	
				end
				7'b1110011: begin	//Tipo I - Break
					state = end_fase;			
				end
				7'b0100011: begin	//Tipo S - sb, sh, sw, sd - 7
					loadReg1 = 1;
					loadReg2 = 1;
					state = tipo_S;
				end
				7'b1100011: begin 	//Tipo SB - beq - 8
					selmuxdesl = 0;
					loadReg1 = 1;
					loadReg2 = 1;
					flag_SB = 2'b00;
					Shift = 2'b00; //shift esq logico
					N_shifts = 6'd2;
					selmux2 = 1'b0; //PC
					selmux4 = 2'b11; //shiftado
					selULA = 3'b001; //soma
					loadALU = 1;
					state = tipo_SB;
				end	
				7'b1100111: begin 	//Tipo SB - bne, jalr, bge, blt
					case(Instruction[14:12])
					3'b000: begin //jalr
						loadReg1 = 1; 
						selmux2 = 0;
						selmuxgera = 2'b10;
						selmuxbanco = 2'b10;
						RegWrite = 1;
						state = jalr; //23
					end
					3'b001: begin //bne
						Shift = 2'b00; //shift esq logico
						N_shifts = 6'd2;
						selmux2 = 1'b0; //PC
						selmux4 = 2'b11; //shiftado
						selULA = 3'b001; //soma
						loadALU = 1;
						loadReg1 = 1;
						loadReg2 = 1;
						flag_SB = 2'b01;
						selmuxdesl = 0;
						state = tipo_SB; //8
					end
					3'b100: begin //blt
						Shift = 2'b00; //shift esq logico
						N_shifts = 6'd2;
						selmux2 = 1'b0; //PC
						selmux4 = 2'b11; //shiftado
						selULA = 3'b001; //soma
						loadALU = 1;
						loadReg1 = 1;
						loadReg2 = 1;
						flag_SB = 2'b10;
						selmuxdesl = 0;
						state = tipo_SB; //8
					end
					3'b101: begin //bge
						Shift = 2'b00; //shift esq logico
						N_shifts = 6'd2;
						selmux2 = 1'b0; //PC
						selmux4 = 2'b11; //shiftado
						selULA = 3'b001; //soma
						loadALU = 1;
						loadReg1 = 1;
						loadReg2 = 1;
						flag_SB = 2'b11;
						selmuxdesl = 0;
						state = tipo_SB; //8
					end
					default: state = incrementar_pc;
					endcase
					
				end
				7'b1101111: begin 	//Tipo UJ - jal
					//escreve o valor de PC em rd
					selmux2 = 0;
					selmuxgera = 2'b10; //PC entra no banco de regist.
					selmuxbanco = 2'b10;
					RegWrite = 1;

					//soma PC + shiftado e carrega na ALUOUT
					Shift = 2'b00; //shift esq logico
					N_shifts = 6'd1;
					selmux2 = 1'b0; //PC
					selmux4 = 2'b11; //shiftado
					selULA = 3'b001; //soma
					loadALU = 1;
					selmuxdesl = 0; //ImmExtended
					state = jal; //22
				end
				7'b0110111: state = salvar_resultado;	//Tipo U
				default: begin
					selmuxcausa = 0; //opcode inexistente
					loadCausa = 1;
					loadEPC = 1;
					selmuxmem = 2'b00; //254
					state = excecoes0;
				end
			endcase
		end

		excecoes0: begin
			estado = state;
			//estado para finalizar a atualizacao da saida da memoria de instrucoes
			IRWrite = 1; //autoriza a atualizacao do registrador de instrucoes
			state = excecoes1;
		end
		
		excecoes1: begin			//3
			estado = state;
			IRWrite = 0;
			loadEPC = 0;
			loadCausa = 0;
			state = excecoes2;
			//estado para finalizar a atualizacao do registrador de instrucoes
		end

		excecoes2: begin			//31
			estado = state;
			extensaoParaPC = {56'd0, Instruction[7:0]};
			flag_excecoes = 1; //chegou a uma excecao
			selmuxpc = 2'b11; //extensaoParaPC
			loadPC = 1;
			state = atualizar_pc;
		end

		tipo_R: begin			//4
			estado = state;
			selmux2 = 1;
			selmux4 = 2'b00;
			funct10 = {Instruction[31:25], Instruction[14:12]};
			case(funct10)
				10'b0000000000: selULA = 3'b001; //add
				10'b0100000000: selULA = 3'b010; //sub
				10'b0000000111: selULA = 3'b011; //AND
				10'b0000000010: selULA = 3'b110; //Ternario(slt)
				default: selULA = 3'b000;
			endcase
			loadALU = 1;
			state = salvar_resultado; 
		end

		tipo_I1: begin			//5
			estado = state;
			selmux2 = 1;
			selmux4 = 2'b10;
			RegWrite = 0;
			selULA = 3'b001;
			loadALU = 1;
			state = salvar_resultado;
		end

		loads: begin 			//6
			estado = state;
			selmux2 = 1; //regA
			selmux4 = 2'b10; //ImmExtended
			RegWrite = 0;
			selULA = 3'b001; //soma
			loadALU = 1;
			//state = getMemory;
			state = esperaDado;
		end
		
		esperaDado: begin
			estado = state;
			state = getMemory;
		end

		getMemory: begin		//10
			estado = state;
			loadRegMemory = 1;
			state = MemToBanco1;
			//state = salvar_resultado;
		end
		
		MemToBanco1: begin		//27
			estado = state;
			loadRegMemory = 0;
			state = MemToBanco2;
			//estado intermediario para carregar o valor em MDR
			//Só no proximo estado podemos igualar MDR2 a (uma parte de) MDR
		end

		MemToBanco2: begin		//28
			estado = state;
			case(Instruction[14:12])
				3'b000: begin 
					if (MDR[7] == 1'b1) MDR2 = {56'b11111111111111111111111111111111111111111111111111111111, MDR[7:0]}; //lb
					else MDR2 = {56'd0, MDR[7:0]};
				end
				3'b001: begin
					if (MDR[15] == 1'b1) MDR2 = {48'b111111111111111111111111111111111111111111111111, MDR[15:0]}; //lh
					else MDR2 = {48'd0, MDR[15:0]};
				end
				3'b010: begin
					if (MDR[31] == 1'b1) MDR2 = {32'b11111111111111111111111111111111, MDR[31:0]}; //lw
					else MDR2 = {32'd0, MDR[31:0]};
				end
				3'b011: MDR2 = MDR; //ld
				3'b100: MDR2 = {56'd0, MDR[7:0]}; //lbu
				3'b101: MDR2 = {48'd0, MDR[15:0]}; //lhu
				3'b110: MDR2 = {32'd0, MDR[31:0]}; //lwu
				default: MDR2 = MDR;
			endcase
			state = salvar_resultado;
		end
		
		tipo_S: begin			//7
			estado = state;
			selmux2 = 1;	//seleciona o rsg 1
			selmux4 = 2'b10;//seleciona o sinal estendido do imm
			RegWrite = 0;	//bloqueia a escrita
			selULA = 3'b001;//seleciona a operaçao de add
			loadALU = 1;	//permite escrita
			state = store_intermediario;
		end
		
		store_intermediario: begin	//30
			loadRegMemory = 1;
			loadALU = 0;
			state = store_intermediario2;
		end

		store_intermediario2: begin	//13
			case(Instruction[14:12])
				3'b000: state = store_byte;
				3'b001: state = store_hw;
				3'b010: state = store_word;
				3'b111: state = store_double;
			endcase
			//estado interemediario para esperar MDR atualizar
		end

		store_byte: begin		//18
			estado = state;
			WriteDataMem = {MDR[63:8], outB[7:0]};
			wr = 1;
			state = incrementar_pc;
		end

		
		store_hw: begin			//19
			estado = state;
			WriteDataMem = {MDR[63:16], outB[15:0]};
			wr = 1;
			state = incrementar_pc;
		end

		store_word: begin		//20
			estado = state;
			WriteDataMem = {MDR[63:32], outB[31:0]};
			wr = 1;
			state = incrementar_pc;
		end

		store_double: begin		//12
			estado = state;
			WriteDataMem = outB;
			wr = 1;
			state = incrementar_pc;
		end
		tipo_SB: begin			//8
			estado = state;
			selmux2 = 1; //regA
			selmux4 = 2'b00; //regB
			selULA = 3'b110; //xor
			loadALU = 0;
			case(flag_SB)
				2'b00: state = continua_SB1; //beq
				2'b01: state = continua_SB2; //bne
				2'b10: state = continua_SB3; //blt
				2'b11: state = continua_SB4; //bge
				default: state = incrementar_pc; 
			endcase
		end
			
		continua_SB1: begin //beq	//9
			estado = state;
			if(Igual) begin
				selmuxpc = 2'b01;
				loadPC = 1;
				state = AntesDeInc;
				//state = atualizar_pc;//
				//state = branch;
			end
			else state = incrementar_pc;
		end
		
		continua_SB2: begin//bne	//14
			estado = state;
			if(!Igual) begin
				selmuxpc = 2'b01;
				loadPC = 1;
				state = AntesDeInc;
				//state = atualizar_pc;
				//state = branch;
			end
			else state = incrementar_pc;
		end
		continua_SB3: begin//blt	//24
			estado = state;
			if(Menor) begin
				selmuxpc = 2'b01;
				loadPC = 1;
				state = AntesDeInc;
				//state = atualizar_pc;
			end
			else state = incrementar_pc;
		end
		continua_SB4: begin//bge	//25
			estado = state;
			if(!Menor) begin
				selmuxpc = 2'b01;
				loadPC = 1;
				state = AntesDeInc;
				//state = atualizar_pc;
			end
			else state = incrementar_pc;
		end
		
		AntesDeInc: begin		//29
			estado = state;
			loadALU = 0;
			loadPC = 0;
			if(opcode == 7'b1100111 && Instruction[14:12] == 3'b000) state = atualiza2; //jalr
			else state = incrementar_pc; //outros desvios
		end

		shift_direita: begin 		//17
			estado = state;
			if(Instruction[31:26] == 6'b000000) Shift = 2'b01; //srli
			else Shift = 2'b10; //srai
			N_shifts = Instruction[25:20];
			selmuxgera = 2'b01;
			selmuxdesl = 1;
			state = salvar_resultado;
		end

		shift_esquerda: begin 		//16
			estado = state;
			Shift = 2'b00;//slli
			N_shifts = Instruction[25:20];
			selmuxgera = 2'b01;
			selmuxdesl = 1;
			state = salvar_resultado;
		end
		
		slti: begin			//26
			estado = state;
			selmux2 = 1; //regA
			selmux4 = 2'b10; //ImmExtended
			selULA = 3'b110; // menor que
			loadALU = 1; //Atualiza o Menor
			state = salvar_resultado;
		end

		jal: begin 			//22
			estado = state;
			RegWrite = 0;
			loadALU = 0; //ALUOUT eh atualizada com o PC+shiftado
			selmuxpc = 2'b01; //ALUOUT
			loadPC = 1; //PC recebe a ALUOUT
			state = AntesDeInc;
		end
		jalr: begin			//23
			estado = state;
			RegWrite = 0;
			selmux2 = 1; //regA
			selmux4 = 2'b10; //immExtended
			selULA = 3'b001; //soma
			//loadALU = 1;	
			selmuxpc = 2'b00;
			loadPC = 1;
			state = AntesDeInc;
			//state = atualizar_pc;
		end
		salvar_resultado: begin		//11
			estado = state;
			state = incrementar_pc;
			if(Overflow) begin
				selmuxcausa = 1; //overflow
				loadCausa = 1;
				loadEPC = 1;
				selmuxmem = 2'b01; //255
				IRWrite = 1;
				state = excecoes1;
			end else begin
				case(opcode)
					7'b0000011: selmuxbanco = 2'b01; 	//tipo I loads
					7'b0110011: begin			//tipo R
						if(Instruction[14:12]==3'b010) begin
							selmuxbanco = 2'b11;
							MenorExt = {63'd0, Menor};
						end
						else selmuxbanco = 2'b00;
					end
					7'b0110111: begin 			//tipo U
						selmuxbanco = 2'b10;
						selmuxgera = 2'b00;
					end
					7'b0010011: begin 			//tipo I - addi/shifts/slti
						case(Instruction[14:12])
							3'b000: selmuxbanco = 2'b00;//addi
							3'b010: begin //slti
								selmuxbanco = 2'b11; //MenorExt
								MenorExt = {63'd0, Menor};
							end
							default: selmuxbanco = 2'b10;
						endcase
					end
					default: selmuxbanco = 2'b00; //addi
				endcase
				RegWrite = 1;
			end
		end
		end_fase:
			$stop;
		default: state = reset_fase;
			 
	endcase
end

endmodule
