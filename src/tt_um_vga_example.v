/*
* Copyright (c) 2024 Konrad Beckmann
* Copyright (c) 2024 Linus Mårtensson
* SPDX-License-Identifier: Apache-2.0
*/

`default_nettype none

module tt_um_vga_example(
input  wire [7:0] ui_in,    // Dedicated inputs
output wire [7:0] uo_out,   // Dedicated outputs
input  wire [7:0] uio_in,   // IOs: Input path
output wire [7:0] uio_out,  // IOs: Output path
output wire [7:0] uio_oe,   // IOs: Enable path (active high: 0=input, 1=output)
input  wire       ena,      // always 1 when the design is powered, so you can ignore it
input  wire       clk,      // clock
input  wire       rst_n     // reset_n - low to reset
);


// VGA signals
wire hsync;
wire vsync;
wire [1:0] R;
wire [1:0] G;
wire [1:0] B;
wire video_active;
wire [9:0] pix_x;
wire [9:0] pix_y;

// TinyVGA PMOD
assign uo_out = {hsync, B[0], G[0], R[0], vsync, B[1], G[1], R[1]};

// Unused outputs assigned to 0.
assign uio_out = 0;
assign uio_oe  = 0;

// Suppress unused signals warning
wire _unused_ok = &{ena, ui_in, uio_in};



hvsync_generator hvsync_gen(
    .clk(clk),
    .reset(~rst_n),
    .hsync(hsync),
    .vsync(vsync),
    .display_on(video_active),
    .hpos(pix_x),
    .vpos(pix_y)
);

reg [11:0] counter;
reg [23:0] VAL;
reg top, bottom, left, right;
reg [10:0] rxy, pxy;
reg  [5:0] LFSR = 1;
reg [7:0] T, xl, yl, bottom_l, back_l, top_a, top_b, top_l;
reg fg;
reg lh, bh;
reg [7:0] fgg, fgb;

function reg[18:0] max ( input reg [18:0] a, b);
  max = a > b ? a : b;
endfunction
function reg[19:0] min ( input reg[19:0] a, b);
  min = a < b ? a : b;
endfunction
function reg[7:0] abs ( input reg[7:0] a);
  abs = a[7]?-a:a;
endfunction
function reg[7:0] tria (input reg[7:0] a);
  tria = a > 127 ? 255 - a : a;
endfunction;

reg [19:0] yq, yqo, xq, xqo;
reg [9:0] limy;
reg [7:0] r,g,b;


always @(posedge clk) begin
  if(~rst_n) begin
    top <= 0; bottom <= 0; left <= 0; right <= 0;
    rxy <= 0; pxy <= 0;
    LFSR <= 1;
    //TODO rst all the things^
  end else begin

    
    VAL[7:0]   <= r;
    VAL[15:8]  <= g;
    VAL[23:16] <= b;
    
    r <= (tria((((xq>>4))-(yq>>5)))+((pix_x>>2)+(pix_y>>3))-20);
    g <= r + (pix_y>>3);
    b <= g + (pix_y>>3);
    
    
    xq <= xqo + 22;
    xqo <= xq;
    if (hsync) begin
      yq <= yqo + (tria(pix_y+(counter<<2)>>1)>>2)-22;
      xq <= 0;
    end else begin
      yqo <= yq;
    end
    if (vsync) begin
      LFSR <= 1;
      yq <= 0;
      yqo <= 0;
    end else begin
      LFSR[5:1]   <= LFSR[4:0];
      LFSR[0]   <= LFSR[2]^LFSR[1];
    end
  end
end


assign R = video_active ? (
        (VAL[7:6]) + (LFSR[5:0] < VAL[5:0])
    ) : 2'b00;
assign G = video_active ? (
        (VAL[15:14]) + (LFSR[5:0] < VAL[13:8])
    ) : 2'b00;
assign B = video_active ? (
        (VAL[23:22]) + (LFSR[5:0] < VAL[21:16])
    ) : 2'b00;

always @(posedge vsync) begin
    if (~rst_n) begin
    counter <= 0;
    end else begin
    counter <= counter + 1;
    end
end

endmodule