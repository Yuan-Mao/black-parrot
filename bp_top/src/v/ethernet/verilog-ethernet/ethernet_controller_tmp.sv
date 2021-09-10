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

	, input [cce_mem_msg_width_lp-1:0]               io_cmd_i
	, input                                          io_cmd_v_i
	, output logic                                   io_cmd_ready_o

	, output logic [cce_mem_msg_width_lp-1:0]        io_resp_o
	, output logic                                   io_resp_v_o
	, input                                          io_resp_ready_i

	, output logic [cce_mem_msg_width_lp-1:0]        io_cmd_o
	, output logic                                   io_cmd_v_o
	, input                                          io_cmd_yumi_i

	, input        [cce_mem_msg_width_lp-1:0]        io_resp_i
	, input                                          io_resp_v_i
	, output logic                                   io_resp_ready_o


/*
	, input [xce_mem_msg_header_width_lp-1:0]        mem_cmd_header_i
	, input [dword_width_gp-1:0]                     mem_cmd_data_i
	, input                                          mem_cmd_v_i
	, output logic                                   mem_cmd_ready_and_o

	, output logic [xce_mem_msg_header_width_lp-1:0] mem_resp_header_o
	, output logic [dword_width_gp-1:0]              mem_resp_data_o
	, output logic                                   mem_resp_v_o
	, input                                          mem_resp_ready_and_i


	, output logic [xce_mem_msg_header_width_lp-1:0] mem_cmd_header_o
	, output logic [dword_width_gp-1:0]              mem_cmd_data_o
	, output logic                                   mem_cmd_v_o
	, input                                          mem_cmd_ready_and_i

	, input [xce_mem_msg_header_width_lp-1:0]        mem_resp_header_i
	, input [dword_width_gp-1:0]                     mem_resp_data_i
	, input                                          mem_resp_v_i
	, output logic                                   mem_resp_ready_and_o*/
);

  `declare_bp_bedrock_mem_if(paddr_width_p, cce_block_width_p, lce_id_width_p, lce_assoc_p, cce);
  localparam els_lp = 2;
  localparam reg_width_lp = 16;
  localparam reg_addr_width_lp = paddr_width_p;
  localparam max_credits_lp = 8;

  logic [els_lp-1:0]                       r_v_lo;
  logic [els_lp-1:0]                       w_v_lo;
  logic [reg_addr_width_lp-1:0]            addr_lo;
  logic [reg_width_lp-1:0]                 data_lo;
  logic [els_lp-1:0][reg_width_lp-1:0]     data_li;


  logic [xce_mem_msg_header_width_lp-1:0]        mem_cmd_header_li;
  logic [dword_width_gp-1:0]                     mem_cmd_data_li;
  logic                                          mem_cmd_v_li;
  logic                                          mem_cmd_ready_and_lo;

  logic [xce_mem_msg_header_width_lp-1:0]        mem_resp_header_lo;
  logic [dword_width_gp-1:0]                     mem_resp_data_lo;
  logic                                          mem_resp_v_lo;
  logic                                          mem_resp_ready_and_li;

  bp_bedrock_cce_mem_msg_s io_cmd_li, io_resp_lo;

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


  bp_me_bedrock_register
   #(.reg_width_p(reg_width_lp)
     ,.reg_addr_width_p(reg_addr_width_lp)
     ,.els_p(els_lp)
     ,.base_addr_p({40'h0050_0002, 40'h0050_0000}))
   register_interface
   (.clk_i(clk_i)
    ,.reset_i(reset_i)

    ,.mem_cmd_header_i(mem_cmd_header_li)
    ,.mem_cmd_data_i(mem_cmd_data_li)
    ,.mem_cmd_v_i(mem_cmd_v_li)
    ,.mem_cmd_ready_and_o(mem_cmd_ready_and_lo)
    ,.mem_cmd_last_i(/* UNUSED */)

    ,.mem_resp_header_o(mem_resp_header_lo)
    ,.mem_resp_data_o(mem_resp_data_lo)
    ,.mem_resp_v_o(mem_resp_v_lo)
    ,.mem_resp_ready_and_i(mem_resp_ready_and_li)
    ,.mem_resp_last_o(/* UNUSED */)

    ,.r_v_o(r_v_lo)
    ,.w_v_o(w_v_lo)
    ,.addr_o(addr_lo)
    ,.size_o(/* UNUSED */)
    ,.data_o(data_lo)
    ,.data_i(data_li)
    );
  
  logic [els_lp - 1:0][reg_width_lp - 1:0] reg_r;
  logic io_cmd_v_r;
  logic read_r;


  always_ff @(posedge clk_i) begin
    if(reset_i) begin
      io_cmd_v_r <= 1'b0;
	  read_r <= 1'b0;
	end
    else if(w_v_lo[0] && addr_lo == 40'h0050_0000 && ~io_cmd_v_r) begin
      io_cmd_v_r <= 1'b1;
	end
    else if(io_cmd_yumi_i && io_cmd_v_r) begin
      io_cmd_v_r <= 1'b0;
	  read_r <= ~read_r;
	end
  end

  for(genvar i = 0;i < els_lp;i++) begin : rof
    always_ff @(posedge clk_i) begin
      if(w_v_lo[i]) begin
          if(addr_lo == 40'h0050_0000 + i * 2) begin
              reg_r[i] <= data_lo;
          end
      end
    end
  end

	always_ff @(posedge clk_i) begin
		if(r_v_lo)
			data_li <= reg_r;
	end

  bp_bedrock_cce_mem_msg_s io_cmd_lo, io_resp_li;
  bp_bedrock_cce_mem_payload_s io_cmd_lo_payload;

  always_comb
  begin
    if(~read_r) begin
    io_cmd_lo.data = {'0, 8'hab};
    io_cmd_lo_payload = '0;
    io_cmd_lo_payload.lce_id = lce_id_i;
    io_cmd_lo.header.payload = io_cmd_lo_payload;
    io_cmd_lo.header.addr = 40'h80300000;
    io_cmd_lo.header.msg_type.mem = e_bedrock_mem_uc_wr;
    io_cmd_lo.header.subop = e_bedrock_store;
    io_cmd_lo.header.size = e_bedrock_msg_size_8;
    end
	else begin
    io_cmd_lo.data = {'0};
    io_cmd_lo_payload = '0;
    io_cmd_lo_payload.lce_id = lce_id_i;
    io_cmd_lo.header.payload = io_cmd_lo_payload;
    io_cmd_lo.header.addr = 40'h80300000;
    io_cmd_lo.header.msg_type.mem = e_bedrock_mem_uc_rd;
    io_cmd_lo.header.subop = e_bedrock_store;
    io_cmd_lo.header.size = e_bedrock_msg_size_8;
    end
  end



  assign io_cmd_o   = io_cmd_lo;
  assign io_cmd_v_o = io_cmd_v_r;
  assign io_resp_ready_o = 1'b1;
  assign io_resp_li = io_resp_i;

  logic [`BSG_WIDTH(max_credits_lp)-1:0] credit_count_lo;

  bsg_flow_counter
   #(.els_p(max_credits_lp))
   eth_counter
    (.clk_i(clk_i)
     ,.reset_i(reset_i)

     ,.v_i(io_cmd_yumi_i)
     ,.ready_i(1'b1)

     ,.yumi_i(io_resp_v_i)
     ,.count_o(credit_count_lo)
     );
  wire credits_empty = (credit_count_lo == '0);

endmodule
