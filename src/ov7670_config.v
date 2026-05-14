// Sequences the OV7670 register writes used by this design.
// The SCCB master sends one {register, data} pair whenever sccb_start pulses.

module ov7670_config (
    input  wire        clk,
    input  wire        rst,

    input  wire        sccb_done,
    output reg         sccb_start,
    output reg  [7:0]  reg_addr,
    output reg  [7:0]  reg_data,

    output reg         cfg_done
);

    localparam END_MARKER = 16'hFFFF;

    reg [15:0] current_reg;
    reg [6:0]  rom_idx;

    always @(*) begin
        case (rom_idx)
            7'd0:  current_reg = {8'h12, 8'h80}; // COM7: soft reset
            
            // Clocking and output format.
            7'd1:  current_reg = {8'h11, 8'h00}; // CLKRC: no divider
            7'd2:  current_reg = {8'h6b, 8'h4a}; // DBLV: PLL 4x
            7'd3:  current_reg = {8'h3b, 8'h0a}; // COM11: Night mode OFF
            7'd4:  current_reg = {8'h12, 8'h04}; // COM7: RGB565 (VGA mode natively)
            7'd5:  current_reg = {8'h40, 8'hD0}; // COM15: RGB565 + Full Range
            7'd6:  current_reg = {8'h3a, 8'h04}; // TSLB
            7'd7:  current_reg = {8'h0c, 8'h00}; // COM3: DCW disable
            7'd8:  current_reg = {8'h3e, 8'h00}; // COM14: No internal scaling
            7'd9:  current_reg = {8'h70, 8'h3a}; // SCALING_XSC
            7'd10: current_reg = {8'h71, 8'h35}; // SCALING_YSC
            7'd11: current_reg = {8'h72, 8'h11}; // SCALING_DCWCTR
            7'd12: current_reg = {8'h73, 8'hf1}; // SCALING_PCLK_DIV
            7'd13: current_reg = {8'ha2, 8'h02}; // SCALING_PCLK_DELAY
            
            // Sensor window.
            7'd14: current_reg = {8'h17, 8'h13}; // HSTART
            7'd15: current_reg = {8'h18, 8'h01}; // HSTOP
            7'd16: current_reg = {8'h32, 8'hbf}; // HREF
            7'd17: current_reg = {8'h19, 8'h02}; // VSTART
            7'd18: current_reg = {8'h1a, 8'h7a}; // VSTOP
            7'd19: current_reg = {8'h03, 8'h0a}; // VREF

            // Color, exposure, gamma, and image tuning.
            7'd20: current_reg = {8'h4f, 8'hb3}; // MTX1
            7'd21: current_reg = {8'h50, 8'hb3}; // MTX2
            7'd22: current_reg = {8'h51, 8'h00}; // MTX3
            7'd23: current_reg = {8'h52, 8'h3d}; // MTX4
            7'd24: current_reg = {8'h53, 8'ha7}; // MTX5
            7'd25: current_reg = {8'h54, 8'he4}; // MTX6
            7'd26: current_reg = {8'h58, 8'h5e}; // MTXS: 0x5E = Manual Matrix Enable

            7'd27: current_reg = {8'h13, 8'hef}; // COM8: Enable AEC, AGC, AWB
            7'd28: current_reg = {8'h00, 8'h00}; // GAIN
            7'd29: current_reg = {8'h10, 8'h00}; // AECH
            7'd30: current_reg = {8'h0d, 8'h40}; // COM4
            7'd31: current_reg = {8'h14, 8'h38}; // COM9: 8x Gain Ceiling
            7'd32: current_reg = {8'h24, 8'h95}; // AEW
            7'd33: current_reg = {8'h25, 8'h33}; // AEB
            7'd34: current_reg = {8'h26, 8'he3}; // VPT

            7'd35: current_reg = {8'h7a, 8'h20};
            7'd36: current_reg = {8'h7b, 8'h10};
            7'd37: current_reg = {8'h7c, 8'h1e};
            7'd38: current_reg = {8'h7d, 8'h35};
            7'd39: current_reg = {8'h7e, 8'h5a};
            7'd40: current_reg = {8'h7f, 8'h69};
            7'd41: current_reg = {8'h80, 8'h76};
            7'd42: current_reg = {8'h81, 8'h80};
            7'd43: current_reg = {8'h82, 8'h88};
            7'd44: current_reg = {8'h83, 8'h8f};
            7'd45: current_reg = {8'h84, 8'h96};
            7'd46: current_reg = {8'h85, 8'ha3};
            7'd47: current_reg = {8'h86, 8'haf};
            7'd48: current_reg = {8'h87, 8'hc4};
            7'd49: current_reg = {8'h88, 8'hd7};
            7'd50: current_reg = {8'h89, 8'he8};

            7'd51: current_reg = {8'h41, 8'h38}; // COM16: Denoise + Edge enhancement + AWB gain ENABLED
            7'd52: current_reg = {8'h76, 8'he1}; // OV
            7'd53: current_reg = {8'h33, 8'h0b}; // CHLF
            7'd54: current_reg = {8'h3c, 8'h78}; // COM12
            7'd55: current_reg = {8'h69, 8'h00}; // GFIX
            7'd56: current_reg = {8'h74, 8'h00}; // REG74
            7'd57: current_reg = {8'hb0, 8'h84}; // T_ELB
            7'd58: current_reg = {8'hb1, 8'h0c}; // ABLC1
            7'd59: current_reg = {8'hb2, 8'h0e}; // Reserved
            7'd60: current_reg = {8'hb3, 8'h82}; // Reserved

            7'd61: current_reg = {8'h67, 8'hc0}; // U gain (Saturation Boost)
            7'd62: current_reg = {8'h68, 8'hc0}; // V gain (Saturation Boost)
            7'd63: current_reg = {8'h56, 8'h40}; // Contrast
            
            7'd64: current_reg = {8'h15, 8'h00}; // COM10
            7'd65: current_reg = {8'h0e, 8'h61}; // COM6
            7'd66: current_reg = {8'h16, 8'h00}; // Reserved
            7'd67: current_reg = {8'h1e, 8'h07}; // MVFP
            7'd68: current_reg = {8'h3d, 8'hc0}; // COM13: Gamma Enable
            
            default: current_reg = END_MARKER;
        endcase
    end

    localparam RESET_WAIT = 200_000;

    reg [17:0] wait_cnt;

    localparam S_RESET_WAIT = 2'd0;
    localparam S_START_TX   = 2'd1;
    localparam S_WAIT_DONE  = 2'd2;
    localparam S_DONE       = 2'd3;

    reg [1:0] state;

    always @(posedge clk) begin
        if (rst) begin
            state       <= S_RESET_WAIT;
            rom_idx     <= 7'd0;
            sccb_start  <= 1'b0;
            reg_addr    <= 8'd0;
            reg_data    <= 8'd0;
            cfg_done    <= 1'b0;
            wait_cnt    <= 18'd0;
        end else begin
            sccb_start <= 1'b0;

            case (state)
                S_RESET_WAIT: begin
                    if (wait_cnt == RESET_WAIT - 1) begin
                        wait_cnt <= 18'd0;
                        state    <= S_START_TX;
                    end else begin
                        wait_cnt <= wait_cnt + 18'd1;
                    end
                end

                S_START_TX: begin
                    if (current_reg == END_MARKER) begin
                        cfg_done <= 1'b1;
                        state    <= S_DONE;
                    end else begin
                        reg_addr   <= current_reg[15:8];
                        reg_data   <= current_reg[7:0];
                        sccb_start <= 1'b1;
                        state      <= S_WAIT_DONE;

                        if (rom_idx == 7'd0)
                            wait_cnt <= 18'd0;
                    end
                end

                S_WAIT_DONE: begin
                    if (sccb_done) begin
                        rom_idx  <= rom_idx + 7'd1;
                        wait_cnt <= 18'd0;
                        state    <= S_RESET_WAIT;
                    end
                end

                S_DONE: begin
                    cfg_done <= 1'b1;
                end

                default: state <= S_RESET_WAIT;
            endcase
        end
    end

endmodule
