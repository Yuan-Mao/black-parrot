`include "bp_common_defines.svh"
`include "bp_me_defines.svh"


module ethernet_interface
  import bp_common_pkg::*;
  import bp_me_pkg::*;
  #(parameter bp_params_e bp_params_p = e_bp_default_cfg
    `declare_bp_proc_params(bp_params_p)
    `declare_bp_bedrock_mem_if_widths(paddr_width_p, dword_width_gp, lce_id_width_p, lce_assoc_p, xce)
    , parameter reg_width_p = dword_width_gp
    , parameter reg_addr_width_p = paddr_width_p
    , parameter els_p = 1
    , parameter [els_p-1:0][reg_addr_width_p-1:0] base_addr_p = '0
    , localparam lg_reg_width_lp = `BSG_WIDTH(`BSG_SAFE_CLOG2(reg_width_p/8))
    )
  (input                                            clk_i
   , input                                          reset_i

   // Network-side BP-Stream interface
   , input [xce_mem_msg_header_width_lp-1:0]        mem_cmd_header_i
   , input [dword_width_gp-1:0]                     mem_cmd_data_i
   , input                                          mem_cmd_v_i
   , output logic                                   mem_cmd_ready_and_o

   , output logic [xce_mem_msg_header_width_lp-1:0] mem_resp_header_o
   , output logic [dword_width_gp-1:0]              mem_resp_data_o
   , output logic                                   mem_resp_v_o
   , input                                          mem_resp_ready_and_i


   , output logic [els_p-1:0]                       r_v_o
   , output logic [els_p-1:0]                       w_v_o
   , input        [els_p-1:0]                       w_yumi_i
   , output logic [reg_addr_width_p-1:0]            addr_o
   , output logic [lg_reg_width_lp-1:0]             size_o
   , output logic [reg_width_p-1:0]                 data_o
   , input [els_p-1:0][reg_width_p-1:0]             data_i
   );
  `declare_bp_bedrock_mem_if(paddr_width_p, dword_width_gp, lce_id_width_p, lce_assoc_p, xce);

  bp_bedrock_xce_mem_msg_header_s mem_cmd_header_lo;
  logic [dword_width_gp-1:0] mem_cmd_data_lo;
  logic mem_cmd_v_lo;
  logic mem_resp_yumi_li, mem_cmd_yumi_li;


  wire yumi_li = |{w_yumi_i, r_v_o};
  bsg_one_fifo
   #(.width_p($bits(bp_bedrock_xce_mem_msg_s)))
   cmd_fifo
    (.clk_i(clk_i)
     ,.reset_i(reset_i)

     ,.data_i({mem_cmd_header_i, mem_cmd_data_i})
     ,.v_i(mem_cmd_v_i)
     ,.ready_o(mem_cmd_ready_and_o)

     ,.data_o({mem_cmd_header_lo, mem_cmd_data_lo})
     ,.v_o(mem_cmd_v_lo)
     ,.yumi_i(mem_cmd_yumi_li)
     );

  wire wr_not_rd  = (mem_cmd_header_lo.msg_type inside {e_bedrock_mem_wr, e_bedrock_mem_uc_wr});
  wire rd_not_wr  = (mem_cmd_header_lo.msg_type inside {e_bedrock_mem_wr, e_bedrock_mem_uc_wr});
  
  for(genvar i = 0;i < els_p;i++) begin: dec
    wire addr_match = mem_cmd_v_lo & (mem_cmd_header_lo.addr[0+:reg_addr_width_p] inside
        {base_addr_p[i]});
    assign r_v_o[i] = addr_match & ~wr_not_rd;
    assign w_v_o[i] = addr_match &  wr_not_rd;
  end

  assign addr_o = mem_cmd_header_lo.addr;
  assign size_o = mem_cmd_header_lo.size;
  assign data_o = mem_cmd_data_lo;

  assign mem_resp_header_o = mem_cmd_header_lo;
  assign mem_resp_data_o   = data_i;
  assign mem_resp_v_o       = yumi_li;
  assign mem_resp_yumi_li = mem_resp_ready_and_i & mem_resp_v_o;
  assign mem_cmd_yumi_li  = mem_resp_yumi_li;

endmodule




