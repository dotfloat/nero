require 'socket'
require 'stringio'
require 'timeout'

require_relative '../../spec_helper'

describe 'Nero::Protocol error handling' do
  HEADER_QUERY = Nero::Protocol::Header.new
  HEADER_INVALID = Nero::Protocol::Header.new

  QUERY_REQ_MESG = Nero::Protocol::QueryReq.new
  QUERY_REQ_MESG_A = Nero::Protocol::QueryReq.new
  QUERY_REQ_MESG_B = Nero::Protocol::QueryReq.new

  before do
    HEADER_QUERY.m_typeid = 1
    HEADER_QUERY.m_length = 0

    HEADER_INVALID.m_typeid = 666
    HEADER_INVALID.m_length = 0

    QUERY_REQ_MESG.q_id = 1
    QUERY_REQ_MESG.q_body = 'test'

    QUERY_REQ_MESG_A.q_id = 100
    QUERY_REQ_MESG_A.q_body = 'message A'

    QUERY_REQ_MESG_B.q_id = 101
    QUERY_REQ_MESG_B.q_body = 'message B'
  end

  before do
    @sio_io = StringIO.new
    @sio_proto = Nero::Protocol.new(@sio_io)

    @cli_io, @srv_io = UNIXSocket.pair
    @cli_proto = Nero::Protocol.new(@cli_io)
    @srv_proto = Nero::Protocol.new(@srv_io)
  end

  it 'empty IO buffer' do
    expect(@cli_proto.read).to eq nil
  end

  it 'valid message' do
    @cli_proto.write(QUERY_REQ_MESG)
    expect(@srv_proto.read).to eq QUERY_REQ_MESG
  end

  it 'valid header but no message' do
    HEADER_QUERY.m_length = QUERY_REQ_MESG.length
    @cli_io.write(HEADER_QUERY)
    expect(@srv_proto.read).to eq nil
  end

  it 'header with valid typeid but zero length' do
    @cli_io.write(HEADER_QUERY)
    expect(@srv_proto.read).to eq nil
  end

  it 'valid header but partial message' do
    HEADER_QUERY.m_length = QUERY_REQ_MESG.length
    @cli_io.write(HEADER_QUERY)
    @cli_io.write(QUERY_REQ_MESG[0..HEADER_QUERY.length / 2])
    expect(@srv_proto.read).to eq nil
  end

  it 'partial header' do
    @cli_io.write(HEADER_QUERY[0..HEADER_QUERY.length/2])
    expect(@srv_proto.read).to eq nil
  end

  it 'message in two parts' do
    @sio_proto.write(QUERY_REQ_MESG)

    str = @sio_io.string

    @cli_io.write(str[0...str.length/2])
    expect(@srv_proto.read).to eq nil

    @cli_io.write(str[str.length/2..-1])
    expect(@srv_proto.read).to eq QUERY_REQ_MESG
  end

  it 'header with invalid typeid' do
    @cli_io.write(HEADER_INVALID)
    expect(@srv_proto.read).to eq nil # Server reads invalid header, sends EINVALID
    expect(@cli_proto.read).to eq Nero::Protocol::EINVAL
  end

  it 'unknown message followed by valid message' do
    mesg = 'hello'
    HEADER_INVALID.m_length = mesg.length
    @cli_io.write(HEADER_INVALID + mesg)
    @cli_proto.write(QUERY_REQ_MESG)
    expect(@srv_proto.read).to eq nil
    expect(@srv_proto.read).to eq QUERY_REQ_MESG
    expect(@cli_proto.read).to eq Nero::Protocol::EINVAL
  end

#  it 'too long message followed by valid message' do
#    @sio_proto.write(QUERY_REQ_MESG_A)
#    @cli_io.write(@sio_io.string + 'too long')
#    @cli_proto.write(QUERY_REQ_MESG_B)
#    expect(@srv_proto.read).to eq QUERY_REQ_MESG_A
#    expect(@srv_proto.read).to eq nil
#    expect(@srv_proto.open?).to eq false
#    expect(@cli_proto.read).to eq Nero::Protocol::EINVAL
#    expect(@cli_proto.read).to eq Nero::Protocol::ECLOSE
#  end
end