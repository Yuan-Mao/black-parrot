module nonsynth_ethernet_receiver
#(
  parameter recv_width_p = 8, // byte
  parameter buf_size_p = ((1556 - 1) / recv_width_p + 1) * recv_width_p, // byte
  parameter addr_width_lp = $clog2(buf_size_p / recv_width_p)
)
(
  input  logic clk_i
  ,input  logic reset_i

  ,input  logic [3:0]                    mii_rxd_i
  ,input  logic                          mii_rx_dv_i
  ,input  logic                          mii_rx_er_i

  ,input  logic                          clear_buffer_i
);

  localparam recv_ptr_width_lp = $clog2(buf_size_p / recv_width_p);
//  localparam recv_ptr_offset_width_lp = $clog2(recv_width_p);

  logic [recv_width_p * 8 - 1:0] buffer_r [buf_size_p / recv_width_p - 1:0];
  logic [15:0] packet_size_r;
  logic [15:0] packet_size_remaining;

  logic [recv_width_p * 8 - 1:0] rx_axis_tdata_lo;
  logic [recv_width_p - 1:0]     rx_axis_tkeep_lo;
  logic                          rx_axis_tvalid_lo;
  logic                          rx_axis_tlast_lo;
  logic                          rx_axis_tuser_lo;



  logic [recv_ptr_width_lp - 1:0] recv_ptr_r, recv_ptr_n;
  logic buffer_empty_r;
  logic receiving;
  logic bad_frame;

  wire rx_axis_tready_lo = buffer_empty_r;
  assign bad_frame = rx_axis_tuser_lo && rx_axis_tvalid_lo && rx_axis_tlast_lo;
  assign receiving = rx_axis_tready_lo && rx_axis_tvalid_lo && !bad_frame;




  always_ff @(posedge clk_i) begin
    assert(recv_width_p == 8) else $error("receiver now only supports width == 8");
  end

  always_ff @(posedge clk_i) begin
    if(reset_i)
      recv_ptr_r <= '0;
    else begin
      if(receiving)
        recv_ptr_r <= recv_ptr_r + recv_ptr_width_lp'(1'b1);
      else if(bad_frame || clear_buffer_i)
        recv_ptr_r <= '0;
    end
  end

  always_ff @(posedge clk_i) begin
    if(receiving) begin
      buffer_r[recv_ptr_r] = rx_axis_tdata_lo;
    end
  end

  always_comb begin
    case(rx_axis_tkeep_lo)
      8'b1111_1111:
        packet_size_remaining = 16'd8;
      8'b0111_1111:
        packet_size_remaining = 16'd7;
      8'b0011_1111:
        packet_size_remaining = 16'd6;
      8'b0001_1111:
        packet_size_remaining = 16'd5;
      8'b0000_1111:
        packet_size_remaining = 16'd4;
      8'b0000_0111:
        packet_size_remaining = 16'd3;
      8'b0000_0011:
        packet_size_remaining = 16'd2;
      8'b0000_0001:
        packet_size_remaining = 16'd1;
    endcase
  end

  always_ff @(posedge clk_i) begin
    if(reset_i)
      packet_size_r <= '0;
    else begin
      if(receiving && rx_axis_tlast_lo)
        packet_size_r <= (recv_ptr_r * 8) + packet_size_remaining;
      else if(clear_buffer_i)
        packet_size_r <= '0;
    end
  end

  always_ff @(posedge clk_i) begin
    if(reset_i)
      buffer_empty_r <= 1'b1;
    else begin
      if(clear_buffer_i)
        buffer_empty_r <= 1'b1;
      else if(!bad_frame && rx_axis_tlast_lo)
        buffer_empty_r <= 1'b0;
    end
  end

    eth_mac_mii_fifo #(.AXIS_DATA_WIDTH(64)) eth_mac_mii_fifo_rx
    (
    .rst(reset_i)
    ,.logic_clk(clk_i)
    ,.logic_rst(reset_i)

    ,.tx_axis_tdata(/* UNUSED */)
    ,.tx_axis_tkeep(/* UNUSED */)
    ,.tx_axis_tvalid(1'b0)
    ,.tx_axis_tready(/* UNUSED */)
    ,.tx_axis_tlast(/* UNUSED */)
    ,.tx_axis_tuser(/* UNUSED */)

    ,.rx_axis_tdata(rx_axis_tdata_lo)
    ,.rx_axis_tkeep(rx_axis_tkeep_lo)
    ,.rx_axis_tvalid(rx_axis_tvalid_lo)
    ,.rx_axis_tready(rx_axis_tready_lo)
    ,.rx_axis_tlast(rx_axis_tlast_lo)
    ,.rx_axis_tuser(rx_axis_tuser_lo)

    ,.mii_rx_clk(clk_i)
    ,.mii_rxd(mii_rxd_i)
    ,.mii_rx_dv(mii_rx_dv_i)
    ,.mii_rx_er(mii_rx_er_i)
    ,.mii_tx_clk(clk_i)
    ,.mii_txd(/* UNUSED */)
    ,.mii_tx_en(/* UNUSED */)
    ,.mii_tx_er(/* UNUSED */)

    ,.tx_error_underflow()
    ,.tx_fifo_overflow()
    ,.tx_fifo_bad_frame()
    ,.tx_fifo_good_frame()
    ,.rx_error_bad_frame()
    ,.rx_error_bad_fcs()
    ,.rx_fifo_overflow()
    ,.rx_fifo_bad_frame()
    ,.rx_fifo_good_frame()

    ,.ifg_delay(8'd24)
    );


endmodule
