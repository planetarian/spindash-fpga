module spindash #(parameter YM_COUNT=5)(
    input           rst,   // reset (active high), should be at least 6 clk&cen cycles long
    input           clk50, // base clock (50mhz)
  //input           cen,   // clock enable (cpu clock/6), if not needed send 1'b1
    input   [7:0]   din,   // data write value
    input   [1:0]   addr,  // A0: reg/data; A1: channels 1-3/4-6
    input   [4:0]   cs, // 1-31: chip select, 0:none
    input           wr_n,  // write reg/data (active low)
    output  [4:0]   cs_thru, // pass cs through to next chip
    output  [7:0]   dout,  // data read value
    output          irq_n, // IRQ pin
    // configuration
    //input           en_hifi_pcm,
    // combined output
    output          pdm_left,
    output          pdm_right,
    output          snd_sample,
    // debug outputs
    output  [3:0]   DEBUG,
    output          LEDREADY,
    output          LEDDONE
);


// 53.7Mhz genesis clock; switch to this once everything else works
wire clk_jt;
pll53 pll(
    .clkin(clk50),
    .clkout0(clk_jt)
);

// clock enable divides incoming clock by 6
// see: https://github.com/supersat/hadbadge2019_fpgasoc/blob/ym2612/soc/audio/audio_wb.v
wire cen;
reg [2:0] clkdiv;
always @(posedge clk_jt)
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
assign DEBUG[0] = clk_jt;
assign DEBUG[1] = cen;
assign DEBUG[2] = pdm_left;
assign DEBUG[3] = snd_sample;
assign LEDREADY = rst;
assign LEDDONE = addr[0];

wire signed [15 + $clog2(YM_COUNT):0] snd_left;
wire signed [15 + $clog2(YM_COUNT):0] snd_right;

wire signed [15:0] snd_left_ic [YM_COUNT-1:0];
wire signed [15:0] snd_right_ic [YM_COUNT-1:0];

// sum together all the outputs
reg signed [15+$clog2(YM_COUNT):0] snd_left_sum [YM_COUNT-1:0];
reg signed [15+$clog2(YM_COUNT):0] snd_right_sum [YM_COUNT-1:0];
integer s;
always @* begin
    for (s=0; s<YM_COUNT; s=s+1) begin
        if (s == 0) begin
            snd_left_sum[s] = snd_left_ic[s];
            snd_right_sum[s] = snd_right_ic[s];
        end
        else begin
            snd_left_sum[s] = snd_left_sum[s-1] + snd_left_ic[s];
            snd_right_sum[s] = snd_right_sum[s-1] + snd_right_ic[s];
        end
    end
end
assign snd_left = snd_left_sum[YM_COUNT-1];
assign snd_right = snd_right_sum[YM_COUNT-1];

assign cs_thru = cs < YM_COUNT+1 ? 5'b0 : cs - (YM_COUNT+1);
wire [YM_COUNT-1:0] cs_n;

wire [YM_COUNT-1:0] snd_sample_ic;
assign snd_sample = snd_sample_ic[0];

genvar i;
generate
    for (i = 0; i < YM_COUNT; i = i+1)
    begin
        assign cs_n[i] = cs != i+1;

        jt12_top fm (
            // inputs
            .rst(rst),
            .clk(clk_jt),
            .cen(cen),
            .din(din),
            .addr(addr),
            .cs_n(cs_n[i]),
            .wr_n(wr_n),
            .en_hifi_pcm(1'b1),
            // outputs
            .dout(/*dout*/),
            .irq_n(/*irq_n*/),
            .snd_left(snd_left_ic[i]),
            .snd_right(snd_right_ic[i]),
            .snd_sample(snd_sample_ic[i]),

            // default input values from jt12.v
            .adpcma_data    ( 8'd0 ), // Data from RAM
            .adpcmb_data    ( 8'd0 ),
            .ch_enable      ( 6'h3f),
            .debug_bus      ( 8'd0          ),
            // Unused YM2203
            .IOA_in         ( 8'b0          ),
            .IOB_in         ( 8'b0          )
        );
    end
endgenerate

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