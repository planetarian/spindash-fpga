module spindash(
    input           rst,   // reset (active high), should be at least 6 clk&cen cycles long
    input           clk50, // base clock (50mhz)
  //input           cen,   // clock enable (cpu clock/6), if not needed send 1'b1
    input   [7:0]   din,   // data write value
    input   [1:0]   addr,  // A0: reg/data; A1: channels 1-3/4-6
    input           cs_n,  // chip select (active low)
    input           wr_n,  // write reg/data (active low)
    output  [7:0]   dout,  // data read value
    output          irq_n, // IRQ pin
    // configuration
    //input           en_hifi_pcm,
    // combined output
    output  signed  [15:0]  snd_right,
    output  signed  [15:0]  snd_left,
    output          snd_sample,
    // debug outputs
    output  [3:0]   DEBUG,
    output          LEDREADY,
    output          LEDDONE
);

/*
// 53.7Mhz genesis clock; switch to this once everything else works
wire clk_jt;
pll53 pll(
    .clkin(clk50),
    .clkout0(clk_jt)
);*/

// clock enable divides incoming clock by 6
// see: https://github.com/supersat/hadbadge2019_fpgasoc/blob/ym2612/soc/audio/audio_wb.v
wire cen;
reg [2:0] clkdiv;
always @(posedge clk50)
begin
    if (rst)
    begin
        clkdiv <= 0;
    end
    else
    begin
        if (clkdiv == 5)
            clkdiv <= 0;
        else
            clkdiv <= clkdiv + 1;
    end
end
assign cen = clkdiv == 0;

// debug outputs
assign DEBUG[0] = clk50;
assign DEBUG[1] = cen;
assign DEBUG[2] = wr_n;
assign DEBUG[3] = addr[0];
assign LEDREADY = rst;
assign LEDDONE = addr[0];

// comment out this module and rst suddenly works??
jt12_top fm (
    // inputs
    .rst(rst),
    .clk(clk50),
    .cen(cen),
    .din(din),
    .addr(addr),
    .cs_n(cs_n),
    .wr_n(wr_n),
    .en_hifi_pcm(1'b1),
    // outputs
    .dout(dout),
    .irq_n(irq_n),
    .snd_left(snd_left),
    .snd_right(snd_right),
    .snd_sample(snd_sample),

    // default input values from jt12.v
    .adpcma_data    ( 8'd0 ), // Data from RAM
    .adpcmb_data    ( 8'd0 ),
    .ch_enable      ( 6'h3f),
    .debug_bus      ( 8'd0          ),
    // Unused YM2203
    .IOA_in         ( 8'b0          ),
    .IOB_in         ( 8'b0          )
);//*/


endmodule