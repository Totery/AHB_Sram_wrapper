module sp_sram_wbe4 #(
	parameter MEM_DEPTH  = 1024,
	parameter DATA_WIDTH = 32,
	parameter ADDR_WIDTH = 10
) (
	input clk_i,
	input rst_n_i,
	input en_i,
	input we_i,
	input [3:0] wbe_i,
	input [ADDR_WIDTH-1:0] addr_i,
	input [DATA_WIDTH-1:0] wdata_i,
	
	output reg [DATA_WIDTH-1:0] rdata_o
);

// Note: in this file we use register file to mimic sram
	reg [DATA_WIDTH-1:0] mem_r [0:MEM_DEPTH-1];

// Sram cannot be initialized by rst_n
	always @(posedge clk_i) begin
		if (en_i) begin
			if (we_i) begin	  // write
				if (wbe_i[0])	mem_r[addr_i][0+:8] <= wdata_i[7:0];		// byte 0 is valid, else the byte isn't written inside
				if (wbe_i[1])	mem_r[addr_i][8+:8] <= wdata_i[15:8];
				if (wbe_i[2])	mem_r[addr_i][16+:8] <= wdata_i[23:16];
				if (wbe_i[3])	mem_r[addr_i][24+:8] <= wdata_i[31:24];
			end
		end
	end

	always @(posedge clk_i or negedge rst_n_i) begin
		if (~rst_n_i)	 rdata_o <= 'b0;
		else if (en_i & ~we_i) begin
			rdata_o <= mem_r[addr_i];
		end
	end

endmodule : sp_sram_wbe4