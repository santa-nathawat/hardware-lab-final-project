// 640x480 VGA timing generator.
// hcount/vcount cover the full 800x525 frame, while active marks the visible
// 640x480 area. Sync pulses are active low.

module vga_controller (
    input  wire        clk,
    input  wire        rst,
    output reg  [9:0]  hcount,
    output reg  [9:0]  vcount,
    output wire        hsync,
    output wire        vsync,
    output wire        active
);

    localparam H_ACTIVE   = 640;
    localparam H_FP       = 16;
    localparam H_SYNC     = 96;
    localparam H_BP       = 48;
    localparam H_TOTAL    = 800;

    localparam V_ACTIVE   = 480;
    localparam V_FP       = 10;
    localparam V_SYNC     = 2;
    localparam V_BP       = 33;
    localparam V_TOTAL    = 525;

    localparam H_SYNC_START = H_ACTIVE + H_FP;
    localparam H_SYNC_END   = H_ACTIVE + H_FP + H_SYNC;
    localparam V_SYNC_START = V_ACTIVE + V_FP;
    localparam V_SYNC_END   = V_ACTIVE + V_FP + V_SYNC;

    always @(posedge clk) begin
        if (rst) begin
            hcount <= 10'd0;
        end else begin
            if (hcount == H_TOTAL - 1)
                hcount <= 10'd0;
            else
                hcount <= hcount + 10'd1;
        end
    end

    // Increment the line counter at the end of each horizontal line.
    always @(posedge clk) begin
        if (rst) begin
            vcount <= 10'd0;
        end else begin
            if (hcount == H_TOTAL - 1) begin
                if (vcount == V_TOTAL - 1)
                    vcount <= 10'd0;
                else
                    vcount <= vcount + 10'd1;
            end
        end
    end

    assign hsync  = ~((hcount >= H_SYNC_START) && (hcount < H_SYNC_END));
    assign vsync  = ~((vcount >= V_SYNC_START) && (vcount < V_SYNC_END));

    assign active = (hcount < H_ACTIVE) && (vcount < V_ACTIVE);

endmodule
