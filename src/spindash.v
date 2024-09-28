`timescale 1ns / 1ps

module spindash #(parameter YM_COUNT=
// how many jt12 instances to generate
`ifdef HIGH_CAPACITY 
45 // ~100K LUT: Artix-7 XC7A100T
`else
9 // ~20K LUT: Nano20K/Primer25K
`endif
)(
    // clock/reset
    input           rst,   // reset (active high), should be at least 6 clk&cen cycles long
    input           clk,   // base clock (50mhz)
  //input           cen,   // clock enable (cpu clock/6), if not needed send 1'b1
    // command input
    input   [1:0]   addr,  // A0: reg/data; A1: channels 1-3/4-6
    input   [7:0]   din,   // data write value
    input   [5:0]   cs,    // 1+: chip select, 0:none
    input           wr_n,  // write reg/data (active low)
    // configuration
  //input           en_hifi_pcm,
    
    output  [5:0]   cs_thru, // pass cs through to next chip
    output  [7:0]   dout,  // data read value
    output          irq_n, // IRQ pin
    // combined output
    output          pdm_left,
    output          pdm_right,
    output          snd_sample, // posedge on new sample (~62.157khz)
    // debug outputs
    output  [3:0]   DEBUG,
    output          LEDREADY,
    output          LEDDONE
);

// clocks
// clk            50.0000mhz
// clk_jt         53.7037mhz     ------------,     (aim for 53.689mhz)
// clk_jt_div6     8.9506mhz     ------,    /6  
// clk_en          1.4918mhz     -,   /6    /36    (jt_top.v) one clock per channel+oper
// snd_sample         62.1570khz /24  /144  /864
// TODO: clk_i2s ideally, snd_sample * 42 (48?)

// 53.7Mhz master clock
wire clk_jt;
pll53 pll(
    .clkin(clk),
`ifdef PLL_HAS_RESET
    .reset(rst),
`endif
    .clkout0(clk_jt)
);

// 8.9Mhz clock enable (master clock / 6)
// see: https://github.com/supersat/hadbadge2019_fpgasoc/blob/ym2612/soc/audio/audio_wb.v
wire clk_jt_div6;
reg [2:0] clkdiv;
always @(posedge clk_jt)
begin
    if (rst || clkdiv == 5)
    begin
        clkdiv <= 0;
    end
    else
    begin
        clkdiv <= clkdiv + 1;
    end
end
assign clk_jt_div6 = clkdiv == 0;

// debug outputs
//assign DEBUG[0] = clk_jt;
//assign DEBUG[1] = clk_jt_div6;
assign DEBUG[2] = pdm_left;
assign DEBUG[3] = snd_sample;
assign LEDREADY = rst;
assign LEDDONE = addr[0];

// 16-bit analog output from each instance
wire signed [15:0] snd_left_ic [YM_COUNT-1:0];
wire signed [15:0] snd_right_ic [YM_COUNT-1:0];


// sum together all the outputs
//  1 chip = 16 bits (clog2(1) = 0)
//  9 chip = 20 bits (clog2(9) = 4)
// 17 chip = 21 bits
reg signed [15 + $clog2(YM_COUNT):0] snd_left_sum [YM_COUNT-1:0];
reg signed [15 + $clog2(YM_COUNT):0] snd_right_sum [YM_COUNT-1:0];
integer s;
always @* begin
    for (s=0; s<YM_COUNT; s=s+1) begin
        if (s == 0) begin
            snd_left_sum[s] = snd_left_ic[s];
            snd_right_sum[s] = snd_right_ic[s];
        end
        else begin
            snd_left_sum[s] = snd_left_ic[s] + snd_left_sum[s-1];
            snd_right_sum[s] = snd_right_ic[s] + snd_right_sum[s-1];
        end
    end
end
wire signed [15 + $clog2(YM_COUNT):0] snd_left;
wire signed [15 + $clog2(YM_COUNT):0] snd_right;
// final entry in the sum array is the sum of all outputs
assign snd_left = snd_left_sum[YM_COUNT-1];
assign snd_right = snd_right_sum[YM_COUNT-1];

// chip select passthru for daisy-chaining multiple FPGAs
// supports up to 31 selectable chips
assign cs_thru = cs <= YM_COUNT ? 5'b0 : cs - YM_COUNT;
// individual CS signals to send to each YM
wire [YM_COUNT-1:0] cs_n;

// posedge when a new sample is available
wire [YM_COUNT-1:0] snd_sample_ic;
assign snd_sample = snd_sample_ic[0];

// jt12_div previously lived inside jt12_mmr
// we can save on resources by extracting it to top level
// and passing the clocks down to the jt12 instances
wire clk_en, clk_en_2, clk_en_ssg, clk_en_666, clk_en_111, clk_en_55;
localparam div_setting = 2'b10; // FM: 1/6
localparam use_ssg = 1'b0;

jt12_div #(.use_ssg(use_ssg)) u_div (
    .rst            ( rst             ),
    .clk            ( clk_jt          ),
    .cen            ( clk_jt_div6     ),
    .clk_en         ( clk_en          ),
    .clk_en_2       ( clk_en_2        ),
    .clk_en_ssg     ( clk_en_ssg      ),
    .clk_en_666     ( clk_en_666      ),
    .clk_en_111     ( clk_en_111      ),
    .clk_en_55      ( clk_en_55       ),
    .div_setting    ( div_setting     )
);

// generate the YM chip instances
genvar i;
generate
    for (i = 0; i < YM_COUNT; i = i+1)
    begin : fm
        assign cs_n[i] = cs != (i+1);

        jt12_top ym (
            // clock/reset
            .rst(rst),
            .clk(clk_jt),
            .cen(clk_jt_div6),
            // jt12_div clocks
            .clk_en         ( clk_en          ),
            .clk_en_2       ( clk_en_2        ),
            .clk_en_ssg     ( clk_en_ssg      ),
            .clk_en_666     ( clk_en_666      ),
            .clk_en_111     ( clk_en_111      ),
            .clk_en_55      ( clk_en_55       ),
            // command inputs
            .din(din),
            .addr(addr),
            .cs_n(cs_n[i]),
            .wr_n(wr_n),
            // outputs
            .dout(/*dout*/),
            .irq_n(/*irq_n*/),
            .snd_left(snd_left_ic[i]),
            .snd_right(snd_right_ic[i]),
            .snd_sample(snd_sample_ic[i]),

            // configuration
            .en_hifi_pcm    ( 1'b1 ),
            // default input values from jt12.v
            .adpcma_data    ( 8'd0 ), // Data from RAM
            .adpcmb_data    ( 8'd0 ),
            .ch_enable      ( 6'h3f ),
            .debug_bus      ( 8'd0 ),
            // Unused YM2203
            .IOA_in         ( 8'b0 ),
            .IOB_in         ( 8'b0 )
        );

    end
endgenerate

// get the mixed output as a pair of PDM signals
delta_sigma_adc #(.WIDTH(16 + $clog2(YM_COUNT))) pdm_l (
    .rst(1'b0),
    .clk(clk_jt),
    .din(snd_left),
    .dout(pdm_left)
);
delta_sigma_adc #(.WIDTH(16 + $clog2(YM_COUNT))) pdm_r (
    .rst(1'b0),
    .clk(clk_jt),
    .din(snd_right),
    .dout(pdm_right)
);

endmodule
