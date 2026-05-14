// Write-only SCCB master for OV7670 register configuration.
// A transaction sends START, device write byte, register address, data, and STOP.
// SDA is driven through top-level open-drain logic; this module does not sample
// the external SDA pin for a real ACK.

module sccb_master #(
    parameter CLK_FREQ   = 100_000_000,  // system clock frequency in Hz
    parameter SCCB_FREQ  = 100_000       // target SCCB clock in Hz
) (
    input  wire       clk,
    input  wire       rst,

    input  wire       start,
    input  wire [6:0] dev_addr,
    input  wire [7:0] reg_addr,
    input  wire [7:0] reg_data,

    output reg        scl,
    output reg        sda,

    output reg        done,
    output reg        busy,
    output reg        ack_err    // Legacy diagnostic; not a true external ACK check.
);

    // One SCL period is four ticks so SDA can change while SCL is low.
    localparam CLK_DIV = CLK_FREQ / (SCCB_FREQ * 4);

    reg [$clog2(CLK_DIV+1)-1:0] clk_cnt;
    reg                          tick;

    always @(posedge clk) begin
        if (rst) begin
            clk_cnt <= 0;
            tick    <= 1'b0;
        end else begin
            tick <= 1'b0;
            if (clk_cnt == CLK_DIV - 1) begin
                clk_cnt <= 0;
                tick    <= 1'b1;
            end else begin
                clk_cnt <= clk_cnt + 1;
            end
        end
    end

    localparam ST_IDLE      = 4'd0;
    localparam ST_START     = 4'd1;  // START condition
    localparam ST_ID        = 4'd2;  // device address + write bit
    localparam ST_DC_ID     = 4'd3;  // SCCB don't-care bit
    localparam ST_REG       = 4'd4;  // register address
    localparam ST_DC_REG    = 4'd5;
    localparam ST_DATA      = 4'd6;  // register data
    localparam ST_DC_DATA   = 4'd7;
    localparam ST_STOP      = 4'd8;
    localparam ST_DONE      = 4'd9;

    reg [3:0]  state;
    reg [3:0]  bit_cnt;
    reg [1:0]  phase;
    reg [7:0]  tx_byte;

    wire [7:0] id_byte = {dev_addr, 1'b0};

    always @(posedge clk) begin
        if (rst) begin
            state   <= ST_IDLE;
            scl     <= 1'b1;
            sda     <= 1'b1;
            done    <= 1'b0;
            busy    <= 1'b0;
            ack_err <= 1'b0;
            bit_cnt <= 4'd7;
            phase   <= 2'd0;
            tx_byte <= 8'd0;
        end else begin
            done <= 1'b0;

            case (state)
                ST_IDLE: begin
                    scl     <= 1'b1;
                    sda     <= 1'b1;
                    busy    <= 1'b0;
                    ack_err <= 1'b0;
                    if (start) begin
                        busy    <= 1'b1;
                        tx_byte <= id_byte;
                        bit_cnt <= 4'd7;
                        phase   <= 2'd0;
                        state   <= ST_START;
                    end
                end

                ST_START: begin
                    if (tick) begin
                        case (phase)
                            2'd0: begin scl <= 1'b1; sda <= 1'b1; phase <= 2'd1; end
                            2'd1: begin sda <= 1'b0; phase <= 2'd2; end
                            2'd2: begin scl <= 1'b0; phase <= 2'd3; end
                            2'd3: begin
                                phase   <= 2'd0;
                                bit_cnt <= 4'd7;
                                tx_byte <= id_byte;
                                state   <= ST_ID;
                            end
                        endcase
                    end
                end

                // Shared byte transmitter for ID, register address, and data.
                ST_ID, ST_REG, ST_DATA: begin
                    if (tick) begin
                        case (phase)
                            2'd0: begin scl <= 1'b0; phase <= 2'd1; end
                            2'd1: begin sda <= tx_byte[bit_cnt]; phase <= 2'd2; end
                            2'd2: begin scl <= 1'b1; phase <= 2'd3; end
                            2'd3: begin
                                phase <= 2'd0;
                                if (bit_cnt == 4'd0) begin
                                    case (state)
                                        ST_ID:   state <= ST_DC_ID;
                                        ST_REG:  state <= ST_DC_REG;
                                        ST_DATA: state <= ST_DC_DATA;
                                        default: state <= ST_STOP;
                                    endcase
                                end else begin
                                    bit_cnt <= bit_cnt - 4'd1;
                                end
                            end
                        endcase
                    end
                end

                // SCCB has a don't-care 9th bit. ack_err is retained for the
                // old interface but only observes this internal SDA register.
                ST_DC_ID, ST_DC_REG, ST_DC_DATA: begin
                    if (tick) begin
                        case (phase)
                            2'd0: begin scl <= 1'b0; sda <= 1'b1; phase <= 2'd1; end
                            2'd1: begin phase <= 2'd2; end
                            2'd2: begin 
                                scl <= 1'b1; 
                                phase <= 2'd3;
                                if (sda == 1'b1) begin
                                    ack_err <= 1'b1;
                                end
                            end
                            2'd3: begin
                                phase   <= 2'd0;
                                scl     <= 1'b0;
                                bit_cnt <= 4'd7;
                                case (state)
                                    ST_DC_ID: begin
                                        tx_byte <= reg_addr;
                                        state   <= ST_REG;
                                    end
                                    ST_DC_REG: begin
                                        tx_byte <= reg_data;
                                        state   <= ST_DATA;
                                    end
                                    ST_DC_DATA: state <= ST_STOP;
                                    default:    state <= ST_STOP;
                                endcase
                            end
                        endcase
                    end
                end

                ST_STOP: begin
                    if (tick) begin
                        case (phase)
                            2'd0: begin scl <= 1'b0; sda <= 1'b0; phase <= 2'd1; end
                            2'd1: begin scl <= 1'b1; phase <= 2'd2; end
                            2'd2: begin sda <= 1'b1; phase <= 2'd3; end
                            2'd3: begin
                                phase <= 2'd0;
                                state <= ST_DONE;
                            end
                        endcase
                    end
                end

                ST_DONE: begin
                    done  <= 1'b1;
                    busy  <= 1'b0;
                    state <= ST_IDLE;
                end

                default: state <= ST_IDLE;
            endcase
        end
    end

endmodule
