onerror {resume}
quietly WaveActivateNextPane {} 0
add wave -noupdate -format Literal -radix hexadecimal /gpuchip_sim/pin_red
add wave -noupdate -format Literal -radix hexadecimal /gpuchip_sim/pin_green
add wave -noupdate -format Literal -radix hexadecimal /gpuchip_sim/pin_blue
add wave -noupdate -format Logic /gpuchip_sim/pin_clkin
add wave -noupdate -format Logic /gpuchip_sim/gpu/pin_sclk
add wave -noupdate -format Logic /gpuchip_sim/pin_pushbtn
add wave -noupdate -format Logic /gpuchip_sim/pin_vga_clk
add wave -noupdate -format Logic /gpuchip_sim/pin_vga_blank
add wave -noupdate -format Logic /gpuchip_sim/pin_vga_sync
add wave -noupdate -format Logic /gpuchip_sim/pin_we_n_i
add wave -noupdate -format Literal -radix hexadecimal /gpuchip_sim/pin_saddr_i
add wave -noupdate -format Literal -radix hexadecimal /gpuchip_sim/pin_sdata_i
add wave -noupdate -format Literal -radix unsigned /gpuchip_sim/gpu/u6/drawxsig
add wave -noupdate -format Literal -radix unsigned /gpuchip_sim/gpu/u6/drawysig
add wave -noupdate -format Logic /gpuchip_sim/gpu/u6/eof
add wave -noupdate -format Literal -radix hexadecimal /gpuchip_sim/gpu/vga_address
add wave -noupdate -format Logic /gpuchip_sim/gpu/full
add wave -noupdate -format Logic /gpuchip_sim/gpu/sdram_rd
add wave -noupdate -format Logic /gpuchip_sim/gpu/visible
add wave -noupdate -format Literal -radix unsigned /gpuchip_sim/gpu/u6/fifo_level
add wave -noupdate -format Logic /gpuchip_sim/gpu/u6/fifo/empty
add wave -noupdate -format Logic /gpuchip_sim/gpu/u6/rst
add wave -noupdate -format Logic /gpuchip_sim/gpu/u6/fifo/wr
add wave -noupdate -format Logic /gpuchip_sim/gpu/u6/read_pixel_r
add wave -noupdate -format Literal -radix hexadecimal /gpuchip_sim/gpu/u6/pixel_data_in
add wave -noupdate -format Literal -radix hexadecimal /gpuchip_sim/gpu/u6/pixel_data_out
add wave -noupdate -format Literal -radix hexadecimal /gpuchip_sim/gpu/sdram_hdout
add wave -noupdate -format Literal /gpuchip_sim/gpu/sdram_hdin
add wave -noupdate -format Logic /gpuchip_sim/gpu/sdram_valid
add wave -noupdate -format Logic /gpuchip_sim/gpu/sdram_waitrequest
add wave -noupdate -format Literal -radix hexadecimal /gpuchip_sim/gpu/u2/az_addr
add wave -noupdate -format Logic /gpuchip_sim/gpu/u2/az_rd_n
add wave -noupdate -format Logic /gpuchip_sim/gpu/u2/az_wr_n
add wave -noupdate -format Logic /gpuchip_sim/gpu/u2/clk
add wave -noupdate -format Logic /gpuchip_sim/gpu/u2/clk_en
add wave -noupdate -format Literal -radix hexadecimal /gpuchip_sim/gpu/u2/zs_addr
add wave -noupdate -format Literal /gpuchip_sim/gpu/u2/zs_ba
add wave -noupdate -format Logic /gpuchip_sim/gpu/u2/zs_cke
add wave -noupdate -format Logic /gpuchip_sim/gpu/u2/zs_cs_n
add wave -noupdate -format Literal /gpuchip_sim/gpu/u2/zs_dqm
add wave -noupdate -format Logic /gpuchip_sim/gpu/u2/zs_we_n
TreeUpdate [SetDefaultTree]
WaveRestoreCursors {{Cursor 1} {400530000 ps} 0}
configure wave -namecolwidth 307
configure wave -valuecolwidth 120
configure wave -justifyvalue left
configure wave -signalnamewidth 0
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
WaveRestoreZoom {400478512 ps} {400991216 ps}
