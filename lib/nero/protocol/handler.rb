require 'stringio'

module Nero
  class Protocol
    QueryStruct = Struct.new(:error, :id, :request, :response)
    private_constant :QueryStruct

    attr_accessor :io
    attr_accessor :query_req_handler
    attr_accessor :query_resp_handler

    def initialize(io = nil)
      @io = io
      @bufio = StringIO.new
      @queries = {}
    end

    def write(mesg)
      header = Header.new
      header.m_length = mesg.length
      header.m_typeid = mesg.class.const_get(:TypeID)
      io.write(header)
      io.write(mesg)

      if mesg.is_a? QueryReq
        @queries[mesg.q_id] = mesg.q_body
      end
    end

    def read
      buf = read_from_buf(Header.round_byte_length)

      return unless buf

      header = Header.new(buf)

      klass = header.m_class

      # Invalid message TypeID. Send EINVAL to show that we didn't understand.
      unless klass
        read_from_buf(header.m_length)
        write(EINVAL)
        return
      end

      unless header.m_length >= klass.round_byte_length && (buf = read_from_buf(header.m_length))
        write_back_to_buf(header)
        return
      end

      klass.new(buf)
    end

    def poll
      rd = read

      return false unless rd

      case rd.class.to_s
      when 'Nero::Protocol::QueryReq'
        return true unless query_req_handler

        query = QueryStruct.new
        query.id = rd.q_id
        query.request = rd.q_body

        query_req_handler.call(query)

        if query.error
          write(query.error.is_a?(Error) ? query : Error.new({ e_id: query.error }))
        elsif query.response
          response = QueryResp.new
          response.q_id = rd.q_id
          response.q_body = query.response
          write(response)
        else
          write(ENORESP)
        end
      when 'Nero::Protocol::QueryResp'
        req_body = @queries[rd.q_id]
        @queries.delete(rd.q_id)

        return true unless query_resp_handler

        query = QueryStruct.new
        query.id = rd.q_id
        query.request = req_body
        query.response = rd.q_body

        query_resp_handler.call(query)
      end

      true
    end

    def open?
      !!@io
    end

    private

    def read_from_buf(n)
      pos = @bufio.tell
      rd = @bufio.read(n)
      rd_len = rd&.length || 0

      if !rd || rd_len != n
        @bufio.seek(pos, IO::SEEK_SET)

        begin
          rd = io.read_nonblock(n)
        rescue IO::WaitReadable, EOFError
          return
        end

        return unless rd

        @bufio.seek(0, IO::SEEK_END)
        @bufio.write(rd)
        @bufio.seek(pos, IO::SEEK_SET)

        if rd_len + rd.length == n
          rd = @bufio.read(n)
          @bufio.string = @bufio.string[n..-1] || ''
        else
          rd = nil
        end
      end

      rd
    end

    def write_back_to_buf(buf)
      pos = @bufio.tell
      @bufio.string = buf + @bufio.string[pos..-1]
    end
  end
end
