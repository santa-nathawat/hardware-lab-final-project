// Captures OV7670 byte pairs on cam_pclk, packs RGB565 pixels, crops unstable
// sensor edges, and writes a 320x240 downsampled frame.

module ov7670_capture #(
    parameter FRAME_WIDTH  = 320,
    parameter FRAME_HEIGHT = 240
)(
    input  wire        pclk,
    input  wire        rst,
    input  wire        cam_vsync,
    input  wire        cam_href,
    input  wire [7:0]  cam_d,

    output reg         wr_en,
    output reg  [16:0] wr_addr,
    output reg  [15:0] wr_data,
    output reg         frame_done
);

    localparam EDGE_GUARD = 10'd4;
    localparam CLEAN_H_END = 10'd644;
    localparam CLEAN_V_END = 10'd484;
    localparam EDGE_GUARD_DIV2 = 9'd2;

    reg [7:0]  first_byte;
    reg        byte_cnt;
    reg        vsync_prev;
    reg        href_prev;
    reg [9:0]  h_cnt;
    reg [9:0]  v_cnt;

    always @(negedge pclk) begin
        if (rst) begin
            wr_addr    <= 17'd0;
            wr_data    <= 16'd0;
            byte_cnt   <= 1'b0;
            wr_en      <= 1'b0;
            frame_done <= 1'b0;
            h_cnt      <= 10'd0;
            v_cnt      <= 10'd0;
            href_prev  <= 1'b0;
            vsync_prev <= 1'b0;
        end else begin
            wr_en      <= 1'b0;
            frame_done <= 1'b0;
            vsync_prev <= cam_vsync;
            href_prev  <= cam_href;

            if (cam_vsync) begin
                wr_addr    <= 17'd0;
                byte_cnt   <= 1'b0;
                h_cnt      <= 10'd0;
                v_cnt      <= 10'd0;
            end else begin
                if (vsync_prev) begin
                    frame_done <= 1'b1;
                end

                if (!cam_href && href_prev) begin
                    v_cnt <= v_cnt + 10'd1;
                end

                if (cam_href) begin
                    if (!byte_cnt) begin
                        first_byte <= cam_d;
                        byte_cnt   <= 1'b1;
                    end else begin
                        // Skip the first few rows/columns and keep every other pixel.
                        if (h_cnt >= EDGE_GUARD && v_cnt >= EDGE_GUARD &&
                            h_cnt < CLEAN_H_END && v_cnt < CLEAN_V_END) begin
                            if (h_cnt[0] == 1'b0 && v_cnt[0] == 1'b0) begin
                                wr_data <= {first_byte, cam_d};
                                wr_en   <= 1'b1;
                                
                                // addr = ((v_cnt - 4) / 2) * 320 + ((h_cnt - 4) / 2)
                                wr_addr <= ({8'd0, v_cnt[9:1] - EDGE_GUARD_DIV2} << 8) +
                                           ({8'd0, v_cnt[9:1] - EDGE_GUARD_DIV2} << 6) +
                                           {8'd0, h_cnt[9:1] - EDGE_GUARD_DIV2};
                            end
                        end
                        h_cnt    <= h_cnt + 10'd1;
                        byte_cnt <= 1'b0;
                    end
                end else begin
                    byte_cnt <= 1'b0;
                    h_cnt    <= 10'd0;
                end
            end
        end
    end

endmodule
