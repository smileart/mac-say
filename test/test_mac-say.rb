require 'helper'
require 'mac/say'

class TestMac::Say < Minitest::Test

  def test_version
    version = Mac::Say.const_get('VERSION')

    assert(!version.empty?, 'should have a VERSION constant')
  end

end
