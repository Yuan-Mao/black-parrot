/**
  *
  * testbench.v
  *
  */

`include "bsg_noc_links.vh"

`ifndef BP_SIM_CLK_PERIOD
`define BP_SIM_CLK_PERIOD 10
`endif

module ethernet_cpu_wrapper
 import bp_common_pkg::*;
 import bp_be_pkg::*;
 import bp_me_pkg::*;
 import bsg_noc_pkg::*;
 #(parameter bp_params_e bp_params_p = BP_CFG_FLOWVAR // Replaced by the flow with a specific bp_cfg
   `declare_bp_proc_params(bp_params_p)
   `declare_bp_core_if_widths(vaddr_width_p, paddr_width_p, asid_width_p, branch_metadata_fwd_width_p)
   `declare_bp_bedrock_mem_if_widths(paddr_width_p, cce_block_width_p, lce_id_width_p, lce_assoc_p, cce)
   , localparam dma_pkt_width_lp = `bsg_cache_dma_pkt_width(caddr_width_p)

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
      input logic                              clk250_i
    , input logic                              clk250_reset_i // sync with clk250_i
    , output logic                             clk250_reset_late_o // sync with clk250_i
    , input logic                              bp_clk_i
    , input logic                              bp_reset_i // sync with bp_clk_i

    , output logic                             rgmii_tx_clk_o
    , output logic [3:0]                       rgmii_txd_o
    , output logic                             rgmii_tx_ctl_o

    , input logic                              rgmii_rx_clk_i
    , input logic [3:0]                        rgmii_rxd_i
    , input logic                              rgmii_rx_ctl_i

    // DRAM interface
    , output logic [dma_pkt_width_lp-1:0]      dma_pkt_o
    , output logic                             dma_pkt_v_o
    , input                                    dma_pkt_yumi_i

    , input [l2_fill_width_p-1:0]              dma_data_i
    , input                                    dma_data_v_i
    , output logic                             dma_data_ready_and_o

    , output logic [l2_fill_width_p-1:0]       dma_data_o
    , output logic                             dma_data_v_o
    , input                                    dma_data_yumi_i

    // Host interface
    , output [cce_mem_msg_width_lp-1:0]        host_io_cmd_o
    , output                                   host_io_cmd_v_o
    , input logic                              host_io_cmd_ready_and_i

    , input logic [cce_mem_msg_width_lp-1:0]   host_io_resp_i
    , input logic                              host_io_resp_v_i
    , output                                   host_io_resp_yumi_o

    // NBF interface
    , input logic [cce_mem_msg_width_lp-1:0]   nbf_io_cmd_i
    , input logic                              nbf_io_cmd_v_i
    , output                                   nbf_io_cmd_yumi_o

    , output  [cce_mem_msg_width_lp-1:0]       nbf_io_resp_o
    , output                                   nbf_io_resp_v_o
    , input logic                              nbf_io_resp_ready_and_i

  );


  `declare_bp_bedrock_mem_if(paddr_width_p, cce_block_width_p, lce_id_width_p, lce_assoc_p, cce);

  // The location and size of the user Ethernet buffer
  localparam [paddr_width_p-1:0] user_ethernet_buffer_addr = 32'h8030_0000;
  localparam [paddr_width_p-1:0] user_ethernet_buffer_size = 32'h0000_1000;

  bp_bedrock_cce_mem_msg_s proc_io_cmd_lo;
  logic proc_io_cmd_v_lo, proc_io_cmd_ready_li;
  bp_bedrock_cce_mem_msg_s proc_io_resp_li;
  logic proc_io_resp_v_li, proc_io_resp_yumi_lo;

  bp_bedrock_cce_mem_msg_s io_cmd_lo;
  logic io_cmd_v_lo, io_cmd_ready_li;
  bp_bedrock_cce_mem_msg_s io_resp_li;
  logic io_resp_v_li, io_resp_yumi_lo;

  bp_bedrock_cce_mem_msg_s load_cmd_li;
  logic load_cmd_v_li, load_cmd_yumi_lo;
  bp_bedrock_cce_mem_msg_s load_resp_lo;
  logic load_resp_v_lo, load_resp_ready_li;


  bp_unicore #(.bp_params_p(bp_params_p)) black_parrot
   (.clk_i(bp_clk_i)
    ,.reset_i(bp_reset_i)

    ,.io_cmd_o(proc_io_cmd_lo)
    ,.io_cmd_v_o(proc_io_cmd_v_lo)
    ,.io_cmd_ready_and_i(proc_io_cmd_ready_li)

    ,.io_resp_i(proc_io_resp_li)
    ,.io_resp_v_i(proc_io_resp_v_li)
    ,.io_resp_yumi_o(proc_io_resp_yumi_lo)
   
    ,.io_cmd_i(load_cmd_li)
    ,.io_cmd_v_i(load_cmd_v_li)
    ,.io_cmd_yumi_o(load_cmd_yumi_lo)
   
    ,.io_resp_o(load_resp_lo)
    ,.io_resp_v_o(load_resp_v_lo)
    ,.io_resp_ready_and_i(load_resp_ready_li)
   
    ,.dma_pkt_o(dma_pkt_o)
    ,.dma_pkt_v_o(dma_pkt_v_o)
    ,.dma_pkt_yumi_i(dma_pkt_yumi_i)
   
    ,.dma_data_i(dma_data_i)
    ,.dma_data_v_i(dma_data_v_i)
    ,.dma_data_ready_and_o(dma_data_ready_and_o)
   
    ,.dma_data_o(dma_data_o)
    ,.dma_data_v_o(dma_data_v_o)
    ,.dma_data_yumi_i(dma_data_yumi_i)
    );


  `declare_bp_memory_map(paddr_width_p, caddr_width_p);
  bp_bedrock_cce_mem_msg_s eth_io_resp_lo;

  bp_local_addr_s io_cmd_local_addr_cast;
  bp_bedrock_cce_mem_msg_s eth_io_cmd_li;
  bp_bedrock_cce_mem_msg_s eth_io_cmd_lo;
  assign eth_io_cmd_li  = proc_io_cmd_lo;
  assign host_io_cmd_o = proc_io_cmd_lo;
  assign io_cmd_local_addr_cast = proc_io_cmd_lo.header.addr;
  wire [dev_id_width_gp-1:0] device_cmd_li = io_cmd_local_addr_cast.dev;
  wire local_cmd_li = (proc_io_cmd_lo.header.addr < dram_base_addr_gp);
  wire is_eth_cmd   = local_cmd_li & (device_cmd_li == eth_dev_gp);

  logic [paddr_width_p-1:0] io_resp_header_addr;
  assign io_resp_header_addr = load_resp_lo.header.addr;

  // Use the address to identify which the io_resp is for
  assign is_eth_resp = ((io_resp_header_addr >= user_ethernet_buffer_addr)
                    && (io_resp_header_addr < user_ethernet_buffer_addr + 
                        user_ethernet_buffer_size));

  logic eth_io_cmd_v_li;
  logic eth_io_cmd_ready_lo;
  logic eth_io_resp_v_lo;
  logic eth_io_resp_ready_li;
  logic eth_io_cmd_v_lo, eth_io_cmd_yumi_li;

  bp_bedrock_cce_mem_msg_s eth_io_resp_li;
  logic eth_io_resp_ready_lo;

  assign proc_io_cmd_ready_li = eth_io_cmd_ready_lo & host_io_cmd_ready_and_i;
  assign host_io_cmd_v_o      = proc_io_cmd_v_lo & ~is_eth_cmd;
  assign eth_io_cmd_v_li      = proc_io_cmd_v_lo &  is_eth_cmd;

  assign proc_io_resp_v_li    = host_io_resp_v_i | eth_io_resp_v_lo;
  assign proc_io_resp_li      = host_io_resp_v_i ? host_io_resp_i : eth_io_resp_lo;
  assign host_io_resp_yumi_o  = host_io_resp_v_i ? proc_io_resp_yumi_lo : 1'b0;
  assign eth_io_resp_ready_li = host_io_resp_v_i ? 1'b0 : proc_io_resp_yumi_lo;

  assign load_cmd_v_li        = nbf_io_cmd_v_i | eth_io_cmd_v_lo;
  assign load_cmd_li          = nbf_io_cmd_v_i ? nbf_io_cmd_i : eth_io_cmd_lo;
  assign nbf_io_cmd_yumi_o    = nbf_io_cmd_v_i ? load_cmd_yumi_lo : 1'b0;
  assign eth_io_cmd_yumi_li   = nbf_io_cmd_v_i ? 1'b0 : load_cmd_yumi_lo;

  assign load_resp_ready_li   = nbf_io_resp_ready_and_i & eth_io_resp_ready_lo;
  assign nbf_io_resp_v_o      = load_resp_v_lo & ~is_eth_resp;
  assign eth_io_resp_v_li     = load_resp_v_lo &  is_eth_resp;
  assign eth_io_resp_li       = load_resp_lo;
  assign nbf_io_resp_o        = load_resp_lo;

  ethernet_controller ethernet_controller
  (.clk250_i(clk250_i)
   ,.clk250_reset_i(clk250_reset_i)
   ,.clk250_reset_late_o(clk250_reset_late_o)
   ,.bp_clk_i(bp_clk_i)
   ,.bp_reset_i(bp_reset_i)

   ,.lce_id_i(lce_id_width_p'('b10))

   ,.io_cmd_i(eth_io_cmd_li)
   ,.io_cmd_v_i(eth_io_cmd_v_li)
   ,.io_cmd_ready_o(eth_io_cmd_ready_lo)
   ,.io_resp_o(eth_io_resp_lo)
   ,.io_resp_v_o(eth_io_resp_v_lo)
   ,.io_resp_ready_i(eth_io_resp_ready_li)

   ,.io_cmd_o(eth_io_cmd_lo)
   ,.io_cmd_v_o(eth_io_cmd_v_lo)
   ,.io_cmd_yumi_i(eth_io_cmd_yumi_li)
   ,.io_resp_i(eth_io_resp_li)
   ,.io_resp_v_i(eth_io_resp_v_li)
   ,.io_resp_ready_o(eth_io_resp_ready_lo)

   ,.rgmii_rx_clk_i(rgmii_rx_clk_i)
   ,.rgmii_rxd_i(rgmii_rxd_i)
   ,.rgmii_rx_ctl_i(rgmii_rx_ctl_i)
   ,.rgmii_tx_clk_o(rgmii_tx_clk_o)
   ,.rgmii_txd_o(rgmii_txd_o)
   ,.rgmii_tx_ctl_o(rgmii_tx_ctl_o)
   );


endmodule
