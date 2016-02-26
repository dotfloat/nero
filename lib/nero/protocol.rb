require 'stringio'
require 'bit-struct'
require 'zlib'

module Nero
  class Protocol

    #
    # struct np_header {
    #     uint16_t m_length;
    #     uint16_t m_typeid;
    # };
    #
    class Header < BitStruct
      unsigned :m_length, 16
      unsigned :m_typeid, 16

      def m_class
        sym = Nero::Protocol.types.rassoc(m_typeid)&.first
        Nero::Protocol.const_get(sym) if sym
      end
    end

    #
    # struct np_error {
    #     uint16_t e_id;
    # };
    #
    # enum {
    #     NP_EINVAL = 0,
    #     NP_ECLOSE = 1,
    # }
    #

    class Error < BitStruct
      TypeID = 0

      unsigned :e_id, 16

      alias_method :_e_id=, :e_id=
      private :_e_id=

      def e_id=(x)
        x = self.class.hash.fetch(x) if x.is_a? Symbol
        _e_id = x
      end

      def to_sym
        self.class.rhash.fetch(e_id, :EUNKNOWN)
      end

      def inspect
        "#<#{self.class} #{to_sym}>"
      end

      def self.hash
        @hash ||= Hash[
            EINVAL: 0,
            ECLOSE: 1,
            ETIMEOUT: 2,
            ENORESP: 3,
            EUNKNOWN: 0xffff,
        ]
      end

      def self.rhash
        @invhash ||= hash.invert
      end
    end

    Error.hash.each { |k, v| const_set(k, Error.new({ e_id: v })) }

    class QueryReq < BitStruct
      TypeID = 1

      unsigned :q_id, 16

      rest :q_body
    end

    QueryStruct = Struct.new(:error, :id, :request, :response)
    private_constant :QueryStruct

    class QueryResp < BitStruct
      TypeID = 2

      unsigned :q_id, 16
      unsigned :q_flags, 32

      rest :q_body
    end

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

    def self.types
      return @types if @types

      @types = {}

      constants.each do |c|
        klass = const_get(c)
        next unless klass.is_a?(Class)

        begin
          typeid = klass.const_get(:TypeID)
        rescue NameError
          next
        end

        @types[c] = typeid
      end

      @types
    end
  end
end
