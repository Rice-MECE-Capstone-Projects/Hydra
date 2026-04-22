module data_cache_interface (
    input  wire        clk,
    input  wire        reset,
    
    // Cache side (burst interface)
    input  wire [31:0] cache_mem_addr_block,
    input  wire [31:0] cache_mem_addr,
    input  wire        cache_mem_read,
    input  wire        cache_mem_write,
    input  wire [255:0] cache_mem_wdata_block,
    input  wire [31:0]  cache_miss_mem_wdata,
    output wire [255:0] cache_mem_rdata_array,
    output reg          cache_mem_ready,

    // Memory side (word interface)
    output reg  [31:0] mem_addr,
    output reg         mem_read,
    output reg         mem_write,
    output reg  [31:0] mem_wdata,
    input  wire [31:0] mem_rdata,
    input  wire        mem_valid
);

    localparam IDLE=2'b00, BURST_READ=2'b01, BURST_WRITE=2'b10, SINGLE_WRITE=2'b11;
    reg [1:0] state, next_state;

    reg [2:0]  beat_q, beat_d;
    reg [31:0] base_addr_q;
    reg [31:0] req_addr_q;
    reg [31:0] sw_addr_q;
    reg [31:0] sw_data_q;
    reg [255:0] read_buffer;

    reg cache_mem_ready_d;

    assign cache_mem_rdata_array = read_buffer;

    wire is_block_write  = cache_mem_write && (cache_mem_wdata_block != 256'b0);
    wire is_single_write = cache_mem_write && (cache_mem_wdata_block == 256'b0);

    // ======================
    // Sequential — single always block
    // ======================
    always @(posedge clk) begin
        if (reset) begin
            state           <= IDLE;
            beat_q          <= 3'd0;
            base_addr_q     <= 32'b0;
            req_addr_q      <= 32'b0;
            read_buffer     <= 256'b0;
            cache_mem_ready <= 1'b0;
            sw_addr_q       <= 32'b0;
            sw_data_q       <= 32'b0;
        end else begin
            state           <= next_state;
            cache_mem_ready <= cache_mem_ready_d;
            req_addr_q      <= mem_addr;

            // burst read: store returning data
            if (state == BURST_READ && mem_valid) begin
                read_buffer[(((req_addr_q - base_addr_q) >> 2) * 32) +: 32] <= mem_rdata;
            end

            // latch address/data when entering SINGLE_WRITE
            if (state == IDLE && next_state == SINGLE_WRITE) begin
                sw_addr_q <= cache_mem_addr;
                sw_data_q <= cache_miss_mem_wdata;
            end

            // beat counter and base address management
            if (state == IDLE && (next_state == BURST_READ || next_state == BURST_WRITE)) begin
                base_addr_q <= cache_mem_addr_block;
                beat_q      <= 3'd1;
            end else if (next_state == IDLE) begin
                beat_q <= 3'd1;
            end else begin
                beat_q <= beat_d;
            end
        end
    end

    // ======================
    // Combinational
    // ======================
    always @* begin
        next_state        = state;
        cache_mem_ready_d = 1'b0;
        mem_addr          = 32'b0;
        mem_read          = 1'b0;
        mem_write         = 1'b0;
        mem_wdata         = 32'b0;
        beat_d            = beat_q;

        case (state)
            IDLE: begin
                if (cache_mem_read) begin
                    next_state = BURST_READ;
                    mem_addr   = cache_mem_addr_block;
                    mem_read   = 1'b1;
                end else if (is_block_write) begin
                    next_state = BURST_WRITE;
                    mem_addr   = cache_mem_addr_block;
                    mem_write  = 1'b1;
                    mem_wdata  = cache_mem_wdata_block[31:0];
                end else if (is_single_write) begin
                    next_state = SINGLE_WRITE;
                    mem_addr   = cache_mem_addr;
                    mem_write  = 1'b1;
                    mem_wdata  = cache_miss_mem_wdata;
                end
            end

            BURST_READ: begin
                mem_read = 1'b1;
                mem_addr = base_addr_q + (beat_q << 2);
                if (mem_valid) begin
                    if (beat_q == 3'd7) begin
                        cache_mem_ready_d = 1'b1;
                        next_state        = IDLE;
                    end else begin
                        beat_d = beat_q + 3'd1;
                    end
                end
            end

            BURST_WRITE: begin
                mem_write = 1'b1;
                mem_addr  = base_addr_q + (beat_q << 2);
                mem_wdata = cache_mem_wdata_block[(beat_q*32) +: 32];
                if (mem_valid) begin
                    if (beat_q == 3'd7) begin
                        cache_mem_ready_d = 1'b1;
                        next_state        = IDLE;
                    end else begin
                        beat_d = beat_q + 3'd1;
                    end
                end
            end

            SINGLE_WRITE: begin
                mem_write = 1'b1;
                mem_addr  = sw_addr_q;
                mem_wdata = sw_data_q;
                if (mem_valid) begin
                    cache_mem_ready_d = 1'b1;
                    next_state        = IDLE;
                end
            end
        endcase
    end

endmodule