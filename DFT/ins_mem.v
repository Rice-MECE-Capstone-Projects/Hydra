module ins_mem (
    input  wire         clk,
    input  wire         reset,

    input  wire [31:0]  pc_i,
    input  wire         pc_i_valid, // request valid from PC

    output wire         STALL_IF_not_ready_w, // stall signal for IF stage (PC module is stalled)
    output wire         STALL_ID_not_ready_w, // stall signal for DECO stage (Decode module is stalled, exec doesnt get new value)
    output wire [31:0]  instruction_o_w,

    input  wire         stall_i_EXEC,
    input  wire         abort_rvalid,

    // Memory interface
    output wire         data_req_o_w,
    output wire [31:0]  data_addr_o_w,
    output wire         data_we_o_w,
    output wire [3:0]   data_be_o_w,
    output wire [31:0]  data_wdata_o_w,

    input  wire [31:0]  data_rdata_i,
    input  wire         data_rvalid_i,
    input  wire         data_gnt_i
);

    // Internal regs driven by FSM (combinational)
    reg          data_req_o;
    reg [31:0]   data_addr_o;

    reg          STALL_IF_not_ready;
    reg          STALL_ID_not_ready;
    reg [31:0]   instruction_o;

    // Backup logic for EXEC stall corner case
    reg [31:0]   instruction_o_backup;
    reg          saved_instruction_from_stall;
    reg          prev_cycle_stall_ID;

    // FSM states
    localparam [1:0] S_IDLE         = 2'b00,
                     S_WAIT_GNT     = 2'b01,
                     S_WAIT_RVALID  = 2'b10,
                     S_ABORT_RVALID = 2'b11;

    reg [1:0] current_state, next_state;

    // (Optional bookkeeping regs you had; harmless to keep)
    reg [31:0] pc_decode;
    reg [31:0] current_PC_wating_rvalid;
    reg [31:0] PC_requested;

    // Constant “read-only” memory interface (instruction fetch = read)
    assign data_we_o_w    = 1'b0;        // FIX: must be 1-bit, not 32'b0
    assign data_be_o_w    = 4'b1111;
    assign data_wdata_o_w = 32'b0;

    assign data_req_o_w   = data_req_o;
    assign data_addr_o_w  = data_addr_o;

    assign STALL_IF_not_ready_w = STALL_IF_not_ready;
    assign STALL_ID_not_ready_w = STALL_ID_not_ready;

    wire backup_used;
    assign backup_used = (~stall_i_EXEC) && saved_instruction_from_stall;

    assign instruction_o_w =
        (saved_instruction_from_stall) ? instruction_o_backup : instruction_o;

    // New request qualification
    wire new_request_from_PC_accept;
    assign new_request_from_PC_accept =
        pc_i_valid && (~abort_rvalid) && (~stall_i_EXEC);

    // ============================================================
    // Combinational next-state + outputs
    // ============================================================
    always @(*) begin
        // Defaults to avoid latches
        data_req_o         = 1'b0;
        data_addr_o        = 32'h0;
        STALL_IF_not_ready = 1'b0;
        STALL_ID_not_ready = 1'b0;
        instruction_o      = 32'h00000013; // NOP
        next_state         = current_state;

        case (current_state)
            S_IDLE: begin
                // Can accept a new request
                if (new_request_from_PC_accept) begin
                    data_req_o  = 1'b1;
                    data_addr_o = pc_i;

                    if (data_gnt_i) begin
                        // request accepted, wait for rvalid
                        STALL_IF_not_ready = 1'b0;
                        STALL_ID_not_ready = 1'b0;
                        next_state         = S_WAIT_RVALID;
                    end else begin
                        // wait for grant, stall IF (PC)
                        STALL_IF_not_ready = 1'b1;
                        STALL_ID_not_ready = 1'b0;
                        next_state         = S_WAIT_GNT;
                    end
                end else begin
                    // no request
                    next_state = S_IDLE;
                end
            end

            S_WAIT_GNT: begin
                // Waiting for grant, do not accept new request if EXEC stalled
                if (~abort_rvalid) begin
                    if (~stall_i_EXEC) begin
                        data_req_o  = 1'b1;
                        data_addr_o = pc_i;

                        if (data_gnt_i) begin
                            STALL_IF_not_ready = 1'b0;
                            STALL_ID_not_ready = 1'b0;
                            next_state         = S_WAIT_RVALID;
                        end else begin
                            STALL_IF_not_ready = 1'b1;
                            STALL_ID_not_ready = 1'b0;
                            next_state         = S_WAIT_GNT;
                        end
                    end else begin
                        // EXEC stall: keep IF stalled to avoid issuing
                        STALL_IF_not_ready = 1'b1;
                        STALL_ID_not_ready = 1'b0;
                        next_state         = S_WAIT_GNT;
                    end
                end else begin
                    // branch/jump abort: drop request and go idle
                    next_state = S_IDLE;
                end
            end

            S_WAIT_RVALID: begin
                if (~abort_rvalid) begin
                    if (data_rvalid_i) begin
                        // got instruction
                        instruction_o = data_rdata_i;

                        if (~stall_i_EXEC) begin
                            // Can potentially issue next request immediately
                            if (pc_i_valid) begin
                                data_req_o  = 1'b1;
                                data_addr_o = pc_i;

                                if (data_gnt_i) begin
                                    STALL_IF_not_ready = 1'b0;
                                    STALL_ID_not_ready = 1'b0;
                                    next_state         = S_WAIT_RVALID;
                                end else begin
                                    STALL_IF_not_ready = 1'b1;
                                    STALL_ID_not_ready = 1'b0;
                                    next_state         = S_WAIT_GNT;
                                end
                            end else begin
                                next_state = S_IDLE;
                            end
                        end else begin
                            // EXEC stalls right when rvalid arrives:
                            // stall both IF/ID (ID can't advance)
                            STALL_IF_not_ready = 1'b1;
                            STALL_ID_not_ready = 1'b1;
                            next_state         = S_IDLE; // FSM can idle; backup handles returning inst
                        end
                    end else begin
                        // still waiting for rvalid: stall ID
                        STALL_IF_not_ready = 1'b0;
                        STALL_ID_not_ready = 1'b1;
                        next_state         = S_WAIT_RVALID;
                    end
                end else begin
                    // abort during outstanding request
                    instruction_o = 32'h00000013;
                    if (data_rvalid_i) begin
                        next_state = S_IDLE;
                    end else begin
                        next_state = S_ABORT_RVALID;
                    end
                end
            end

            S_ABORT_RVALID: begin
                // waiting for rvalid to throw away old data
                instruction_o = 32'h00000013;

                if (data_rvalid_i && ~stall_i_EXEC) begin
                    // old request satisfied (discard), can accept new
                    if (pc_i_valid) begin
                        data_req_o  = 1'b1;
                        data_addr_o = pc_i;

                        if (data_gnt_i) begin
                            STALL_IF_not_ready = 1'b0;
                            STALL_ID_not_ready = 1'b0;
                            next_state         = S_WAIT_RVALID;
                        end else begin
                            STALL_IF_not_ready = 1'b1;
                            STALL_ID_not_ready = 1'b0;
                            next_state         = S_WAIT_GNT;
                        end
                    end else begin
                        next_state = S_IDLE;
                    end
                end else begin
                    // keep stalling IF while flushing old request
                    STALL_IF_not_ready = 1'b1;
                    STALL_ID_not_ready = 1'b0;
                    next_state         = S_ABORT_RVALID;
                end
            end

            default: begin
                next_state = S_IDLE;
            end
        endcase
    end

    // ============================================================
    // Sequential state + backup capture
    // ============================================================
    always @(posedge clk) begin
        if (reset) begin
            current_state                <= S_IDLE;
            instruction_o_backup         <= 32'h00000013;
            PC_requested                 <= 32'h0;
            saved_instruction_from_stall <= 1'b0;
            prev_cycle_stall_ID          <= 1'b0;

            pc_decode                    <= 32'h0;
            current_PC_wating_rvalid     <= 32'h0;
        end else begin
            current_state       <= next_state;
            prev_cycle_stall_ID <= STALL_ID_not_ready;

            // Capture the returning instruction if EXEC stalls when rvalid arrives
            if (current_state == S_WAIT_RVALID) begin
                if (pc_i_valid && stall_i_EXEC && ~abort_rvalid && data_rvalid_i) begin
                    instruction_o_backup         <= data_rdata_i;
                    saved_instruction_from_stall <= 1'b1;
                end
            end

            // Once EXEC is free and we used backup, clear it
            if (backup_used) begin
                instruction_o_backup         <= 32'h00000013;
                saved_instruction_from_stall <= 1'b0;
            end
        end
    end

endmodule