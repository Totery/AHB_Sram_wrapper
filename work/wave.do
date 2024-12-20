onerror {resume}
quietly WaveActivateNextPane {} 0
add wave -noupdate /tb/clk
add wave -noupdate /tb/rstn
add wave -noupdate /tb/hsel
add wave -noupdate /tb/htrans
add wave -noupdate -color Violet -itemcolor Violet /tb/hwrite
add wave -noupdate /tb/haddr
add wave -noupdate /tb/hreadyout
add wave -noupdate -radix hexadecimal /tb/hrdata
add wave -noupdate /tb/u_ahb_ms_model/ahb_rd_burst/ref_word
add wave -noupdate -radix hexadecimal /tb/u_ahb_ms_model/ref_mem0
add wave -noupdate /tb/u_ahb_ms_model/ref_mem1
add wave -noupdate /tb/u_ahb_ms_model/ref_mem2
add wave -noupdate /tb/u_ahb_ms_model/ref_mem3
add wave -noupdate /tb/u_ahb_ms_model/ref_mem4
add wave -noupdate /tb/u_ahb_ms_model/ref_mem5
add wave -noupdate /tb/u_ahb_ms_model/ref_mem6
add wave -noupdate /tb/u_ahb_ms_model/ref_mem7
add wave -noupdate /tb/u_ahb_ms_model/ref_mem8
add wave -noupdate /tb/u_ahb_ms_model/ref_mem9
add wave -noupdate /tb/u_ahb_ms_model/ref_mem10
add wave -noupdate /tb/u_ahb_ms_model/ref_mem11
TreeUpdate [SetDefaultTree]
WaveRestoreCursors {{Cursor 1} {95290 ps} 0}
quietly wave cursor active 1
configure wave -namecolwidth 150
configure wave -valuecolwidth 119
configure wave -justifyvalue left
configure wave -signalnamewidth 1
configure wave -snapdistance 10
configure wave -datasetprefix 0
configure wave -rowmargin 4
configure wave -childrowmargin 2
configure wave -gridoffset 0
configure wave -gridperiod 1
configure wave -griddelta 40
configure wave -timeline 0
configure wave -timelineunits ns
update
WaveRestoreZoom {0 ps} {181490 ps}
