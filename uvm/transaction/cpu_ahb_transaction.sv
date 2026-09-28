typedef enum bit {
    AHB_READ,
    AHB_WRITE
} ahb_direction_e;

class cpu_ahb_transaction extends uvm_sequence_item;

    //request field
    rand ahb_direction_e direction;
    rand logic [31:0] address;
    rand logic [31:0] write_data;

    //response field
    logic [31:0] read_data;
    logic   response;

    constraint word_aligned_c {
        address[1:0] == 2'b00;
    }

    `uvm_object_utils_begin (cpu_ahb_transaction)
        `uvm_field_enum (ahb_direction_e, direction, UVM_DEFAULT)
        `uvm_field_int (address, UVM_HEX)
        `uvm_field_int (write_data, UVM_HEX)
        `uvm_field_int (read_data, UVM_HEX)
        `uvm_field_int (response, UVM_DEFAULT)
    `uvm_object_utils_end

    function new(string name="cpu_ahb_transaction");
        super.new(name);
    endfunction
endclass