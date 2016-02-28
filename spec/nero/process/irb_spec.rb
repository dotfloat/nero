require_relative '../../spec_helper'

require 'nero/process'

describe 'Nero::Process' do
  before do
    @proc = Nero::Process.new('/usr/bin/env irb')
    @proc.shell_prompt = /^irb\(main\):[0-9]{3}:[0-9]. /
  end

  it 'exchange message with irb' do
    @proc.puts '1+2'
    sleep 1
    expect(@proc.gets).to eq "=> 3"
  end

  it 'irb exits by itself' do
    @proc.puts 'exit'
    sleep 1
    expect(@proc.open?).to be false
  end
end