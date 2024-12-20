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
	input 			hsel_i,
	
	// AHB Bus Mux to slave (data phase)
	input  			hready_i,
	
	// AHB slave outputs
	output wire [DATA_WIDTH-1:0] hrdata_o,
	output reg  hreadyout_o,
	output wire hresp_o,
	
	// Memory interface
	output reg mem_en_o,
	output wire mem_we_o,
	output reg [3:0] mem_wbe_o,
	output reg [ADDR_BITS-1:0] mem_addr_o,
	output wire [DATA_WIDTH-1:0] mem_wdata_o,
	input [DATA_WIDTH-1:0] mem_rdata_i

);
	
	// mem_wdata can be directly fetched by ahb bus 
	assign mem_wdata_o = hwdata_i;
	
	reg [ADDR_BITS-1:0] mem_addr_r;
	
	// haddr should be delayed for one beat and passed to mem_addr during writing
	// if the last beat is write, first beat of reading should also delay haddr
	// otherwise connect haddr_i to mem_addr
	always @(posedge hclk_i or negedge hrst_n_i) begin
		if (~hrst_n_i)	mem_addr_r <= 'b0;
		else 						mem_addr_r <= haddr_i[2+:ADDR_BITS];
	end

	reg hwrite_r, hwrite_2r;
	always @(posedge hclk_i or negedge hrst_n_i) begin
		if (~hrst_n_i) begin
			hwrite_r  <= 1'b0;
			hwrite_2r <= 1'b0;
		end else begin 						
			hwrite_r  <= hwrite_i;
			hwrite_2r <= hwrite_r;
		end	
	end
	
	always @(*) begin
		if (hwrite_r)	mem_addr_o = mem_addr_r;			 // hwrite_r = 1 represents the addr phase is write cmd
		else if (hwrite_2r)	mem_addr_o = mem_addr_r; // hwrite_r = 0, hwrite_2r = 1 represents the current transfer addr phase is read
																							   // but the last beat transfer is write --> write switch to read
		else mem_addr_o = haddr_i[2+:ADDR_BITS];									 // otherwise directly pass haddr_i
	end
	
	// mem_wbe_o is decided by 2 factors: hstrb_i and hsize_i, 
	// if hsize_i = 3'b000 --> write in byte --> in which byte depends on haddr_i[1:0]
	// if hsize_i = 3'b001 --> write in half-word --> in which byte depends on haddr_i[1]
	// the result of hstrb_i and hsize_i should be delayed for 1 cycle and pass to mem_wbe_o
	always @(posedge hclk_i or negedge hrst_n_i) begin
		if (~hrst_n_i)	mem_wbe_o <= 'b0;
		else begin 
		
			case (hsize_i) 
				3'b000: begin		// size is byte, little endian
					
					case (haddr_i[1:0])
						2'b00:	mem_wbe_o <= hstrb_i & 4'b0001;		
						2'b01:	mem_wbe_o <= hstrb_i & 4'b0010;	 
						2'b10:	mem_wbe_o <= hstrb_i & 4'b0100;
						2'b11:	mem_wbe_o <= hstrb_i & 4'b1000;
					endcase
				end
				
				3'b001: begin	 // size is half-word, little endian
						if (~haddr_i[1])	mem_wbe_o <= hstrb_i & 4'b0011;
						else							mem_wbe_o <= hstrb_i & 4'b1100;
				end
				
				default:		mem_wbe_o <= hstrb_i; 
				
			endcase
			
		end
	end	

	// mem_en_o 
	// for writing mem_en_o is simply hsel_r
	// for reading mem_en_o is hsel_i
	// from writing switch to reading, mem_en_o should be 1
	// from reading switch to writing, mem_en_o should be 0 for 1 cycle
	// for r -> w case: hwrite_i = 1 indicates in this cycle you initiate one beat write transfer
	// meanwhile hwrite_r = 0 indicates the last beat transfer is read
	reg hsel_r;
	always @(posedge hclk_i or negedge hrst_n_i) begin
		if (~hrst_n_i)	hsel_r <= 'b0;
		else 						hsel_r <= hsel_i;
	end		
	
	reg [1:0] htrans_r;
	always @(posedge hclk_i or negedge hrst_n_i) begin
		if (~hrst_n_i)	htrans_r <= 2'b0;
		else 						htrans_r <= htrans_i;
	end	
	
	always @(*) begin
		if (hwrite_r)	 			mem_en_o = hsel_r & (htrans_r != 2'b00) & (htrans_r != 2'b01);	// consequtive write and addr htrans is not IDLE/BUSY
		else if (hwrite_2r)	mem_en_o = 1'b1;		// write switch to read
		else if (hwrite_i)	mem_en_o = 1'b0;    // read switch to write
		else 								mem_en_o = hsel_i & (htrans_i != 2'b00) & (htrans_i != 2'b01);	// consequtive read and addr htrans is not IDLE/BUSY
	end

	// mem_we_o
	assign mem_we_o = hwrite_r;
	
	///////////////////////
	// AHB slave output ///
	///////////////////////
	assign hrdata_o = mem_rdata_i;
	assign hresp_o = 1'b0;
	
	// hreadyout_o, except for switch from write to read = 0, otherwise = 1
	always @(*) begin
		if ((~hwrite_r)& hwrite_2r)	hreadyout_o = 1'b0;
		else hreadyout_o = 1'b1;
	end
	
	
endmodule : ahb_inf