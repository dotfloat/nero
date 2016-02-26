require 'socket'
require 'stringio'

require_relative '../../spec_helper'

describe 'Nero::Protocol query' do
  QUERY_REQ_MESG = Nero::Protocol::QueryReq.new
  QUERY_RESP_MESG = Nero::Protocol::QueryResp.new

  before do
    QUERY_REQ_MESG.q_id = 1
    QUERY_REQ_MESG.q_body = 'query request'

    QUERY_RESP_MESG.q_id = 1
    QUERY_RESP_MESG.q_body = 'query response'
  end

  before do
    @sio_io = StringIO.new
    @sio_proto = Nero::Protocol.new(@sio_io)

    @cli_io, @srv_io = UNIXSocket.pair
    @cli_proto = Nero::Protocol.new(@cli_io)
    @srv_proto = Nero::Protocol.new(@srv_io)
  end

  it 'use query_req_handler' do
    @srv_proto.query_req_handler = ->(query) do
      query.response = QUERY_RESP_MESG.q_body
    end

    @cli_proto.write(QUERY_REQ_MESG)
    @srv_proto.poll
    expect(@cli_proto.read).to eq QUERY_RESP_MESG
  end

  it 'use query_resp_handler' do
    @srv_proto.query_req_handler = ->(query) do
      query.response = QUERY_RESP_MESG.q_body
    end

    @cli_proto.query_resp_handler = ->(query) do
      expect(query.request).to eq QUERY_REQ_MESG.q_body
      expect(query.response).to eq QUERY_RESP_MESG.q_body
    end

    @cli_proto.write(QUERY_REQ_MESG)
    @srv_proto.poll
    @cli_proto.poll
  end

  it 'use buffered query' do
    @srv_proto.query_req_handler = ->(query) do
      const_get
    end
  end

  it 'use correct id on query_req_handler' do
    @srv_proto.query_req_handler = ->(query) do
      query.response = QUERY_RESP_MESG.q_body
    end

    50.times do
      id = Random.rand(0xffff)
      q = Nero::Protocol::QueryReq.new({ q_id: id, q_body: 'query request' })

      @cli_proto.write(q)
      @srv_proto.poll
      r = @cli_proto.read

      expect(r&.q_id).to eq id
    end
  end
end