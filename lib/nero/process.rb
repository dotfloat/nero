require 'pty'
require 'stringio'
require 'io/console'

module Nero
  class Process
    attr_accessor :shell_prompt

    def initialize(*args, **opts)
      @pty_r, @pty_w, @pid = PTY.spawn(*args)
      @buffer = StringIO.new
      @shell_prompt = ''

      @pty_r.echo = false
      @pty_w.echo = false
    end

    def pid
      return unless @pid

      if PTY.check(@pid)
        @pty_r = @pty_w = @pid = nil
      end

      @pid
    end

    def open?
      !pid.nil?
    end

    def close
      return unless pid

      ::Process.kill('TERM', pid)
      @pty_r = @pty_w = @pid = nil
    end

    def puts(*args)
      return unless pty_w

      pty_w.puts(*args)
    end

    def readline
      fill_buffer
      line = buffer.gets

      return unless line

      unless line.end_with? $/ # Check that the line is complete
        buffer.seek(-line.length, IO::SEEK_CUR)
        return
      end

      line.chomp!
      line.sub!(shell_prompt, '') if shell_prompt

      line
    end

    def readlines
      fill_buffer
      lines = buffer.readlines

      return [] if lines.empty?

      unless lines.last.end_with? $/
        buffer.seek(-lines.last.length, IO::SEEK_CUR)
        lines.pop
      end

      lines.map(&:chomp)
    end

    alias_method :gets, :readline
    attr :buffer

    private

    attr :pty_r, :pty_w

    def fill_buffer
      return unless pty_r

      pos = buffer.tell
      buffer.string = buffer.string[pos..-1]
      buffer.seek(0, IO::SEEK_END)
      buffer << pty_r.read_nonblock(4096)
    rescue IO::WaitReadable
    ensure
      buffer.rewind
    end
  end
end
