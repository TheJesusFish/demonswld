`default_nettype none

module rom_controller
(
    input reset,
    input clk,

    input         prog_rom_cs,
    input         prog_rom_oe,
    input  [23:1] prog_rom_addr,
    output [15:0] prog_rom_data,
    output        prog_rom_data_valid,

    input         tile_rom_cs,
    input         tile_rom_oe,
    input  [17:0] tile_rom_addr,
    output [31:0] tile_rom_data,
    output        tile_rom_data_valid,

    input         sprite_rom_cs,
    input         sprite_rom_oe,
    input  [17:0] sprite_rom_addr,
    output [31:0] sprite_rom_data,
    output        sprite_rom_data_valid,

    input         sound_rom_1_cs,
    input         sound_rom_1_oe,
    input  [15:0] sound_rom_1_addr,
    output [7:0]  sound_rom_1_data,
    output        sound_rom_1_data_valid,

    input [26:0] ioctl_addr,
    input [7:0]  ioctl_data,
    input [15:0] ioctl_index,
    input        ioctl_wr,
    input        ioctl_download,
    output       download_wait,

    output reg [22:0] sdram_addr,
    output reg [31:0] sdram_data,
    output reg        sdram_we,
    output reg        sdram_req,
    input             sdram_ack,
    input             sdram_valid,
    input      [31:0] sdram_q
);

localparam NONE        = 3'd0;
localparam PROG_ROM    = 3'd1;
localparam TILE_ROM    = 3'd2;
localparam SPRITE_ROM  = 3'd3;

reg [2:0] rom;
reg [2:0] next_rom;
reg [2:0] pending_rom;

reg prog_rom_ctrl_req;
reg tile_rom_ctrl_req;
reg sprite_rom_ctrl_req;

reg prog_rom_ctrl_ack;
reg tile_rom_ctrl_ack;
reg sprite_rom_ctrl_ack;

reg prog_rom_ctrl_hit;
reg tile_rom_ctrl_hit;
reg sprite_rom_ctrl_hit;

reg prog_rom_ctrl_valid;
reg tile_rom_ctrl_valid;
reg sprite_rom_ctrl_valid;

reg [22:0] prog_rom_ctrl_addr;
reg [22:0] tile_rom_ctrl_addr;
reg [22:0] sprite_rom_ctrl_addr;

reg [1:0]  download_count;
reg [31:0] download_shift;
reg [22:0] download_addr;
reg [31:0] download_data;
reg        download_pending;
reg        download_pending_rom;
wire       download_byte = ioctl_download & ioctl_wr;
wire [18:0] prog_rom_segment_addr = prog_rom_addr[19:1];

reg        sprite_rom_full;
reg        sprite_rom_pending;
reg [22:0] sprite_rom_pending_addr;
reg [22:0] sprite_rom_cache_addr;
reg [31:0] sprite_rom_cache_data;

wire [22:0] sprite_rom_base_addr = 23'h060000;  // byte base 0x180000
wire [22:0] sprite_rom_addr32 = sprite_rom_base_addr + {5'd0, sprite_rom_addr};
wire        sprite_rom_active = sprite_rom_cs & !ioctl_download;

reg ctrl_req;

assign download_wait = download_pending | (download_byte & (download_count == 2'd3));

always @(posedge clk) begin
    if (reset && !ioctl_download && !download_pending) begin
        download_count <= 2'd0;
        download_shift <= 32'd0;
        download_data <= 32'd0;
        download_addr <= 23'd0;
        download_pending <= 1'b0;
        download_pending_rom <= 1'b0;
    end else begin
        if (download_pending && sdram_ack) begin
            download_pending <= 1'b0;
        end

        if (!ioctl_download && !download_pending) begin
            download_count <= 2'd0;
        end

        if (download_byte && !download_pending) begin
            case (download_count)
                2'd0: download_shift[31:24] <= ioctl_data;
                2'd1: download_shift[23:16] <= ioctl_data;
                2'd2: download_shift[15:8]  <= ioctl_data;
                default: begin
                    download_data <= {download_shift[31:8], ioctl_data};
                    download_addr <= ioctl_addr[24:2];
                    download_pending <= 1'b1;
                    download_pending_rom <= (ioctl_index == 16'd0);
                end
            endcase
            download_count <= download_count + 2'd1;
        end
    end
end

segment
#(
    .ROM_ADDR_WIDTH(19),
    .ROM_DATA_WIDTH(16),
    .ROM_OFFSET(24'h000000)
) prog_rom_segment
(
    .reset(reset),
    .clk(clk),
    .cs(prog_rom_cs & !ioctl_download),
    .oe(prog_rom_oe),
    .ctrl_addr(prog_rom_ctrl_addr),
    .ctrl_req(prog_rom_ctrl_req),
    .ctrl_ack(prog_rom_ctrl_ack),
    .ctrl_valid(prog_rom_ctrl_valid),
    .ctrl_hit(prog_rom_ctrl_hit),
    .ctrl_data(sdram_q),
    .rom_addr(prog_rom_segment_addr),
    .rom_data(prog_rom_data)
);

segment
#(
    .ROM_ADDR_WIDTH(18),
    .ROM_DATA_WIDTH(32),
    .ROM_OFFSET(24'h080000)
) tile_rom_segment
(
    .reset(reset),
    .clk(clk),
    .cs(tile_rom_cs & !ioctl_download),
    .oe(tile_rom_oe),
    .ctrl_addr(tile_rom_ctrl_addr),
    .ctrl_req(tile_rom_ctrl_req),
    .ctrl_ack(tile_rom_ctrl_ack),
    .ctrl_valid(tile_rom_ctrl_valid),
    .ctrl_hit(tile_rom_ctrl_hit),
    .ctrl_data(sdram_q),
    .rom_addr(tile_rom_addr),
    .rom_data(tile_rom_data)
);

always @(posedge clk, posedge reset) begin
    if (reset) begin
        sprite_rom_full <= 1'b0;
        sprite_rom_pending <= 1'b0;
        sprite_rom_pending_addr <= 23'd0;
        sprite_rom_cache_addr <= 23'd0;
        sprite_rom_cache_data <= 32'd0;
    end else begin
        if (sprite_rom_ctrl_ack) begin
            sprite_rom_pending <= 1'b1;
            sprite_rom_pending_addr <= sprite_rom_ctrl_addr;
        end else if (sprite_rom_ctrl_valid) begin
            sprite_rom_full <= 1'b1;
            sprite_rom_pending <= 1'b0;
            sprite_rom_cache_addr <= sprite_rom_pending_addr;
            sprite_rom_cache_data <= sdram_q;
        end
    end
end

always @(*) begin
    sprite_rom_ctrl_addr = sprite_rom_addr32;
    sprite_rom_ctrl_hit = sprite_rom_full && (sprite_rom_addr32 == sprite_rom_cache_addr);
    sprite_rom_ctrl_req = sprite_rom_active && !(sprite_rom_pending || sprite_rom_ctrl_hit);
end

assign sprite_rom_data = (sprite_rom_cs & sprite_rom_oe) ?
                         (sprite_rom_ctrl_valid ? sdram_q : sprite_rom_cache_data) :
                         32'd0;

always @(posedge clk, posedge reset) begin
    if (reset) begin
        rom <= NONE;
        pending_rom <= NONE;
    end else begin
        rom <= NONE;

        if (!ioctl_download && !download_pending) begin
            rom <= next_rom;
        end

        if (sdram_ack && !download_pending) begin
            pending_rom <= rom;
        end
    end
end

assign prog_rom_data_valid   = prog_rom_cs   & (prog_rom_ctrl_hit   | (pending_rom == PROG_ROM   ? sdram_valid : 1'b0)) & ~reset;
assign tile_rom_data_valid   = tile_rom_cs   & (tile_rom_ctrl_hit   | (pending_rom == TILE_ROM   ? sdram_valid : 1'b0)) & ~reset;
assign sprite_rom_data_valid = sprite_rom_cs & (sprite_rom_ctrl_hit | (pending_rom == SPRITE_ROM ? sdram_valid : 1'b0)) & ~reset;

always @(*) begin
    next_rom <= NONE;
    case (1'b1)
        prog_rom_ctrl_req:   next_rom <= PROG_ROM;
        tile_rom_ctrl_req:   next_rom <= TILE_ROM;
        sprite_rom_ctrl_req: next_rom <= SPRITE_ROM;
        default:             next_rom <= NONE;
    endcase

    prog_rom_ctrl_ack <= 1'b0;
    tile_rom_ctrl_ack <= 1'b0;
    sprite_rom_ctrl_ack <= 1'b0;
    case (rom)
        PROG_ROM:   prog_rom_ctrl_ack <= sdram_ack;
        TILE_ROM:   tile_rom_ctrl_ack <= sdram_ack;
        SPRITE_ROM: sprite_rom_ctrl_ack <= sdram_ack;
        default: ;
    endcase

    prog_rom_ctrl_valid <= 1'b0;
    tile_rom_ctrl_valid <= 1'b0;
    sprite_rom_ctrl_valid <= 1'b0;
    case (pending_rom)
        PROG_ROM:   prog_rom_ctrl_valid <= sdram_valid;
        TILE_ROM:   tile_rom_ctrl_valid <= sdram_valid;
        SPRITE_ROM: sprite_rom_ctrl_valid <= sdram_valid;
        default: ;
    endcase

    ctrl_req <= prog_rom_ctrl_req | tile_rom_ctrl_req | sprite_rom_ctrl_req;

    sdram_addr <= 23'd0;
    case (1'b1)
        download_pending:    sdram_addr <= download_addr;
        prog_rom_ctrl_req:   sdram_addr <= prog_rom_ctrl_addr;
        tile_rom_ctrl_req:   sdram_addr <= tile_rom_ctrl_addr;
        sprite_rom_ctrl_req: sdram_addr <= sprite_rom_ctrl_addr;
        default:             sdram_addr <= 23'd0;
    endcase

    sdram_data <= download_data;
    sdram_req <= download_pending | (!download_pending & !ioctl_download & ctrl_req);
    sdram_we <= download_pending & download_pending_rom;
end

wire [14:0] sound_rom_ofs = ioctl_addr[14:0];
wire sound_rom_w = (ioctl_index == 16'd0) && ioctl_wr &&
                   (ioctl_addr >= 27'h0200000) && (ioctl_addr < 27'h0208000);

assign sound_rom_1_data_valid = sound_rom_1_oe;

dual_port_ram #(.LEN(32768), .DATA_WIDTH(8)) sound_rom
(
    .clock_a(clk),
    .address_a(sound_rom_ofs),
    .wren_a(sound_rom_w),
    .data_a(ioctl_data),
    .q_a(),

    .clock_b(clk),
    .address_b(sound_rom_1_addr[14:0]),
    .wren_b(1'b0),
    .data_b(8'd0),
    .q_b(sound_rom_1_data)
);

endmodule
