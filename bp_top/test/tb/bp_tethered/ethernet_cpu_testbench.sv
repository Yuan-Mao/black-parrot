/**
  *
  * testbench.v
  *
  */

`include "bsg_noc_links.vh"

`ifndef BP_SIM_CLK_PERIOD
`define BP_SIM_CLK_PERIOD 10
`endif

module ethernet_cpu_testbench
 import bp_common_pkg::*;
 import bp_be_pkg::*;
 import bp_me_pkg::*;
 import bsg_noc_pkg::*;
 #(parameter bp_params_e bp_params_p = BP_CFG_FLOWVAR // Replaced by the flow with a specific bp_cfg
   `declare_bp_proc_params(bp_params_p)
   `declare_bp_core_if_widths(vaddr_width_p, paddr_width_p, asid_width_p, branch_metadata_fwd_width_p)
   `declare_bp_bedrock_mem_if_widths(paddr_width_p, cce_block_width_p, lce_id_width_p, lce_assoc_p, cce)

   // TRACE enable parameters
   , parameter icache_trace_p              = 0
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

   // DRAM parameters
   , parameter dram_type_p                 = BP_DRAM_FLOWVAR // Replaced by the flow with a specific dram_type
   , parameter preload_mem_p               = 0

   // Synthesis parameters
   , parameter no_bind_p                   = 0

   , parameter nbf_filename_p              = "inv"
   )
  (
      input logic         chip_id_i
    , output logic        rgmii_tx_clk_o
    , output logic [3:0]  rgmii_txd_o
    , output logic        rgmii_tx_ctl_o

    , input logic         rgmii_rx_clk_i
    , input logic [3:0]   rgmii_rxd_i
    , input logic         rgmii_rx_ctl_i

    , output bit          reset_o
  );

  import "DPI-C" context function bit get_finish(int hartid);
  export "DPI-C" function get_dram_period;
  export "DPI-C" function get_sim_period;

  function int get_dram_period();
    return (`dram_pkg::tck_ps);
  endfunction

  function int get_sim_period();
    return (`BP_SIM_CLK_PERIOD);
  endfunction

  bit dram_clk_i, dram_reset_i;
  bit clkx2_lo;
  bit clk_lo;
  bit reset_lo;

  `ifdef VERILATOR
    bsg_nonsynth_dpi_clock_gen
  `else
    bsg_nonsynth_clock_gen
  `endif
   #(.cycle_time_p(`dram_pkg::tck_ps))
   dram_clock_gen
    (.o(dram_clk_i));
  
  bsg_nonsynth_reset_gen
   #(.num_clocks_p(1)
     ,.reset_cycles_lo_p(0)
     ,.reset_cycles_hi_p(10)
     )
   dram_reset_gen
    (.clk_i(dram_clk_i)
     ,.async_reset_o(dram_reset_i)
     );

  `ifdef VERILATOR
    bsg_nonsynth_dpi_clock_gen
  `else
    bsg_nonsynth_clock_gen
  `endif
   #(.cycle_time_p(`BP_SIM_CLK_PERIOD / 2))
   clock_gen
    (.o(clkx2_lo));

  bsg_nonsynth_reset_gen
   #(.num_clocks_p(1)
     ,.reset_cycles_lo_p(0)
     ,.reset_cycles_hi_p(20)
     )
   reset_gen
    (.clk_i(clk_lo)
     ,.async_reset_o(reset_lo)
     );

  `declare_bsg_cache_dma_pkt_s(caddr_width_p);
  bsg_cache_dma_pkt_s [num_cce_p-1:0] dma_pkt_lo;
  logic [num_cce_p-1:0] dma_pkt_v_lo, dma_pkt_yumi_li;
  logic [num_cce_p-1:0][l2_fill_width_p-1:0] dma_data_lo;
  logic [num_cce_p-1:0] dma_data_v_lo, dma_data_yumi_li;
  logic [num_cce_p-1:0][l2_fill_width_p-1:0] dma_data_li;
  logic [num_cce_p-1:0] dma_data_v_li, dma_data_ready_and_lo;

  assign reset_o = reset_lo;

  `declare_bp_bedrock_mem_if(paddr_width_p, cce_block_width_p, lce_id_width_p, lce_assoc_p, cce);

  bp_bedrock_cce_mem_msg_s nbf_io_cmd_lo;
  logic nbf_io_cmd_v_lo;
  logic nbf_io_cmd_yumi_li;
  bp_bedrock_cce_mem_msg_s nbf_io_resp_li;
  logic nbf_io_resp_v_li;
  logic nbf_io_resp_ready_lo;


  logic [cce_mem_msg_width_lp-1:0]   host_io_cmd_lo;
  logic                              host_io_cmd_v_lo;
  logic                              host_io_cmd_ready_and_li;

  logic [cce_mem_msg_width_lp-1:0]   host_io_resp_li;
  logic                              host_io_resp_v_li;
  logic                              host_io_resp_yumi_lo;

  ethernet_cpu_wrapper
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

        ,.nbf_filename_p(nbf_filename_p)
    ) dut
    (
        .clkx2_i(clkx2_lo)
        ,.clk_o(clk_lo)
        ,.reset_i(reset_lo)

        ,.rgmii_tx_clk_o(rgmii_tx_clk_o)
        ,.rgmii_txd_o(rgmii_txd_o)
        ,.rgmii_tx_ctl_o(rgmii_tx_ctl_o)

        ,.rgmii_rx_clk_i(rgmii_rx_clk_i)
        ,.rgmii_rxd_i(rgmii_rxd_i)
        ,.rgmii_rx_ctl_i(rgmii_rx_ctl_i)

        // DRAM interface
        ,.dma_pkt_o(dma_pkt_lo)
        ,.dma_pkt_v_o(dma_pkt_v_lo)
        ,.dma_pkt_yumi_i(dma_pkt_yumi_li)

        ,.dma_data_i(dma_data_li)
        ,.dma_data_v_i(dma_data_v_li)
        ,.dma_data_ready_and_o(dma_data_ready_and_lo)

        ,.dma_data_o(dma_data_lo)
        ,.dma_data_v_o(dma_data_v_lo)
        ,.dma_data_yumi_i(dma_data_yumi_li)

        // Host interface
        ,.host_io_cmd_o(host_io_cmd_lo)
        ,.host_io_cmd_v_o(host_io_cmd_v_lo)
        ,.host_io_cmd_ready_and_i(host_io_cmd_ready_and_li)
                                  
        ,.host_io_resp_i(host_io_resp_li)
        ,.host_io_resp_v_i(host_io_resp_v_li)
        ,.host_io_resp_yumi_o(host_io_resp_yumi_lo)

        ,.nbf_io_cmd_i(nbf_io_cmd_lo)
        ,.nbf_io_cmd_v_i(nbf_io_cmd_v_lo)
        ,.nbf_io_cmd_yumi_o(nbf_io_cmd_yumi_li)
                                  
        ,.nbf_io_resp_o(nbf_io_resp_li)
        ,.nbf_io_resp_v_o(nbf_io_resp_v_li)
        ,.nbf_io_resp_ready_and_i(nbf_io_resp_ready_lo)
    );

  bp_nonsynth_dram
   #(.bp_params_p(bp_params_p)
     ,.num_dma_p(num_cce_p)
     ,.preload_mem_p(preload_mem_p)
     ,.dram_type_p(dram_type_p)
     ,.mem_els_p(2**28)
     )
   dram
    (.clk_i(clk_lo)
     ,.reset_i(reset_lo)

     ,.dma_pkt_i(dma_pkt_lo)
     ,.dma_pkt_v_i(dma_pkt_v_lo)
     ,.dma_pkt_yumi_o(dma_pkt_yumi_li)

     ,.dma_data_o(dma_data_li)
     ,.dma_data_v_o(dma_data_v_li)
     ,.dma_data_ready_and_i(dma_data_ready_and_lo)

     ,.dma_data_i(dma_data_lo)
     ,.dma_data_v_i(dma_data_v_lo)
     ,.dma_data_yumi_o(dma_data_yumi_li)

     ,.dram_clk_i(dram_clk_i)
     ,.dram_reset_i(dram_reset_i)
     );

  logic cosim_en_lo;
  logic icache_trace_en_lo;
  logic dcache_trace_en_lo;
  logic lce_trace_en_lo;
  logic cce_trace_en_lo;
  logic dram_trace_en_lo;
  logic vm_trace_en_lo;
  logic cmt_trace_en_lo;
  logic core_profile_en_lo;
  logic pc_profile_en_lo;
  logic branch_profile_en_lo;
  bp_nonsynth_host
   #(.bp_params_p(bp_params_p)
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
     )
   host
    (.clk_i(clk_lo)
     ,.reset_i(reset_lo)

     ,.io_cmd_i(host_io_cmd_lo)
     ,.io_cmd_v_i(host_io_cmd_v_lo)
     ,.io_cmd_ready_and_o(host_io_cmd_ready_and_li)

     ,.io_resp_o(host_io_resp_li)
     ,.io_resp_v_o(host_io_resp_v_li)
     ,.io_resp_yumi_i(host_io_resp_yumi_lo)

     ,.icache_trace_en_o(icache_trace_en_lo)
     ,.dcache_trace_en_o(dcache_trace_en_lo)
     ,.lce_trace_en_o(lce_trace_en_lo)
     ,.cce_trace_en_o(cce_trace_en_lo)
     ,.dram_trace_en_o(dram_trace_en_lo)
     ,.vm_trace_en_o(vm_trace_en_lo)
     ,.cmt_trace_en_o(cmt_trace_en_lo)
     ,.core_profile_en_o(core_profile_en_lo)
     ,.branch_profile_en_o(branch_profile_en_lo)
     ,.pc_profile_en_o(pc_profile_en_lo)
     ,.cosim_en_o(cosim_en_lo)

     ,.chip_id_i(chip_id_i)
     );

  bp_nonsynth_nbf_loader
   #(.bp_params_p(bp_params_p)
    ,.nbf_filename_p(nbf_filename_p))
   nbf_loader
    (.clk_i(clk_lo)
     ,.reset_i(reset_lo)

     ,.lce_id_i(lce_id_width_p'('b10))

     ,.io_cmd_o(nbf_io_cmd_lo)
     ,.io_cmd_v_o(nbf_io_cmd_v_lo)
     ,.io_cmd_yumi_i(nbf_io_cmd_yumi_li)

     // NOTE: IO response ready_o is always high - acts as sink
     ,.io_resp_i(nbf_io_resp_li)
     ,.io_resp_v_i(nbf_io_resp_v_li)
     ,.io_resp_ready_and_o(nbf_io_resp_ready_lo)

     ,.done_o()
     );


endmodule
