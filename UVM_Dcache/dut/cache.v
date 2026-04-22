// cache.v — write-through + no-write-allocate
// Fix 1: data_table written only in sequential block
// Fix 2: write-hit waits for mem_ready (S_MISS_WR)
// Fix 3: address/data latched on state entry
module cache (
    input  wire        clk,
    input  wire        reset,

    // CPU side
    input  wire [31:0] cpu_addr,
    input  wire [31:0] cpu_wdata,
    input  wire        data_req,
    input  wire        data_we,
    input  wire [3:0]  data_be,
    output reg  [31:0] cpu_rdata,
    output reg         data_rvalid,
    output reg         data_gnt,
    output reg         cpu_stall,

    // Cache → Interface
    output reg  [31:0]  mem_addr_block,
    output reg  [31:0]  mem_addr,
    output reg          mem_read,
    output reg          mem_write,
    output reg  [255:0] mem_wdata_block,
    output reg  [31:0]  miss_mem_wdata,

    // Interface → Cache
    input  wire [255:0] mem_rdata_array,
    input  wire         mem_ready,

    output reg  [2:0]   state
);

    localparam WORDS_PER_BLOCK = 8;
    localparam INDEX_W = 6;
    localparam TAG_W   = 21;

    reg [TAG_W-1:0] tag_table   [0:63];
    reg             valid_table [0:63];
    reg [31:0]      data_table  [0:63][0:7];

    wire [TAG_W-1:0]   tag   = cpu_addr[31:11];
    wire [INDEX_W-1:0] index = cpu_addr[10:5];
    wire [2:0]         woff  = cpu_addr[4:2];

    localparam S_IDLE    = 3'd0;
    localparam S_MISS_RD = 3'd1;
    localparam S_MISS_WR = 3'd2;

    reg [2:0] cs, ns;

    reg [INDEX_W-1:0] miss_idx;
    reg [TAG_W-1:0]   miss_tag;
    reg [2:0]         miss_woff;
    reg [31:0]        base_addr;
    reg [31:0]        miss_addr;
    reg [31:0]        miss_wdata;

    integer i;

    // ====================================================
    // SEQUENTIAL
    // ====================================================
    always @(posedge clk) begin
        if (reset) begin
            cs    <= S_IDLE;
            state <= S_IDLE;
            cpu_rdata <= 0;
            for (i = 0; i < 64; i = i + 1)
                valid_table[i] <= 0;
        end else begin
            cs    <= ns;
            state <= ns;

            // Latch context entering S_MISS_RD
            if (cs == S_IDLE && ns == S_MISS_RD) begin
                miss_idx  <= index;
                miss_tag  <= tag;
                miss_woff <= woff;
                base_addr <= {cpu_addr[31:5], 5'b0};
            end

            // Latch context entering S_MISS_WR
            if (cs == S_IDLE && ns == S_MISS_WR) begin
                miss_idx   <= index;
                miss_tag   <= tag;
                miss_woff  <= woff;
                miss_addr  <= cpu_addr & 32'hFFFF_FFFC;
                miss_wdata <= cpu_wdata;
                // Write hit: update data_table
                if (valid_table[index] && tag_table[index] == tag)
                    data_table[index][woff] <= cpu_wdata;
            end

            // Fill cache on read miss
            if (cs == S_MISS_RD && mem_ready) begin
                for (i = 0; i < WORDS_PER_BLOCK; i = i + 1)
                    data_table[miss_idx][i] <= mem_rdata_array[(i*32)+:32];
                tag_table[miss_idx]   <= miss_tag;
                valid_table[miss_idx] <= 1;
            end
        end
    end

    // ====================================================
    // COMBINATIONAL
    // ====================================================
    always @* begin
        ns = cs;

        data_rvalid     = 0;
        data_gnt        = 0;
        cpu_stall       = 0;
        cpu_rdata       = 0;

        mem_read        = 0;
        mem_write       = 0;
        mem_addr_block  = 0;
        mem_addr        = 0;
        mem_wdata_block = 0;
        miss_mem_wdata  = 0;

        case (cs)

        S_IDLE: begin
            if (data_req) begin
                if (!data_we) begin
                    if (valid_table[index] && tag_table[index] == tag) begin
                        // READ HIT
                        data_gnt    = 1;
                        data_rvalid = 1;
                        cpu_rdata   = data_table[index][woff];
                    end else begin
                        // READ MISS
                        cpu_stall      = 1;
                        mem_read       = 1;
                        mem_addr_block = {cpu_addr[31:5], 5'b0};
                        ns             = S_MISS_RD;
                    end
                end else begin
                    // WRITE (hit or miss) — write-through, always go to mem
                    cpu_stall      = 1;
                    mem_write      = 1;
                    mem_addr       = cpu_addr & 32'hFFFF_FFFC;
                    miss_mem_wdata = cpu_wdata;
                    ns             = S_MISS_WR;
                end
            end
        end

        S_MISS_RD: begin
            cpu_stall      = 1;
            mem_read       = 1;
            mem_addr_block = base_addr;
            if (mem_ready) begin
                data_gnt    = 1;
                data_rvalid = 1;
                cpu_rdata   = mem_rdata_array[(miss_woff*32)+:32];
                cpu_stall   = 0;
                ns          = S_IDLE;
            end
        end

        S_MISS_WR: begin
            cpu_stall      = 1;
            mem_write      = 1;
            mem_addr       = miss_addr;
            miss_mem_wdata = miss_wdata;
            if (mem_ready) begin
                data_gnt  = 1;
                cpu_stall = 0;
                ns        = S_IDLE;
            end
        end

        default: ns = S_IDLE;
        endcase
    end

endmodule