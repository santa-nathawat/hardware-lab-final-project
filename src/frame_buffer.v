// Dual-clock 320x240 RGB565 frame buffer.
// Port A writes camera pixels in the cam_pclk domain. Port B reads pixels in
// the pixel_clk domain for VGA display.

module frame_buffer (
    input  wire        clka,
    input  wire        ena,
    input  wire        wea,
    input  wire [16:0] addra,
    input  wire [15:0] dina,

    input  wire        clkb,
    input  wire        enb,
    input  wire [16:0] addrb,
    output wire [15:0] doutb
);

`ifdef SIMULATION
    // Small behavioral model for Cocotb tests.
    reg [15:0] mem [0:76799];

    integer k;
    initial begin
        for (k = 0; k < 76800; k = k + 1)
            mem[k] = 16'd0;
    end

    always @(posedge clka) begin
        if (ena && wea)
            mem[addra] <= dina;
    end

    reg [15:0] doutb_reg;
    always @(posedge clkb) begin
        if (enb)
            doutb_reg <= mem[addrb];
    end
    assign doutb = doutb_reg;

`else
    // Vivado IP: true dual-port RAM, 16-bit wide, 76800-deep.
    // Port B output register is enabled, so reads have one clock of latency.
    blk_mem_gen_0 u_bram (
        .clka  (clka),
        .ena   (ena),
        .wea   (wea),
        .addra (addra),
        .dina  (dina),
        .douta (),

        .clkb  (clkb),
        .enb   (enb),
        .web   (1'b0),
        .addrb (addrb),
        .dinb  (16'd0),
        .doutb (doutb)
    );
`endif

endmodule
