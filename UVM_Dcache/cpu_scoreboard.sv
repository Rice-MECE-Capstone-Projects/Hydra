class cpu_scoreboard extends uvm_component;
  `uvm_component_utils(cpu_scoreboard)

  uvm_analysis_imp #(cpu_sequence_item, cpu_scoreboard) imp;

  // =========================
  // Memory model
  // =========================
  logic [31:0] ref_mem [0:4095]; // word address

  // =========================
  // Cache reference model
  // =========================
  localparam NUM_LINES = 64;
  localparam WORDS_PER_BLOCK = 8;

  bit valid [NUM_LINES];
  bit [20:0] tag [NUM_LINES];              
  logic [31:0] data [NUM_LINES][WORDS_PER_BLOCK];

  // =========================
  // Coverage
  // =========================
  bit cov_we;
  bit cov_hit;

  covergroup cg;
    cp_rw  : coverpoint cov_we  { bins READ = {0}; bins WRITE = {1}; }
    cp_hit : coverpoint cov_hit { bins HIT  = {1}; bins MISS  = {0}; }
    cp_cross : cross cp_rw, cp_hit;
  endgroup

  // =========================
  // Constructor
  // =========================
  function new(string name="cpu_scoreboard", uvm_component parent=null);
    super.new(name, parent);
    imp = new("imp", this);
    cg  = new();
  endfunction

  // =========================
  // Build Phase
  // =========================
  function void build_phase(uvm_phase phase);
    super.build_phase(phase);

    $readmemh("memory_dump.hex", ref_mem);
    foreach (valid[i]) valid[i] = 0;

    `uvm_info("SCB", "Memory + Cache model initialized", UVM_LOW)
  endfunction

  // ============================================================
  // MAIN CHECK
  // ============================================================
  virtual function void write(cpu_sequence_item tr);

    int index, word_idx, woff;
    bit [20:0] tag_in;
    int base_word;

    logic [31:0] exp;
    bit is_hit;

    // decode address
    index     = tr.addr[10:5];
    woff      = tr.addr[4:2];
    tag_in    = tr.addr[31:11];
    word_idx  = tr.addr >> 2;
    base_word = (tr.addr >> 5) << 3;

    // address check
    if (word_idx < 0 || word_idx >= 4096) begin
      `uvm_error("SCB", $sformatf("Addr OOB: %h", tr.addr))
      return;
    end

    // hit
    is_hit = valid[index] && (tag[index] == tag_in);

    // =========================
    // Coverage
    // =========================
    cov_we  = tr.we;
    cov_hit = is_hit;
    cg.sample();

    // ============================================================
    // WRITE
    // ============================================================
    if (tr.we) begin
      ref_mem[word_idx] = tr.wdata;

      if (is_hit) begin
        data[index][woff] = tr.wdata;
        `uvm_info("SCB",
          $sformatf("WRITE: Addr=%h Data=%h Type: HIT", tr.addr, tr.wdata),
          UVM_LOW)
      end else begin
        `uvm_info("SCB",
          $sformatf("WRITE: Addr=%h Data=%h Type: MISS", tr.addr, tr.wdata),
          UVM_LOW)
      end
      return;
    end

    // ============================================================
    // READ
    // ============================================================
    if (is_hit) begin
      exp = data[index][woff];
    end else begin
      // refill
      for (int i = 0; i < WORDS_PER_BLOCK; i++) begin
        data[index][i] = ref_mem[base_word + i];
      end

      tag[index]   = tag_in;
      valid[index] = 1;

      exp = ref_mem[word_idx];
    end

    // =========================
    // CHECK
    // =========================
    if (tr.rdata !== exp) begin
      `uvm_error("SCB",
        $sformatf("DATA MISMATCH! Addr:%h Exp:%h Got:%h (hit=%0d)",
                  tr.addr, exp, tr.rdata, is_hit))
    end else begin
      `uvm_info("SCB",
        $sformatf("READ PASS: Addr:%h Data:%h Type:%s",
                  tr.addr, tr.rdata, is_hit ? "HIT" : "MISS"),
        UVM_LOW)
    end

  endfunction


  // =========================
  // COVERAGE REPORT
  // =========================
  function void report_phase(uvm_phase phase);
    super.report_phase(phase);
    
    $display(">>> ENTER REPORT PHASE <<<");

    $display("=================================");
    $display("FUNCTIONAL COVERAGE = %0.2f%%", cg.get_coverage());
    $display("=================================");

  endfunction

endclass