//----------------------------------------------------------------------------//
// File name    : ahb_lite_ms_model.v
// Author       : Jialing
// Email        : davidluistoter@outlook.com
// Project      :
// Created      : 
// Copyright    : 
//
// Description  : 
// 1: ahb-lite master model.
// 2: support idle/busy/nonseq/seq htrans; 8b/16b/32b hsize;
// 3: doesn't check for hresp.
//----------------------------------------------------------------------------//
`timescale 1ns / 10ps
`define	MEM_PATH	tb.u_ahb_sram.u_sram
`define EN_BAKC2BACK

module ahb_lite_ms_model(
	// Model AHB_Lite bus, output ahb ctrl and wdata signals(stimulus)
	// Receive slave response and rdata
	// Auto judge if behavior is incorrect
	hsel			,
	haddr			,
	hburst			,
	htrans			,
	hsize			,
	hprot			,
	hwrite			,
	hwdata			,
	hready			,
	hreadyout		,
	hrdata			,
	hresp			,

    clk				,
    rstn			 
);


parameter   mem_depth   = 1024  ;
parameter   mem_abit    = 10    ;
parameter   mem_dw      = 32    ; 


input   wire					clk, rstn	;

output	reg					hsel		;					// output of ahb bus decoder
output	reg	[11:0]	haddr		;
output	reg	[2:0]	  hburst		;
output	reg	[1:0]	  htrans		;
output	reg	[2:0]	  hsize		;
output	wire [3:0]	hprot		;
output	reg			    hwrite		;	
output	wire	[31:0]hwdata		;
output	wire		    hready		;				// output of ahb bus mux

input	wire			      hreadyout	;
input	wire	[31:0]	  hrdata		;
input	wire				    hresp		;


reg     [7:0]   ref_mem [0 : (mem_depth*4) - 1];  // mem_r of slave has mem_depth words --> here separate words into 4 bytes
																									// to verify bytewise write function

reg     [4:0]   bt_wait     ;




// In real examples, hready is the mux-chosen hreadyout based on decoder result
// because in out exercise, we only have one slave(one hreadyout), so hready = hreadyout 
assign hready	= hreadyout;

// We do not include hprot function for the slave device, 
// so hprot stimulus is set as recommended default value: 4'b1110
assign	hprot		= 4'b1110;

// stimulus(outputs) change should not happen at the rising edge of clk
// we should disallign the stimulus 
// wire	[31:0]	hrdata_d	;



reg		[31:0]	rand0		;
reg		[31:0]	rand1		;
reg		[31:0]	rand2		;
reg   [31:0]  rand3   ;
reg		[7:0]	  wait_cnt	;
integer       test_cnt	;
reg		[31:0]	addr		;
reg   [31:0]  hwdata_pre  ;               //1T pre of hwdata

//--- burst info
reg     skip_info_gen;
reg     [mem_abit+2-1:0]    bt_addr;        //byte addr

reg     [1:0]   bt_size     ;               // 0: byte  1: half-word  2:word
																					  // directly assign to hsize 
																						
reg     [4:0]   bt_len      ;								// burst length info, decides which value the hburst should have
																						// the correlationship between bt_len and hburst is listed below
																						
reg             bt_wrap_flag;			          // 0: incr burst  1:wrap burst
reg     [31:0]  bt_end_addr ;               // The final address after burst transfer, use to decide if the burst 
																						// transfer cross the 1KB boundary
																						
reg     [mem_abit+2-1:0]    bt_addr_array [0:15];  // store all the addr of a burst
																									 // because fixed-length burst maximum 16 beats, so here bt_addr_array[0:15]
	
reg     [mem_abit+2-1:0]    inc_bt_addr ;		// the increasing address for every beat transfer

reg     [2:0]   addr_step   ;							  // decided by bt_size

reg     [2:0]   addr_wrap_bloc;
/* reg     [4:0]   addr_lcnt   ; */
integer         acnt        ;
integer         rcnt        ;
integer         wcnt        ;


// bt_addr_array records each beat transfer address(inc_bt_addr)

// This task generates burst information --> no sim time forward
// 1. hsize decided by rand1[7:0] (bt_size)
// 2. hburst decided by rand1[15:8] bt_len(butst length) and bt_wrap_flag(wrap or incr)
// 3. calculation of allignment bit addr_wrap_bloc --> incr: 1KB block --> mem_addr[7:0] allign
// 																	 									 wrap: $clog2(2^hsize * bt_len) allign
// 4. burst starting address bt_addr generates(random), and allign according to hsize
// 5. burst end address bt_end_addr calculation, exceed 1kB check 
// 		--> if exceed, reset start address bt_addr to the value that just reach the boundary
// 6. Able to deal the case that when wrap exceeds boundary, how to set next step address
// 7. record each beat address in array bt_addr_array for debug purpose

task bt_info_gen;
reg     [31:0]  addr_mask;
begin
    rand1   = $random();
    if(rand1[7:0] <= 128)
        bt_size = 'd2;
    else
        bt_size = {1'b0, rand1[5]};

    addr_step   = 2**bt_size;				// byte: 0 --> addr_step + 2^0=1
																		// half-word: 1 --> addr_step + 2^1=2
																		// word: 2 --> addr_step + 2^2=4
																		
    if(rand1[15:8] <= (128 + 64 + 32))   
		//4/8/16  
		 begin
        case(rand1[11:10])
            'd0:    bt_len  = 'd4;
            'd1:    bt_len  = 'd8;
            default:bt_len  = 'd16; 
        endcase

        bt_wrap_flag = rand1[9];
    end else begin	
        if(rand1[15:8] <= (128 + 64 + 32 + 16)) //single: 7'b111 0000 ~ 7'b1111 000
            bt_len = 1;
        else
            bt_len = rand1[12:9];               //incr: 7'b1111 111 ~ 7'b1111 001

        bt_wrap_flag = 1'b0;
    end

    if(bt_wrap_flag)
        addr_wrap_bloc = bt_size + $clog2(bt_len); // block bytes volume: 2^bt_size * bt_len --> means mem_addr from  
																									 // $clog2(2^bt_size * bt_len) = bt_size + $clog2(bt_len) should not change
    else
        addr_wrap_bloc = 10;                        // when not wrap, the block should not exceed 1KB, means bt_addr from 10th bit cannot change
																										// we will not use this value in fact

		// burst start addr should be alligned with size
    bt_addr = $random();
    if(bt_size == 1)
        bt_addr[0] = 1'b0;	// half-word: addr[0] = 0
    else if(bt_size == 2)
        bt_addr[1:0] = 2'd0;  // word: addr[1:0] = 0

    //1K boundary check --> incr transfer now impossible to exceed boundary
    bt_end_addr = bt_addr + addr_step*bt_len;
    if((bt_end_addr[10] != bt_addr[10]) && (bt_end_addr[9:0] != 'd0))  begin //corss 1KB boundary
        bt_addr = {bt_end_addr[mem_abit+2-1 : 10], 10'h0} - addr_step * bt_len;			// new start addr, so that exactly reach the boundary
    end

    inc_bt_addr = bt_addr;
    /* addr_lcnt   = 0; */
    bt_addr_array[0] = bt_addr;
    
    for(acnt=1; acnt<bt_len; acnt=acnt+1) begin
        inc_bt_addr = inc_bt_addr + addr_step;								// update current beat address 

        if((inc_bt_addr[addr_wrap_bloc] != bt_addr[addr_wrap_bloc]) && bt_wrap_flag) begin // exceed wrap boundary
            // when wrap exceeds the boundary, the behavior should be, inc_by_addr[addr_wrap_back-1:0] return to 'b0
						// inc_by_addr[addr_wrap_back] should remain the same value, following codes realize this behavior
						addr_mask   = ~( (1<<addr_wrap_bloc)-1 );         //  addr_mask = {1'b1, {(addr_wrap_back)'(1'b0)}}
            inc_bt_addr = bt_addr & addr_mask;								// inc_by_addr becomes the first beat of this block
 //           addr_lcnt   = 1;
        end 
			  bt_addr_array[acnt] = inc_bt_addr;			// for debug purpose(see above)
/* 				else begin
            addr_lcnt   = addr_lcnt + 'd1;
        end */

    end

end
endtask

always @(*) begin
    hsize = {1'b0, bt_size};

		if(bt_len== 4)					// corresponds incr4(3'b011) or wrap4(3'b010) notice: bit[0] is the inverse of bt_wrap_flag
			hburst = {2'b01, ~bt_wrap_flag};
    else if(bt_len == 8)
			hburst = {2'b10, ~bt_wrap_flag};
		else if(bt_len == 16)
			hburst = {2'b11, ~bt_wrap_flag};
		else if(bt_len == 1)
			hburst = 'd0;
		else										// other length corresponds to not-fixed length transfer
			hburst = 3'h1;
end

// This task simulates the case that master gives BUSY htrans
// rand3 decides if the current beat master is BUSY 
// rand2 decides if the current beat master is BUSY, how many cycles BUSY should last

task bt_busy_trans;
reg             master_busy    ;
reg     [2:0]   busy_cyc    ;
begin
    rand3 = $random() % 15;
    rand2 = $random() % 128;
    if(rand3[3:0] >= 12) begin
        master_busy = 1;
        
        if(rand2[2:0] <= 4)
            busy_cyc = 1;
        else if(rand2[2:0] == (4+1))
            busy_cyc = 2;
        else if(rand2[2:0] == 6)
            busy_cyc = 3;
        else
            busy_cyc = {1'b1, rand2[6:5]};
						
    end else begin
        master_busy = 0;
    end

    if(master_busy) begin
        while(busy_cyc != 0) begin
            htrans = 'd1;
            @(negedge clk);
						
          while(!hready) begin		
						@(negedge clk);					// Because if hready == 0, addr phase signal including(htrans) should retain
																		// in other words, last cycles should not decrease, AHB protocol requires, 
					end												// If address phase htrans = IDLE/BUSY, corresponding data phase hready must be high
            busy_cyc = busy_cyc - 1;
        end
    end

end
endtask


// This task simulates the burst read transaction process
// each rcnt loop represents one beat of the burst, call bt_busy_trans task to insert additional BUSY cycles duting the butst
// Because SRAM does not support byte read, each read is word-length, so the reference rd_data is also word-length
task ahb_rd_burst;
//reg     [31:0]  ref_word[0:15];
reg 		[31:0]  ref_word;
reg     [mem_abit+2-1:0]  ref_addr;
//reg     [31:0]  tmp_data;

begin
    repeat(bt_wait) @(negedge clk);

    //--- generate burst info
    if(!skip_info_gen)
        bt_info_gen;				// call task bt_info_gen(hburst, hsize)

    hwrite = 1'b0;
    //--- send out each beat
	for(rcnt=0; rcnt< bt_len; rcnt=rcnt+1) begin

        haddr = bt_addr_array[rcnt];

        if(rcnt != 0) begin				
            //--- insert busy trans(busy does not count in rcnt: additional BUSY cycles)
            bt_busy_trans;							
        end

				if(rcnt == 0)
					htrans = 2'h2;		// First beat transfer should always be NONSEQ
				else begin
					htrans = 2'h3;
				end
    		
				@(posedge clk);
				#0.1;			// To ensure the rd_data in data phase already comes out
				
				while(!hready) begin
					@(negedge clk);			
				end

        // always check in word (4 bytes)
        ref_addr = {haddr[mem_abit+2-1:2], 2'b0};		// The corresponding mem_addr
				       
			  // The reference 
        ref_word[8*0 +: 8] = ref_mem[ref_addr + 0]; 	// byte
        ref_word[8*1 +: 8] = ref_mem[ref_addr + 1];
        ref_word[8*2 +: 8] = ref_mem[ref_addr + 2];
        ref_word[8*3 +: 8] = ref_mem[ref_addr + 3];
				
				if (ref_word != hrdata) begin
					$display("Error: AHB read error at %8x: dut_word is %8x, should be %8x.", haddr, hrdata, ref_word);
					repeat(2) @(negedge clk);
					$finish();
				end
				
				@(negedge clk);
	end
	
	htrans = 2'h0;
end
endtask

// This task simulates the write burst transaction
// Compared to read burst, here needs an additional step which is generating 2**(bt_size) * bt_len bytes write data
// Each wcnt loop represents one beat of the burst, because hwdata is word-length [31:0], for hsize byte and half-word,
// We should put valid data in the correct byte lane following little-endian
// At last of this task, we copy the used write data into ref_mem, to verify if the data are successfully written into the SRAM
task ahb_write_burst;
reg     [2:0]   bcnt    ;   // byte counter
reg     [31:0]  waddr   ;
reg     [7:0]   bt_wdata[0 : (16*4-1)];		// 64 bytes 因为最多16 beats transfer * 4 bytes = 64 bytes
reg     [31:0]  bus_addr_align;
reg     [7:0]   bus_wr_word[0:3];
integer         wdata_index;
reg     [1:0]   byte_sf ;
begin

    repeat(bt_wait) @(negedge clk);
    //--- generate burst info
    if(!skip_info_gen)
        bt_info_gen;

    hwrite = 1'b1;
		
    //-- generate wdata of the whole burst
    wdata_index = 0;
    for(wcnt=0; wcnt< bt_len; wcnt=wcnt+1) begin	 // bt_len beats transfer
        for(bcnt=0; bcnt<(2**bt_size); bcnt=bcnt+1) begin // each beat may contain multiple bytes
            bt_wdata[wdata_index] = $random();
            wdata_index = wdata_index + 1;
        end
    end

    // Send out each beat
    wdata_index = 0;
		for(wcnt=0; wcnt< bt_len; wcnt=wcnt+1) begin
					
					haddr = bt_addr_array[wcnt];  // Each beat address generation
					
					// Each beat wdata generation
					for(bcnt=0; bcnt<(2**bt_size); bcnt=bcnt+1) begin
							bus_wr_word[bcnt] = bt_wdata[wdata_index];
							wdata_index = wdata_index + 1;
					end

					// Because hwdata is word-length, we should put the valid data in the right byte lane(little-endian)
					case(bt_size)
					'd0:    begin
											case(bt_addr_array[wcnt][1:0])
											'd0:    hwdata_pre = {24'hf0f0f0, bus_wr_word[0]};
											'd1:    hwdata_pre = {16'hf0f0, bus_wr_word[0], 8'hf0};
											'd2:    hwdata_pre = {8'hf0, bus_wr_word[0], 16'h0};
											'd3:    hwdata_pre = {bus_wr_word[0], 24'h0};
											endcase
									end

					'd1:    begin
											if(bt_addr_array[wcnt][1])
													hwdata_pre = {bus_wr_word[1], bus_wr_word[0], 16'h0f0f};
											else
													hwdata_pre = {16'h0f0f, bus_wr_word[1], bus_wr_word[0]};
									end

					default:begin
											hwdata_pre = {bus_wr_word[3], bus_wr_word[2], bus_wr_word[1], bus_wr_word[0]};
									end
					endcase


					if((wcnt != 0)) begin
							//--- insert busy trans
							bt_busy_trans;
					end

					if(wcnt == 0)
						htrans = 2'h2;
					else
						htrans = 2'h3;
					
					@(negedge clk);
					
					while(!hready) begin
						@(negedge clk);
					end
    
		end

    // copy the write data into ref_mem, used to verify if the data are successfully written into the SRAM
		wdata_index = 0;
		
		for (wcnt = 0; wcnt < bt_len; wcnt = wcnt + 1) begin
			waddr = bt_addr_array[wcnt];
			
			for (bcnt = 0; bcnt < 2**(bt_size); bcnt = bcnt + 1) begin
				ref_mem[waddr + bcnt] = bt_wdata[wdata_index];
				wdata_index = wdata_index + 1;
			end

		end
		
    htrans = 2'h0;
end
endtask

// Note: for write burst, hwdata_pre should be delayed for 1 cycle

assign #10 hwdata = hwdata_pre; 


// This task is used to check if the wdata are successfully written inside the SRAM
// Here we verify every element of mem_r (1024), because we might not write in some of the elements
// those never-written elements should be initial values
task mem_content_chk;
	reg [mem_abit:0]  cnt ;
	reg [7:0]   ref_byte[0:3];
	reg [31:0]  ref_word ;
	reg [31:0]  dut_word ;

	begin
			for(cnt = 0; cnt < mem_depth; cnt = cnt + 1) begin
					ref_byte[0] = ref_mem[(cnt<<2) + 0];
					ref_byte[1] = ref_mem[(cnt<<2) + 1];
					ref_byte[2] = ref_mem[(cnt<<2) + 2];
					ref_byte[3] = ref_mem[(cnt<<2) + 3];

					ref_word = {ref_byte[3], ref_byte[2], ref_byte[1], ref_byte[0]};
					dut_word = `MEM_PATH.mem_r[cnt];

					
					if(ref_word !== dut_word) begin
							$display("Error: AHB SRAM content error at %8x: dut_word is %8x, should be %8x.", (cnt<<2), dut_word, ref_word);
							repeat(2) @(posedge clk);
							$finish();
					end
			end
	end
	
