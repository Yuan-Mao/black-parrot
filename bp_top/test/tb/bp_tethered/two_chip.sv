
`include "bsg_noc_links.vh"
`include "bp_common_defines.svh"

module two_chip
 import bp_common_pkg::*;
 import bp_be_pkg::*;
 import bp_me_pkg::*;
 import bsg_noc_pkg::*;
 #(  parameter icache_trace_p              = 0
   , parameter dcache_trace_p              = 0
   , parameter lce_trace_p                 = 0
   , parameter cce_trace_p                 = 0
   , parameter dram_trace_p                = 0
   , parameter vm_trace_p                  = 0
   , parameter cmt_trace_p                 = 0
   , parameter core_profile_p              = 0
   , parameter pc_profile_p                = 0
   , parameter br_profile_p                = 0
   , parameter cosim_p                     = 0

   // COSIM parameters
   , parameter checkpoint_p                = 0
   , parameter cosim_memsize_p             = 0
   , parameter cosim_cfg_file_p            = "prog.cfg"
   , parameter cosim_instr_p               = 0
   , parameter warmup_instr_p              = 0
   , parameter amo_en_p                    = 0

   , parameter preload_mem_p               = 0

   // Synthesis parameters
   , parameter no_bind_p                   = 0

   )
   (
     output bit reset_o
   );

    logic [3:0] tb1_mii_txd_li;
    logic       tb1_mii_tx_en_li;
    logic       tb1_mii_tx_er_li;
    logic [3:0] tb2_mii_txd_li;
    logic       tb2_mii_tx_en_li;
    logic       tb2_mii_tx_er_li;

    testbench
    #(
        .icache_trace_p(icache_trace_p)
        ,.dcache_trace_p(dcache_trace_p)
        ,.lce_trace_p(lce_trace_p)
        ,.cce_trace_p(cce_trace_p)
        ,.dram_trace_p(dram_trace_p)
        ,.vm_trace_p(vm_trace_p)
        ,.cmt_trace_p(cmt_trace_p)
        ,.core_profile_p(core_profile_p)
        ,.pc_profile_p(pc_profile_p)
        ,.br_profile_p(br_profile_p)
        ,.cosim_p(cosim_p)

        ,.checkpoint_p(checkpoint_p)
        ,.cosim_memsize_p(cosim_memsize_p)
        ,.cosim_cfg_file_p(cosim_cfg_file_p)
        ,.cosim_instr_p(cosim_instr_p)
        ,.warmup_instr_p(warmup_instr_p)
        ,.amo_en_p(amo_en_p)

        ,.preload_mem_p(preload_mem_p)

        ,.no_bind_p(no_bind_p)

        ,.nbf_filename_p("prog1.nbf")
    ) tb1
    (
        .chip_id_i(1'b0)
        ,.mii_txd_i(tb1_mii_txd_li)
        ,.mii_tx_en_i(tb1_mii_tx_en_li)
        ,.mii_tx_er_i(tb1_mii_tx_er_li)
        ,.mii_rxd_o(tb2_mii_txd_li)
        ,.mii_rx_dv_o(tb2_mii_tx_en_li)
        ,.mii_rx_er_o(tb2_mii_tx_er_li)

        ,.reset_o(reset_o)
    );

    testbench
    #(
        ,.icache_trace_p(icache_trace_p)
        ,.dcache_trace_p(dcache_trace_p)
        ,.lce_trace_p(lce_trace_p)
        ,.cce_trace_p(cce_trace_p)
        ,.dram_trace_p(dram_trace_p)
        ,.vm_trace_p(vm_trace_p)
        ,.cmt_trace_p(cmt_trace_p)
        ,.core_profile_p(core_profile_p)
        ,.pc_profile_p(pc_profile_p)
        ,.br_profile_p(br_profile_p)
        ,.cosim_p(cosim_p)

        ,.checkpoint_p(checkpoint_p)
        ,.cosim_memsize_p(cosim_memsize_p)
        ,.cosim_cfg_file_p(cosim_cfg_file_p)
        ,.cosim_instr_p(cosim_instr_p)
        ,.warmup_instr_p(warmup_instr_p)
        ,.amo_en_p(amo_en_p)

        ,.preload_mem_p(preload_mem_p)

        ,.no_bind_p(no_bind_p)

        ,.nbf_filename_p("prog2.nbf")
    ) tb2
    (
        .chip_id_i(1'b1)
        ,.mii_txd_i(tb2_mii_txd_li)
        ,.mii_tx_en_i(tb2_mii_tx_en_li)
        ,.mii_tx_er_i(tb2_mii_tx_er_li)
        ,.mii_rxd_o(tb1_mii_txd_li)
        ,.mii_rx_dv_o(tb1_mii_tx_en_li)
        ,.mii_rx_er_o(tb1_mii_tx_er_li)

        ,.reset_o(/* UNUSED */)
    );

endmodule
