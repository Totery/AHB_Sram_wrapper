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

	// connection signals
	wire mem_en_s, mem_we_s;
	wire [3:0] mem_wbe_s;
	wire [ADDR_BITS-1:0] mem_addr_s;
	wire [DATA_WIDTH-1:0] mem_wdata_s, mem_rdata_s;
	
	ahb_inf #(.MEM_DEPTH(MEM_DEPTH), .DATA_WIDTH(DATA_WIDTH), .ADDR_BITS(ADDR_BITS))
		u_inf (
			.hclk_i			        (hclk_i),
			.hrst_n_i		        (hrst_n_i),
			.hburst_i						(hburst_i),
			.hmasterlock_i			(hburst_i),
			.hprot_i						(hprot_i),
			.hsize_i						(hsize_i),
			.htrans_i						(htrans_i),
			.hwrite_i						(hwrite_i),
			.hstrb_i						(hstrb_i),
			.haddr_i						(haddr_i),
			.hwdata_i						(hwdata_i),
			.hsel_i							(hsel_i),
			.hready_i						(hready_i),
			
			.hrdata_o						(hrdata_o),
			.hreadyout_o				(hreadyout_o),
			.hresp_o						(hresp_o),
			
			.mem_en_o						(mem_en_s),
			.mem_we_o						(mem_we_s),
			.mem_wbe_o					(mem_wbe_s),
			.mem_addr_o					(mem_addr_s),
			.mem_wdata_o				(mem_wdata_s),
			
			.mem_rdata_i				(mem_rdata_s)
		);

	sp_sram_wbe4 #(.MEM_DEPTH(MEM_DEPTH), .DATA_WIDTH(DATA_WIDTH), .ADDR_BITS(ADDR_BITS))
		u_sram (
		  .clk_i							(hclk_i),
		  .rst_n_i						(hrst_n_i),
		  .en_i								(mem_en_s),
		  .we_i								(mem_we_s),
		  .wbe_i							(mem_wbe_s),
		  .addr_i 						(mem_addr_s),
      .wdata_i						(mem_wdata_s),
		  .rdata_o						(mem_rdata_s)
		);
endmodule