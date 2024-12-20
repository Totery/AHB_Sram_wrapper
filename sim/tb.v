// by a subsisting licensing agreement from SiliconThink.
//
//      (C) COPYRIGHT SiliconThink Limited or its affiliates
//                   ALL RIGHTS RESERVED
//
// This entire notice must be reproduced on all copies of this file
// and copies of this file may only be made by a person if such person is
// permitted to do so under the terms of a subsisting license agreement
// from SiliconThink or its affiliates.
// ---------------------------------------------------------------------------//

//----------------------------------------------------------------------------//
// File name    : tb.v
// Author       : sky@SiliconThink
// Email        : 
// Project      : 
// Created      : 
// Copyright    : 
// Description  : 
//----------------------------------------------------------------------------//

`timescale 1ns / 10ps

module tb();

parameter	clk_cyc = 10.0;

parameter   mem_depth   = 1024  ;
parameter   mem_abit    = 10    ;
parameter   mem_dw      = 32    ;   //can't change this parameter

reg             clk, rstn   ;

always #(clk_cyc/2.0) clk = ~clk;

initial begin
	clk = 0; rstn = 0;
	@(negedge clk); rstn = 1;
end


//--- connection model and DUT
wire			hsel	;
wire	[(mem_abit+2-1):0] haddr;
wire	[2:0]	hburst	;	//support all burst type
wire	[1:0]	htrans	;   //support htrans type
wire	[2:0]	hsize	;   //support 8/16/32 bit trans
wire	[3:0]	hprot	;   //ignored
wire			hwrite	;	//r/w
wire	[mem_dw-1:0]hwdata;
wire			hready	;
wire			hreadyout;
wire	[31:0]	hrdata	;
wire	hresp	;



ahb_lite_ms_model #(.mem_depth(mem_depth), .mem_abit(mem_abit),
	.mem_dw(mem_dw)) u_ahb_ms_model(

	.hsel		    (hsel		  ),
	.haddr		  (haddr		),
	.hburst	    (hburst	  ),
	.htrans	    (htrans	  ),
	.hsize		  (hsize		),
	.hprot		  (hprot		),
	.hwrite	    (hwrite	  ),
	.hwdata	    (hwdata	  ),
	.hready	    (hready	  ),
	.hreadyout	(hreadyout),
	.hrdata	    (hrdata	  ),
	.hresp		  (hresp		),
                                    
  .clk			  (clk			),
  .rstn			  (rstn			)  
);


ahb_sram_wrapper #(.MEM_DEPTH (mem_depth), .ADDR_BITS (mem_abit), 
	.DATA_WIDTH(mem_dw)) u_ahb_sram(

. hburst_i				(hburst),
. hmasterlock_i		(1'b0),
. hprot_i					(hprot),
. hsize_i				  (hsize),
. htrans_i				(htrans),
. hwrite_i        (hwrite	),
. hstrb_i					(4'b1111),
. haddr_i					(haddr),
. hwdata_i				(hwdata),
. hsel_i					(hsel),
. hready_i				(hready),


. hreadyout_o	    (hreadyout),
. hrdata_o	      (hrdata),
. hresp_o		      (hresp),
                                    
. hclk_i          (clk ),
. hrst_n_i        (rstn)   
);




endmodule

