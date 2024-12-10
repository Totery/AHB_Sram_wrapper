module ahb_inf #(	
	parameter MEM_DEPTH = 1024,
	parameter DATA_WIDTH = 32,
	parameter ADDR_BITS = 10
)	(
	// Global AHB signals
	input 			hclk_i,
	input   		hrst_n_i,
	
	// AHB Master to slave (addr phase)
	input [2:0] hburst_i,
	input 			hmasterlock_i,
	input	[3:0] hprot_i,
	input [2:0] hsize_i,
	input [1:0] htrans_i,
	input				hwrite_i,
	input [3:0] hstrb_i,
	input	[ADDR_BITS+1:0] haddr_i,
	
	// AHB Master to slave (data phase)
	input [DATA_WIDTH-1:0] hwdata_i,
	
	// AHB Decoder to slave	(addr phase)
	input 			hsel_i
	
	// AHB Bus Mux to slave (data phase)
	input  			hready_i,
	
	// AHB slave outputs
	output wire [DATA_WIDTH-1:0] hrdata_o,
	output wire hreadyout_o,
	output wire hresp_o,
	
	// Memory interface
	output wire mem_en_o,
	output wire mem_we_o,
	output wire [3:0] mem_wbe_o,
	output wire [ADDR_BITS-1:0] mem_addr_o,
	output wire [DATA_WIDTH-1:0] mem_wdata_o,
	input [DATA_WIDTH-1:0] mem_rdata_i

);









endmodule : ahb_inf