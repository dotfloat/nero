require 'bit-struct'
require 'zlib'

module Nero
  class Protocol

    class Header < BitStruct
      unsigned :m_length, 16
      unsigned :m_typeid, 16

      def m_class
        sym = Nero::Protocol.types.rassoc(m_typeid)&.first
        Nero::Protocol.const_get(sym) if sym
      end
    end

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

    class QueryReq < BitStruct
      TypeID = 1

      unsigned :q_id, 16

      rest :q_body
    end

    class QueryResp < BitStruct
      TypeID = 2

      unsigned :q_id, 16
      unsigned :q_flags, 32

      rest :q_body
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

    # Generate error constants
    Error.hash.each { |k, v| const_set(k, Error.new({ e_id: v })) }
  end
end