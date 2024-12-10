module ahb_sram_wrapper #(
	parameter MEM_DEPTH = 1024,
	parameter DATA_WIDTH = 32,
	parameter ADDR_BITS = 10
) (
	// Global signals
	input 		hclk_i,
	input 		hrst_n_i,
	
	// AHB Master to slave(addr phase)
	input [2:0] hburst_i,
	input 			hmasterlock_i,
	input [3:0] hprot_i,
	input [2:0] hsize_i,
	input [1:0] htrans_i,
	input 			hwrite_i,
	input [3:0] hstrb_i,
	input [ADDR_BITS+1:0] haddr_i,
	
	// AHB master to slave(data phase)
	input [DATA_WIDTH-1:0] hwdata_i,

	// AHB bus decoder to slave
	input				hsel_i,
	// AHB bus mux to slave
	input				hready_i,
	
	// AHB slaves outputs
	output wire [DATA_WIDTH-1:0] hrdata_o,
	output wire	hreadyout_o,
	output wire hresp_o

);

	



endmodule