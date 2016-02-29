require_relative '../../spec_helper'

require 'nero/process'

describe 'Nero::Process' do
  before do
    ENV['HELLO'] = 'hello'

    @proc = Nero::Process.new('/usr/bin/env irb --prompt=default')
    @proc.shell_prompt = /^irb\(main\):[0-9]{3}:[0-9]. /
  end

  it 'gets doesn\'t return unterminated lines' do
    @proc.shell_prompt = nil
    sleep 1
    expect(@proc.gets).to eq nil

    @proc.puts('0')
    sleep 1
    expect(@proc.gets).to eq 'irb(main):001:0> => 0'
  end

  it 'exchange message with irb' do
    @proc.puts '1+2'
    sleep 1
    expect(@proc.gets).to eq '=> 3'
  end

  it 'multiline message from irb' do
    @proc.puts 'puts "puts"'
    sleep 1
    expect(@proc.gets).to eq 'puts'
    expect(@proc.gets).to eq '=> nil'
  end

  it 'irb exits by itself' do
    @proc.puts 'exit'
    sleep 1
    expect(@proc.open?).to be false
    expect(@proc.pid).to eq nil
    expect(@proc.gets).to eq nil
    expect{@proc.puts 'hello'}.to_not raise_error
  end

  it 'env is passed to child' do
    @proc.puts 'ENV[\'HELLO\']'
    sleep 1
    expect(@proc.gets).to eq '=> "hello"'
  end
end