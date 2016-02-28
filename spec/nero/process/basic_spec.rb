require_relative '../../spec_helper'

require 'nero/process'

describe 'Nero::Process' do
  it 'open /usr/bin/env irb' do
    proc = Nero::Process.new('/usr/bin/env irb')
    expect(proc.open?).to be true
    proc.close
  end

  it 'open non-existent program and raise error' do
    expect{Nero::Process.new('/bin/doesnt-exist-hopefully')}.to raise_error Errno::ENOENT
  end
end