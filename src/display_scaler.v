// Maps VGA coordinates to the 320x240 frame buffer, applies the selected
// RGB565 filter, and drives the 4-bit VGA DAC signals.
//
// The displayed camera image is a centered 360x480 region. That region is
// scaled back to a 240x320 rotated coordinate space, then mapped into the
// 320x240 buffer to correct the camera orientation used by this build.

module display_scaler (
    input  wire        clk,
    input  wire        rst,

    input  wire [9:0]  hcount,
    input  wire [9:0]  vcount,
    input  wire        active,

    input  wire        frame_valid,

    input  wire [15:0] rd_data,
    output wire [16:0] rd_addr,

    input  wire [1:0]  sw,

    output reg  [3:0]  vga_r,
    output reg  [3:0]  vga_g,
    output reg  [3:0]  vga_b
);

    localparam SCREEN_X_OFFSET = 10'd140;
    localparam SCREEN_X_END    = 10'd500;
    localparam SCREEN_Y_END    = 10'd480;
    localparam SCALE_NUM       = 8'd171;  // 171/256 is close to 2/3.

    // Center a 360x480 image on a 640x480 display.
    wire valid_area = (hcount >= SCREEN_X_OFFSET && hcount < SCREEN_X_END && vcount < SCREEN_Y_END);
    wire [8:0] screen_x = hcount - SCREEN_X_OFFSET;
    
    wire [16:0] scaled_x_full = screen_x * SCALE_NUM;
    wire [17:0] scaled_y_full = vcount   * SCALE_NUM;
    
    wire [7:0] rot_x = scaled_x_full[15:8];
    wire [8:0] rot_y = scaled_y_full[16:8];

    // Orientation correction: screen Y selects buffer X, screen X selects buffer Y.
    wire [8:0] img_x = rot_y;
    wire [7:0] img_y = rot_x;

    // addr = img_y * 320 + img_x
    wire [16:0] addr_next = ({9'd0, img_y} << 8) + ({9'd0, img_y} << 6) + {8'd0, img_x};

    assign rd_addr = (active && valid_area) ? addr_next : 17'd0;

    // Delay visibility to match the BRAM read and output register pipeline.
    reg active_d1;
    reg active_d2;

    always @(posedge clk) begin
        if (rst) begin
            active_d1 <= 1'b0;
            active_d2 <= 1'b0;
        end else begin
            active_d1 <= (active && valid_area);
            active_d2 <= active_d1;
        end
    end

    wire [15:0] filtered_pixel;
    filter_engine u_filter (
        .pixel_in  (rd_data),
        .sw        (sw),
        .pixel_out (filtered_pixel)
    );

    always @(posedge clk) begin
        if (rst) begin
            vga_r <= 4'd0;
            vga_g <= 4'd0;
            vga_b <= 4'd0;
        end else begin
            if (!active_d2 || !frame_valid) begin
                vga_r <= 4'd0;
                vga_g <= 4'd0;
                vga_b <= 4'd0;
            end else begin
                vga_r <= filtered_pixel[15:12];
                vga_g <= filtered_pixel[10:7];
                vga_b <= filtered_pixel[4:1];
            end
        end
    end

endmodule
