// RGB565 pixel filter.
// sw[1:0]: 00 raw, 01 grayscale, 10 red-only, 11 inverted.

module filter_engine (
    input  wire [15:0] pixel_in,
    input  wire [1:0]  sw,
    output reg  [15:0] pixel_out
);

    wire [4:0] r5 = pixel_in[15:11];
    wire [5:0] g6 = pixel_in[10:5];
    wire [4:0] b5 = pixel_in[4:0];

    // Weighted grayscale used by the existing tests and camera tuning.
    // The 6-bit value is reused for green; its upper 5 bits feed red/blue.
    wire [13:0] y_scaled = (r5 * 14'd54) + (g6 * 14'd183) + (b5 * 14'd18);
    wire [5:0] y_6bit = y_scaled[13:8];
    wire [4:0] y_5bit = y_6bit[5:1];

    always @(*) begin
        case (sw)
            2'b00: begin
                pixel_out = pixel_in;
            end
            2'b01: begin
                pixel_out = {y_5bit, y_6bit, y_5bit};
            end
            2'b10: begin
                pixel_out = {r5, 6'b0, 5'b0};
            end
            2'b11: begin
                pixel_out = ~pixel_in;
            end
            default: pixel_out = pixel_in;
        endcase
    end

endmodule
