require 'cfn_monitor/version'

describe 'Version' do
  it 'is equal to 0.1.0' do
    expect(CfnMonitor::VERSION).to eq("0.1.0")
  end
end