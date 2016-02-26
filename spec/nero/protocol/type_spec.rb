require 'spec_helper'

describe 'Nero::Protocol type correctness' do
  it 'type ids are unique' do
    expect(Nero::Protocol.types.values.uniq.length).to eq(Nero::Protocol.types.length)
  end

  it 'errors are frozen' do
    expect(Nero::Protocol.constants.select{|x| x.is_a?(Symbol) && x.to_s.start_with?('E')}.all?(&:frozen?)).to be true
  end
end
