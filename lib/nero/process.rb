require 'pty'
require 'stringio'
require 'forwardable'
require 'io/console'

module Nero
  class Process
    extend Forwardable

    attr_accessor :shell_prompt

    def initialize(*args, **opts)
      @pty_r, @pty_w, @pty_pid = PTY.spawn(*args)
      @buffer = StringIO.new
      @shell_prompt = ''

      @pty_r.echo = false
      @pty_w.echo = false
    end

    def open?
      PTY.check(pty_pid).nil?
    end

    def close
      return unless pty_pid

      ::Process.kill('TERM', pty_pid)
      @pty_r = @pty_w = @pty_pid = nil
    end

    def read(n)
      fill_buffer
      buffer.read(n)
    end

    def readline
      fill_buffer
      line = buffer.gets&.chomp

      if shell_prompt && line
        mlen = line.match(shell_prompt).to_s.length
        line = line[mlen..-1]
        line = nil if line.empty?
      end

      line
    end

    def readlines
      fill_buffer
      buffer.readlines.map(&:chomp)
    end

    def_delegators :pty_w, :puts, :write

    alias_method :gets, :readline
    attr :buffer

    private

    attr :pty_r, :pty_w, :pty_pid

    def fill_buffer
      buffer.string = buffer.string[buffer.tell..-1]
      buffer << pty_r.read_nonblock(4096)
    rescue IO::WaitReadable
    ensure
      buffer.rewind
    end
  end
end
