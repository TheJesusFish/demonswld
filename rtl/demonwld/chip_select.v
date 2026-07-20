//

module chip_select
(
    input [23:0] cpu_a,
    input        cpu_as_n,

    input [15:0] z80_addr,
    input        MREQ_n,
    input        IORQ_n,

    // M68K selects
    output reg   prog_rom_cs,
    output reg   ram_cs,
    output reg   scroll_ofs_x_cs,
    output reg   scroll_ofs_y_cs,
    output reg   frame_done_cs,
    output reg   int_en_cs,
    output reg   crtc_cs,
    output reg   tile_ofs_cs,
    output reg   tile_attr_cs,
    output reg   tile_num_cs,
    output reg   scroll_cs,
    output reg   shared_ram_cs,
    output reg   vblank_cs,
    output reg   tile_palette_cs,
    output reg   bcu_flip_cs,
    output reg   sprite_palette_cs,
    output reg   sprite_ofs_cs,
    output reg   sprite_cs,
    output reg   sprite_size_cs,
    output reg   sprite_ram_cs,
    output reg   fcu_flip_cs,
    output reg   reset_z80_cs,
    output reg   dsp_ctrl_cs,
    output reg   dsp_addr_cs,
    output reg   dsp_r_cs,
    output reg   dsp_bio_cs,

    // Z80 selects
    output reg   z80_p1_cs,
    output reg   z80_p2_cs,
    output reg   z80_dswa_cs,
    output reg   z80_dswb_cs,
    output reg   z80_system_cs,
    output reg   z80_tjump_cs,
    output reg   z80_sound0_cs,
    output reg   z80_sound1_cs,

    // other params
    output reg [15:0] scroll_y_offset
);

function m68k_cs;
        input [23:0] start_address;
        input [23:0] end_address;
begin
    m68k_cs = ( cpu_a[23:0] >= start_address && cpu_a[23:0] <= end_address) & !cpu_as_n;
end
endfunction

function z80_cs;
        input [7:0] address_lo;
begin
    z80_cs = ( IORQ_n == 0 && z80_addr[7:0] == address_lo );
end
endfunction

always @ (*) begin

    scroll_y_offset = 16'd16;

    prog_rom_cs       = m68k_cs( 24'h000000, 24'h03ffff );
    ram_cs            = m68k_cs( 24'hc00000, 24'hc03fff );

    scroll_ofs_x_cs   = m68k_cs( 24'he00000, 24'he00001 );
    scroll_ofs_y_cs   = m68k_cs( 24'he00002, 24'he00003 );
    fcu_flip_cs       = m68k_cs( 24'he00006, 24'he00007 );

    vblank_cs         = m68k_cs( 24'h400000, 24'h400001 );
    int_en_cs         = m68k_cs( 24'h400002, 24'h400003 );
    crtc_cs           = m68k_cs( 24'h400008, 24'h40000f );

    tile_palette_cs   = m68k_cs( 24'h404000, 24'h4047ff );
    sprite_palette_cs = m68k_cs( 24'h406000, 24'h4067ff );

    shared_ram_cs     = m68k_cs( 24'h600000, 24'h600fff );

    bcu_flip_cs       = m68k_cs( 24'h800000, 24'h800001 );
    tile_ofs_cs       = m68k_cs( 24'h800002, 24'h800003 );
    tile_attr_cs      = m68k_cs( 24'h800004, 24'h800005 );
    tile_num_cs       = m68k_cs( 24'h800006, 24'h800006 );
    scroll_cs         = m68k_cs( 24'h800010, 24'h80001f );

    frame_done_cs     = m68k_cs( 24'ha00000, 24'ha00001 );
    sprite_ofs_cs     = m68k_cs( 24'ha00002, 24'ha00003 );
    sprite_cs         = m68k_cs( 24'ha00004, 24'ha00005 );
    sprite_size_cs    = m68k_cs( 24'ha00006, 24'ha00007 );
    sprite_ram_cs     = 1'b0;

    reset_z80_cs      = m68k_cs( 24'he00008, 24'he00009 );

    dsp_ctrl_cs       = m68k_cs( 24'he0000a, 24'he0000b );
    //dsp_addr_cs       = m68k_cs( 4'h0 );
    //dsp_r_cs          = m68k_cs( 4'h1 );
    //dsp_bio_cs        = m68k_cs( 4'h3 );
    dsp_addr_cs       = 1'b0;
    dsp_r_cs          = 1'b0;
    dsp_bio_cs        = 1'b0;

    z80_p1_cs         = z80_cs( 8'h80 );
    z80_p2_cs         = z80_cs( 8'hc0 );
    z80_dswa_cs       = z80_cs( 8'he0 );
    z80_dswb_cs       = z80_cs( 8'ha0 );
    z80_system_cs     = z80_cs( 8'h60 );
    z80_tjump_cs      = z80_cs( 8'h20 );
    z80_sound0_cs     = z80_cs( 8'h00 );
    z80_sound1_cs     = z80_cs( 8'h01 );
end

endmodule
