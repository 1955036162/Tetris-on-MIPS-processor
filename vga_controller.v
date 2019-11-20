module vga_controller(  iRST_n,
                        iVGA_CLK,
                        key_in,
                        key_en,
                        // key_up,
                        // key_down,
                        // key_left,
                        // key_right,
                        oBLANK_n,
                        oHS,
                        oVS,
                        b_data,
                        g_data,
                        r_data);

    input [7:0] key_in;
    input key_en;
    input iRST_n;
    input iVGA_CLK;
    // input key_up, key_down, key_left, key_right;
    output reg oBLANK_n;
    output reg oHS;
    output reg oVS;
    output [7:0] b_data;
    output [7:0] g_data;  
    output [7:0] r_data;

///////////// wires
    wire [1:0] en_block; // en[0] for inner, en[1] for edge
    wire [9:0] addr_x, addr_y;
    wire VGA_CLK_n;
    wire [7:0] index;
    wire [23:0] bgr_data_raw;
    wire cBLANK_n, cHS, cVS, rst;
    wire [23:0] out;
    wire [23:0] bg_edge;

///////////// Registers
    reg [18:0] ADDR;
    reg [23:0] bgr_data;
    reg [9:0]  ref_x, ref_y;
    reg [23:0] counter;
    reg stop;
    reg [2:0] offsetLeft, offsetRight;
    reg [2:0] height;
    reg [2:0] blockType;

    parameter size = 16;

    // initialize x y register
    initial begin
        ref_x = 320;
        ref_y = 0;
        stop = 0;
        offsetLeft = 0;
        offsetRight = 0;
        height = 0;
    end

////
    assign rst = ~iRST_n;
    video_sync_generator LTM_ins (.vga_clk(iVGA_CLK),
                                  .reset(rst),
                                  .blank_n(cBLANK_n),
                                  .HS(cHS),
                                  .VS(cVS));
////

////Addresss generator
    always@(posedge iVGA_CLK, negedge iRST_n) begin
        if (!iRST_n)
             ADDR<=19'd0;
        else if (cHS==1'b0 && cVS==1'b0)
            ADDR<=19'd0;
        else if (cBLANK_n==1'b1)
            ADDR<=ADDR+1;
    end

    /*************************************
     * Pattern tests
     *************************************/
    // block block(addr_x, addr_y, ref_x, ref_y, en_block[0], en_block[1]);
    // square sq(addr_x, addr_y, ref_x, ref_y, en_block[0], en_block[1]);
    // longBar lb(addr_x, addr_y, ref_x, ref_y, en_block[0], en_block[1]);
    // TBar tb(addr_x, addr_y, ref_x, ref_y, en_block[0], en_block[1]);
    // ZBlock zb(addr_x, addr_y, ref_x, ref_y, en_block[0], en_block[1]);
    SBlock sb(addr_x, addr_y, ref_x, ref_y, en_block[0], en_block[1], 
                offsetLeft, offsetRight, height);

    // counter
    always@(posedge iVGA_CLK) begin
        if (counter == 10000000)
            counter <= 0;
        else
            counter = counter + 1;
    end

    // always@(posedge VGA_CLK_n) begin
    //     if(counter == 10000000) begin
    //         ref_y <= (ref_y + 16 == 480) ? 464 : ref_y + 16; // down
    //     end   
    // end

    // falling pieces
    always@(posedge VGA_CLK_n) begin
        if(counter == 10000000 && !stop) begin
            // ref_y <= (ref_y + height * size == 480) ? 480 - height * size : 
                    // ref_y + 16;
            ref_y <= ref_y + 16;
            stop  <= (ref_y + height * size == 480) ? 1 : 0;
        end
        else if(stop) begin
            ref_y = 0;
            stop = 0;
        end
    end

// key binding
    always@(posedge VGA_CLK_n) begin
        if ( key_en ) begin
            case(key_in)
                // 8'h75 : ref_y = (ref_y == 0) ? 0 : ref_y - 10;
                // 8'h72 : ref_y = ref_y + 16;
                8'h6b : ref_x = (ref_x - offsetLeft  * size == 240) ? 
                        240 + offsetLeft  * size : ref_x - 16;
                8'h74 : ref_x = (ref_x + offsetRight * size == 400) ? 
                        400 - offsetRight * size : ref_x + 16;
            endcase
        end
    end

//////////////////////////
//////INDEX addr.
    assign VGA_CLK_n = ~iVGA_CLK;
    img_data    img_data_inst (
        .address ( ADDR ),
        .clock ( VGA_CLK_n ),
        .q ( index )
        );

/////////////////////////
//////Add switch-input logic here
    decoder decode(ADDR, addr_x, addr_y); // ADDR => x, y coordinate

    // first edge, then block
    mux_24bit mux_block_edge (bgr_data_raw, 24'h000000, en_block[1], bg_edge);
    mux_24bit mux_block_inner(bg_edge,      24'h00004F, en_block[0], out);

//////Color table output
    img_index img_index_inst (
        .address ( index ),
        .clock ( iVGA_CLK ),
        .q ( bgr_data_raw )
        );
//////

//////latch valid data at falling edge;
    always@(posedge VGA_CLK_n) bgr_data <= out;
    assign b_data = bgr_data[23:16];
    assign g_data = bgr_data[15:8];
    assign r_data = bgr_data[7:0];
///////////////////

//////Delay the iHD, iVD,iDEN for one clock cycle;
    always@(negedge iVGA_CLK) begin
        oHS<=cHS;
        oVS<=cVS;
        oBLANK_n<=cBLANK_n;
    end

endmodule
