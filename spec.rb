require 'fileutils'
require 'mocha'
RSpec.configure { |config| config.mock_with :mocha }

describe 'opening a file' do
  let :filename do
    '/tmp/file.txt'
  end

  it 'should call File.open' do
    File.expects(:read).with(filename).returns('File Contents')
    #@test = File.read(filename)
  end
end
