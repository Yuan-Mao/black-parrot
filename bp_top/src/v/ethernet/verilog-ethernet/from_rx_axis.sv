
module from_rx_axis
    import bp_common_pkg::*;
    import bp_me_pkg::*;
#(parameter bp_params_e bp_params_p = e_bp_default_cfg
  ,parameter axis_data_width_p      = 64
  ,parameter reg_addr_width_p       = paddr_width_p
  ,parameter eth_rx_state_width_p   = 3
  ,parameter eth_cmd_width_p        = 3
    `declare_bp_proc_params(bp_params_p)
    `declare_bp_bedrock_mem_if_widths(paddr_width_p, dword_width_gp, lce_id_width_p, lce_assoc_p, xce)
    `declare_bp_bedrock_mem_if_widths(paddr_width_p, cce_block_width_p, lce_id_width_p, lce_assoc_p, cce)
)
(
    input logic                                 clk_i
    , input logic                               reset_i
    , input logic [lce_id_width_p-1:0]          lce_id_i

    , input logic [eth_cmd_width_p-1:0]         eth_cmd_i
    , input logic                               eth_cmd_v_i
    , input logic [reg_addr_width_p-1:0]        eth_cmd_arg_i

    /* AXIS RX */
    , input logic [axis_data_width_p-1:0]       rx_axis_tdata_i
    , input logic [axis_data_width_p/8-1:0]     rx_axis_tkeep_i
    , input logic                               rx_axis_tvalid_i
    , output logic                              rx_axis_tready_o
    , input logic                               rx_axis_tlast_i
    , input logic                               rx_axis_tuser_i

    , output logic [cce_mem_msg_width_lp-1:0]   io_cmd_o
    , output logic                              io_cmd_v_o
    , input                                     io_cmd_yumi_i
    , input logic                               io_resp_v_i

    , output logic [1:0]                        rx_ext_state_o
);
  `declare_bp_bedrock_mem_if(paddr_width_p, cce_block_width_p, lce_id_width_p, lce_assoc_p, cce);
  typedef enum logic [eth_rx_state_width_p-1:0] {
    ETH_RX_STATE_INIT           = 3'b000
    ,ETH_RX_STATE_EMPTY         = 3'b001
    ,ETH_RX_STATE_PAYLOAD       = 3'b010
    ,ETH_RX_STATE_SIZE          = 3'b011
    ,ETH_RX_STATE_SYNC          = 3'b100
    ,ETH_RX_STATE_READY         = 3'b101
  } eth_rx_state_e;

  typedef enum logic [eth_cmd_width_p-1:0] {
    ETH_CMD_RX_SET_BUF_ADDR       = 3'b001
    ,ETH_CMD_RX_ACK                = 3'b010
  } eth_cmd_e;

  eth_rx_state_e rx_state_r, rx_state_n;
  logic [reg_addr_width_p-1:0] rx_buf_addr_r, rx_buf_addr_n;

  logic bad_frame;
  logic rx_beat_sent, rx_size_sent;
  logic rx_credits_empty;
  logic [1:0] rx_ext_state;
  localparam rx_max_credits_lp = 256;


  always_ff @(posedge clk_i) begin
    if(reset_i) begin
      rx_state_r <= ETH_RX_STATE_INIT;
    end
    else begin
      rx_state_r <= rx_state_n;
      rx_buf_addr_r <= rx_buf_addr_n;
    end
  end
  always_comb begin
    rx_buf_addr_n = rx_buf_addr_r;
    if(eth_cmd_v_i)
      case(eth_cmd_i)
        ETH_CMD_RX_SET_BUF_ADDR:
          if(rx_state_r == ETH_RX_STATE_INIT || rx_state_r == ETH_RX_STATE_READY)
            rx_buf_addr_n = eth_cmd_arg_i;
      endcase
  end

  always_comb begin
    rx_ext_state_o = 2'b11;
    case(rx_state_r)
      ETH_RX_STATE_INIT:
        rx_ext_state_o = 2'b00;
      ETH_RX_STATE_EMPTY
      ,ETH_RX_STATE_PAYLOAD
      ,ETH_RX_STATE_SIZE
      ,ETH_RX_STATE_SYNC:
        rx_ext_state_o = 2'b01;
      ETH_RX_STATE_READY:
        rx_ext_state_o = 2'b10;
    endcase
  end
  always_comb begin
    rx_state_n = rx_state_r;
    io_cmd_v_o = 1'b0;
    rx_beat_sent = 1'b0;
    rx_size_sent = 1'b0;
    bad_frame = 1'b0;
    case(rx_state_r)
      ETH_RX_STATE_INIT: begin
        if(eth_cmd_v_i && (eth_cmd_i == ETH_CMD_RX_SET_BUF_ADDR))
          rx_state_n = ETH_RX_STATE_EMPTY;
      end
      ETH_RX_STATE_EMPTY: begin
        if(rx_axis_tvalid_i)
          rx_state_n = ETH_RX_STATE_PAYLOAD;
      end
      ETH_RX_STATE_PAYLOAD: begin
        io_cmd_v_o = rx_axis_tvalid_i;
        bad_frame = (rx_axis_tuser_i & rx_axis_tvalid_i & rx_axis_tlast_i);
        rx_beat_sent = io_cmd_yumi_i & ~bad_frame;
        if(rx_beat_sent & rx_axis_tlast_i)
          rx_state_n = ETH_RX_STATE_SIZE;
        else if(bad_frame)
          rx_state_n = ETH_RX_STATE_EMPTY;
      end
      ETH_RX_STATE_SIZE: begin
        io_cmd_v_o = 1'b1;
        rx_size_sent = io_cmd_yumi_i;
        if(rx_size_sent)
          rx_state_n = ETH_RX_STATE_SYNC;
      end
      ETH_RX_STATE_SYNC: begin
      if(rx_credits_empty)
          rx_state_n = ETH_RX_STATE_READY;
      end
      ETH_RX_STATE_READY: begin
        if(eth_cmd_v_i && (eth_cmd_i == ETH_CMD_RX_ACK))
          rx_state_n = ETH_RX_STATE_EMPTY;
      end
    endcase
  end


  logic [15:0] rx_recv_cnt_r, rx_beat_byte_cnt;
  logic [reg_addr_width_p - 1:0] rx_recv_offset_r;
  logic [3:0] rx_head_offset_r;

  always_ff @(posedge clk_i) begin
    if(reset_i) begin
      rx_recv_cnt_r <= '0;
      rx_recv_offset_r <= '0;
    end
    else begin
      if(rx_beat_sent) begin
        rx_recv_cnt_r <= rx_recv_cnt_r + rx_beat_byte_cnt;
        rx_recv_offset_r <= rx_recv_offset_r + rx_beat_byte_cnt;
      end
      else if(rx_state_r == ETH_RX_STATE_EMPTY) begin
        rx_recv_cnt_r <= '0;
        rx_recv_offset_r <= rx_buf_addr_r + reg_addr_width_p'(4'h8);
      end
    end
  end

  always_ff @(posedge clk_i) begin
    if(rx_beat_sent && (rx_recv_cnt_r == '0)) begin
      case(rx_axis_tkeep_i)
        8'b1111_1111:
          rx_head_offset_r <= 4'h0;
        8'b1111_1110:
          rx_head_offset_r <= 4'h1;
        8'b1111_1100:
          rx_head_offset_r <= 4'h2;
        8'b1111_1000:
          rx_head_offset_r <= 4'h3;
        8'b1111_0000:
          rx_head_offset_r <= 4'h4;
        8'b1110_0000:
          rx_head_offset_r <= 4'h5;
        8'b1100_0000:
          rx_head_offset_r <= 4'h6;
        8'b1000_0000:
          rx_head_offset_r <= 4'h7;
      endcase
    end
  end

  always_comb begin
    rx_beat_byte_cnt = '1;
    case(rx_axis_tkeep_i)
      8'b1111_1111:
        rx_beat_byte_cnt = 16'h8;
      8'b0111_1111,
      8'b1111_1110:
        rx_beat_byte_cnt = 16'h7;
      8'b0011_1111,
      8'b1111_1100:
        rx_beat_byte_cnt = 16'h6;
      8'b0001_1111,
      8'b1111_1000:
        rx_beat_byte_cnt = 16'h5;
      8'b0000_1111,
      8'b1111_0000:
        rx_beat_byte_cnt = 16'h4;
      8'b0000_0111,
      8'b1110_0000:
        rx_beat_byte_cnt = 16'h3;
      8'b0000_0011,
      8'b1100_0000:
        rx_beat_byte_cnt = 16'h2;
      8'b0000_0001,
      8'b1000_0000:
        rx_beat_byte_cnt = 16'h1;
    endcase
  end

  bp_bedrock_cce_mem_msg_s io_cmd_lo;
  bp_bedrock_cce_mem_payload_s io_cmd_lo_payload;

  always_comb begin
    /* write arrival packet to BP dcache */
    if(rx_state_r == ETH_RX_STATE_PAYLOAD) begin
      io_cmd_lo.data = rx_axis_tdata_i;
      io_cmd_lo_payload = '0;
      io_cmd_lo_payload.lce_id = lce_id_i;
      io_cmd_lo.header.payload = io_cmd_lo_payload;
      io_cmd_lo.header.addr = rx_recv_offset_r;
      io_cmd_lo.header.msg_type.mem = e_bedrock_mem_uc_wr;
      io_cmd_lo.header.subop = e_bedrock_store;
      io_cmd_lo.header.size = e_bedrock_msg_size_8;
    end
    else begin
      io_cmd_lo.data = {rx_head_offset_r, rx_recv_cnt_r};
      io_cmd_lo_payload = '0;
      io_cmd_lo_payload.lce_id = lce_id_i;
      io_cmd_lo.header.payload = io_cmd_lo_payload;
      io_cmd_lo.header.addr = rx_buf_addr_r;
      io_cmd_lo.header.msg_type.mem = e_bedrock_mem_uc_wr;
      io_cmd_lo.header.subop = e_bedrock_store;
      io_cmd_lo.header.size = e_bedrock_msg_size_8;
    end
  end
  assign io_cmd_o = io_cmd_lo;
  /* TODO: potential critical path: */
  assign rx_axis_tready_o = io_cmd_yumi_i;

  logic [`BSG_WIDTH(rx_max_credits_lp)-1:0] rx_credit_count_lo;

  bsg_flow_counter
   #(.els_p(rx_max_credits_lp))
   eth_counter
    (.clk_i(clk_i)
     ,.reset_i(reset_i)

     ,.v_i(rx_beat_sent | rx_size_sent)
     ,.ready_i(1'b1)

     ,.yumi_i(io_resp_v_i)
     ,.count_o(rx_credit_count_lo)
     );
  assign rx_credits_empty = (rx_credit_count_lo == '0);

endmodule
