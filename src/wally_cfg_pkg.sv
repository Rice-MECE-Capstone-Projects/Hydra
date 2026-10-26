// Define global parameters
`include "config.vh"

package wally_cfg_pkg;
    import cvw::*;
    
    // Assign the global parameters to a cvw_t localparam, P
    `include "parameter-defs.vh" 
    
    // Create an exported parameter pointing to it
    parameter cvw_t TOP_P = P; 
endpackage