endtask



//--- 2: send out AHB burst ---//
reg		[mem_abit:0]	ini_addr	;
reg		[31:0]	ini_data	;
integer         l0, l1      ;
reg     [31:0]  addr_wrap_back;
reg     [15:0]  rw_rand     ;
wire    [31:0]  max_test    ;

assign  max_test = (1<<14);

initial begin
    bt_wait = 'd1;
		hsel	= 1'b0;
		haddr	= 32'h0;
		hburst= 3'h0;
		htrans= 2'h0;
		hwrite = 1'b0;
		@(posedge rstn);
		hsel	= 1'b1;
    //--- initial SRAM with random value
		// Also initial the ref_mem value
	for(ini_addr = 0; ini_addr < mem_depth; ini_addr = ini_addr+1) begin
			ini_data    = $random();
			`MEM_PATH.mem_r[ini_addr] = ini_data;
			ref_mem[(ini_addr << 2) + 0] = ini_data[8*0 +: 8];
			ref_mem[(ini_addr << 2) + 1] = ini_data[8*1 +: 8];
			ref_mem[(ini_addr << 2) + 2] = ini_data[8*2 +: 8];
			ref_mem[(ini_addr << 2) + 3] = ini_data[8*3 +: 8];
			
	end
	$display("initialization of SRAM and reference memory finishes");
	
	repeat(2) @(posedge clk);
	
		// Manually set burst information, for boundary address check
    skip_info_gen = 1;

    // 8 beats, word-length burst, start from address 0
    bt_addr = 0; bt_size = 2; bt_len = 8; bt_wrap_flag = 0;						
    for(l0 =0; l0<bt_len; l0=l0+1) begin
        bt_addr_array[l0] = bt_addr + (2**bt_size) *l0;
    end
    
		ahb_rd_burst;
    ahb_write_burst;

    //-- t1: addr = max r/w
    bt_addr = (mem_depth-1)*4; bt_size = 2; bt_len = 16; bt_wrap_flag = 1;
    //-- beat_0
    bt_addr_array[0] = bt_addr;
    addr_wrap_back = (mem_depth - bt_len)*4;

    //-- beat_1~15
    for(l0 =0; l0<(bt_len-1); l0=l0+1) begin
        bt_addr_array[l0+1] = addr_wrap_back + 4*l0;
    end

    ahb_rd_burst;
    ahb_write_burst;
		
		// Random checks
    skip_info_gen = 0;

    for(test_cnt=0; test_cnt< max_test; test_cnt=test_cnt + 1) begin
        rw_rand = $random();

        if(rw_rand[15:8] < 64)
            bt_wait = 'd0;
        else if(rw_rand[15:8] < (64 + 16))
            bt_wait = 'd1;
        else if(rw_rand[15:8] < (64 + 16 + 16))
            bt_wait = 'd2;
        else if(rw_rand[15:8] < (64 + 16 + 16 + 16))
            bt_wait = 'd3;
        else if(rw_rand[15:8] < (64 + 16 + 16 + 16 + 8))
            bt_wait = 'd4;
        else
            bt_wait = rw_rand[4:0];

        `ifndef  EN_BAKC2BACK
        if(bt_wait == 0)
            bt_wait = 1;
        `endif
        

        if(test_cnt < (max_test >> 1)) begin    //read dominate
            if(rw_rand[5:0] < 48)
                ahb_rd_burst;
            else
                ahb_write_burst;
        end else begin                          //wirte dominate
            if(rw_rand[5:0] >= 16)
                ahb_write_burst;
            else
                ahb_rd_burst;
        end
    end

    mem_content_chk;


		repeat(20) @(posedge clk);
		
    $display("OK: sim pass.");
    $finish();
end

wire    [7:0]   ref_mem0    ;
wire    [7:0]   ref_mem1    ;
wire    [7:0]   ref_mem2    ;
wire    [7:0]   ref_mem3    ;
wire    [7:0]   ref_mem4    ;
wire    [7:0]   ref_mem5    ;
wire    [7:0]   ref_mem6    ;
wire    [7:0]   ref_mem7    ;
wire    [7:0]   ref_mem8    ;
wire    [7:0]   ref_mem9    ;
wire    [7:0]   ref_mem10   ;
wire    [7:0]   ref_mem11   ;



assign  ref_mem0 = ref_mem[0];
assign  ref_mem1 = ref_mem[1];
assign  ref_mem2 = ref_mem[2];
assign  ref_mem3 = ref_mem[3];
assign  ref_mem4 = ref_mem[4];
assign  ref_mem5 = ref_mem[5];
assign  ref_mem6 = ref_mem[6];
assign  ref_mem7 = ref_mem[7];
assign  ref_mem8 = ref_mem[8];
assign  ref_mem9 = ref_mem[9];
assign  ref_mem10= ref_mem[10];
assign  ref_mem11= ref_mem[11];

endmodule

