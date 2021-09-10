`include "bp_common_defines.svh"
`include "bp_me_defines.svh"

module ethernet_controller
    import bp_common_pkg::*;
    import bp_me_pkg::*;
#(parameter bp_params_e bp_params_p = e_bp_default_cfg
    `declare_bp_proc_params(bp_params_p)
    `declare_bp_bedrock_mem_if_widths(paddr_width_p, dword_width_gp, lce_id_width_p, lce_assoc_p, xce)
    `declare_bp_bedrock_mem_if_widths(paddr_width_p, cce_block_width_p, lce_id_width_p, lce_assoc_p, cce)
)
(

    input logic                                      clk_i
    , input logic                                    reset_i
    , input logic [lce_id_width_p-1:0]               lce_id_i

    /* BP I/O command input */
    , input [cce_mem_msg_width_lp-1:0]               io_cmd_i
    , input                                          io_cmd_v_i
    , output logic                                   io_cmd_ready_o
    , output logic [cce_mem_msg_width_lp-1:0]        io_resp_o
    , output logic                                   io_resp_v_o
    , input                                          io_resp_ready_i

    /* BP I/O command output */
    , output logic [cce_mem_msg_width_lp-1:0]        io_cmd_o
    , output logic                                   io_cmd_v_o
    , input                                          io_cmd_yumi_i
    , input        [cce_mem_msg_width_lp-1:0]        io_resp_i
    , input                                          io_resp_v_i
    , output logic                                   io_resp_ready_o

    /* MII interface */
    , input  logic                                   mii_rx_clk_i
    , input  logic [3:0]                             mii_rxd_i
    , input  logic                                   mii_rx_dv_i
    , input  logic                                   mii_rx_er_i
    , input  logic                                   mii_tx_clk_i
    , output logic [3:0]                             mii_txd_o
    , output logic                                   mii_tx_en_o
    , output logic                                   mii_tx_er_o
);

  `declare_bp_bedrock_mem_if(paddr_width_p, cce_block_width_p, lce_id_width_p, lce_assoc_p, cce);
  localparam els_lp = 2;
  localparam axis_data_width_lp = 64;
  localparam reg_addr_width_lp = paddr_width_p;
  localparam max_credits_lp = 8;
  localparam eth_rx_state_width_lp = 3;

  logic [els_lp-1:0]                       r_v_lo;
  logic [els_lp-1:0]                       w_v_lo;
  logic [reg_addr_width_lp-1:0]            addr_lo;
  logic [63:0]                 data_lo;
  logic [els_lp-1:0][63:0]     data_li;


  logic [xce_mem_msg_header_width_lp-1:0]        mem_cmd_header_li;
  logic [dword_width_gp-1:0]                     mem_cmd_data_li;
  logic                                          mem_cmd_v_li;
  logic                                          mem_cmd_ready_and_lo;

  logic [xce_mem_msg_header_width_lp-1:0]        mem_resp_header_lo;
  logic [dword_width_gp-1:0]                     mem_resp_data_lo;
  logic                                          mem_resp_v_lo;
  logic                                          mem_resp_ready_and_li;

  bp_bedrock_cce_mem_msg_s io_cmd_li, io_resp_lo;

  logic [axis_data_width_lp-1:0] tx_axis_tdata_li;
  logic  [axis_data_width_lp/8-1:0] tx_axis_tkeep_li;
  logic        tx_axis_tvalid_li;
  logic        tx_axis_tready_lo;
  logic        tx_axis_tlast_li;
  logic        tx_axis_tuser_li;

  logic [axis_data_width_lp-1:0] rx_axis_tdata_lo;
  logic  [axis_data_width_lp/8-1:0] rx_axis_tkeep_lo;
  logic        rx_axis_tvalid_lo;
  logic        rx_axis_tready_li;
  logic        rx_axis_tlast_lo;
  logic        rx_axis_tuser_lo;


  assign io_cmd_li = io_cmd_i;
  assign io_resp_o = io_resp_lo;

  assign {mem_cmd_header_li, mem_cmd_data_li} = 
    {io_cmd_li.header, io_cmd_li.data[0+:dword_width_gp]};
  assign mem_cmd_v_li = io_cmd_v_i;
  assign io_cmd_ready_o = mem_cmd_ready_and_lo;


  assign io_resp_lo = '{header: mem_resp_header_lo
                       ,data: {cce_block_width_p/dword_width_gp{mem_resp_data_lo}}};
  assign io_resp_v_o = mem_resp_v_lo;
  assign mem_resp_ready_and_li = io_resp_ready_i;

  // TODO: put this into from_rx_axis ?
  assign io_resp_ready_o = 1'b1;

  logic [els_lp-1:0] w_yumi_li;
  assign w_yumi_li[0] = w_v_lo[0];

  ethernet_interface
   #(.reg_width_p(64)
     ,.reg_addr_width_p(reg_addr_width_lp)
     ,.els_p(els_lp)
  // TODO: May need to change the MMIO location from 40'h0050_0000 to somewhere else.
     ,.base_addr_p({40'h0050_0008, 40'h0050_0000}))
   ethernet_interface
   (.clk_i(clk_i)
    ,.reset_i(reset_i)

    ,.mem_cmd_header_i(mem_cmd_header_li)
    ,.mem_cmd_data_i(mem_cmd_data_li)
    ,.mem_cmd_v_i(mem_cmd_v_li)
    ,.mem_cmd_ready_and_o(mem_cmd_ready_and_lo)

    ,.mem_resp_header_o(mem_resp_header_lo)
    ,.mem_resp_data_o(mem_resp_data_lo)
    ,.mem_resp_v_o(mem_resp_v_lo)
    ,.mem_resp_ready_and_i(mem_resp_ready_and_li)

    ,.r_v_o(r_v_lo)
    ,.w_v_o(w_v_lo)
    ,.w_yumi_i(w_yumi_li)
    ,.addr_o(addr_lo)
    ,.size_o(/* UNUSED */)
    ,.data_o(data_lo)
    ,.data_i(data_li)
    );
  
  localparam eth_cmd_width_lp = 3;

  wire [eth_cmd_width_lp-1:0] eth_cmd_li = data_lo[63-:eth_cmd_width_lp];
  wire                        eth_cmd_v_li = w_v_lo[0];
  wire [reg_addr_width_lp-1:0] eth_cmd_arg_li = data_lo[reg_addr_width_lp-1:0];

  logic [1:0] rx_ext_state_lo;
  logic [1:0] tx_ext_state_lo;
  logic [3:0] ext_state_r;


  always_ff @(posedge clk_i) begin
    if(r_v_lo[0])
      ext_state_r <= {tx_ext_state_lo, rx_ext_state_lo};
  end
  assign data_li = {64'(ext_state_r)};

  from_rx_axis #(.bp_params_p(bp_params_p)
                ,.axis_data_width_p(axis_data_width_lp)
                ,.reg_addr_width_p(reg_addr_width_lp)
                ,.eth_rx_state_width_p(eth_rx_state_width_lp)
                ,.eth_cmd_width_p(eth_cmd_width_lp)
                ) from_rx_axis
    (
      .clk_i(clk_i)
      ,.reset_i(reset_i)
      ,.lce_id_i(lce_id_i)

      ,.eth_cmd_i(eth_cmd_li)
      ,.eth_cmd_v_i(eth_cmd_v_li)
      ,.eth_cmd_arg_i(eth_cmd_arg_li)
    
      ,.rx_axis_tdata_i(rx_axis_tdata_lo)
      ,.rx_axis_tkeep_i(rx_axis_tkeep_lo)
      ,.rx_axis_tvalid_i(rx_axis_tvalid_lo)
      ,.rx_axis_tready_o(rx_axis_tready_li)
      ,.rx_axis_tlast_i(rx_axis_tlast_lo)
      ,.rx_axis_tuser_i(rx_axis_tuser_lo)

      ,.io_cmd_o(io_cmd_o)
      ,.io_cmd_v_o(io_cmd_v_o)
      ,.io_cmd_yumi_i(io_cmd_yumi_i)
      ,.io_resp_v_i(io_resp_v_i)

      ,.rx_ext_state_o(rx_ext_state_lo)
    );

  to_tx_axis #(.bp_params_p(bp_params_p)
              ,.eth_cmd_width_p(eth_cmd_width_lp)
              ,.axis_data_width_p(axis_data_width_lp)
              ) to_tx_axis
    (
      .clk_i(clk_i)
      ,.reset_i(reset_i)

      ,.frame_data_i(data_lo)
      ,.frame_data_v_i(w_v_lo[1])
      ,.frame_data_yumi_o(w_yumi_li[1])
      ,.tx_ext_state_o(tx_ext_state_lo)

      ,.tx_axis_tdata_o(tx_axis_tdata_li)
      ,.tx_axis_tkeep_o(tx_axis_tkeep_li)
      ,.tx_axis_tvalid_o(tx_axis_tvalid_li)
      ,.tx_axis_tready_i(tx_axis_tready_lo)
      ,.tx_axis_tlast_o(tx_axis_tlast_li)
      ,.tx_axis_tuser_o(tx_axis_tuser_li)
    );

  eth_mac_mii_fifo #(
            .AXIS_DATA_WIDTH(axis_data_width_lp)
            ) eth_mac_mii_fifo
    (
        .rst(reset_i)
        ,.logic_clk(clk_i)
        ,.logic_rst(reset_i) // difference between rst ?

        /* AXI input */
        ,.tx_axis_tdata(tx_axis_tdata_li)
        ,.tx_axis_tkeep(tx_axis_tkeep_li)
        ,.tx_axis_tvalid(tx_axis_tvalid_li)
        ,.tx_axis_tready(tx_axis_tready_lo)
        ,.tx_axis_tlast(tx_axis_tlast_li)
        ,.tx_axis_tuser(tx_axis_tuser_li)

        /* AXI output */
        ,.rx_axis_tdata(rx_axis_tdata_lo)
        ,.rx_axis_tkeep(rx_axis_tkeep_lo)
        ,.rx_axis_tvalid(rx_axis_tvalid_lo)
        ,.rx_axis_tready(rx_axis_tready_li)
        ,.rx_axis_tlast(rx_axis_tlast_lo)
        ,.rx_axis_tuser(rx_axis_tuser_lo)

        ,.mii_rx_clk(mii_rx_clk_i) // 25 MHZ
        ,.mii_rxd(mii_rxd_i)
        ,.mii_rx_dv(mii_rx_dv_i)
        ,.mii_rx_er(mii_rx_er_i)
        ,.mii_tx_clk(mii_tx_clk_i) // 25 MHZ
        ,.mii_txd(mii_txd_o)
        ,.mii_tx_en(mii_tx_en_o)
        ,.mii_tx_er(mii_tx_er_o)

        ,.tx_error_underflow(/* UNUSED */)
        ,.tx_fifo_overflow(/* UNUSED */)
        ,.tx_fifo_bad_frame(/* UNUSED */)
        ,.tx_fifo_good_frame(/* UNUSED */)
        ,.rx_error_bad_frame(/* UNUSED */)
        ,.rx_error_bad_fcs(/* UNUSED */)
        ,.rx_fifo_overflow(/* UNUSED */)
        ,.rx_fifo_bad_frame(/* UNUSED */)
        ,.rx_fifo_good_frame(/* UNUSED */)

        ,.ifg_delay(8'd24)
    );


endmodule
