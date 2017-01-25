require 'helper'
require 'mac/say'

describe 'Mac::Say as a macOS `say` wrapper' do
  describe 'On a class level' do
    it "must have a VERSION constant" do
      Mac::Say.const_get('VERSION').wont_be_empty
    end

    it "must return available voices as an Array of Hashes" do
      Mac::Say.voices.wont_be_empty
      Mac::Say.voices.must_be_kind_of Array
    end

    it "must return specific Hash structure for a voice" do
      voice = Mac::Say.voices.first
      voice.wont_be_empty
      voice.must_be_kind_of Hash
      voice.keys.must_equal [:name, :iso_code, :sample]
    end

    it "must return specific Hash structure for an iso_code" do
      voice = Mac::Say.voices.first
      voice.wont_be_empty
      voice[:iso_code].must_be_kind_of Hash
      voice[:iso_code].keys.must_equal [:language, :country]
    end

    it "::voice must search for a voice by name" do
      voice = Mac::Say.voice(:name, :alex)
      voice[:name].must_equal :alex
    end

    it "::voice must search for a voice by country" do
      voice = Mac::Say.voice(:country, :scotland)
      voice[:name].must_equal :fiona
    end

    it "::voice must search for a voice by language" do
      voices = Mac::Say.voice(:language, :en)
      voices.count.must_be :>, 2
    end

    it "::voice must return one voice as a Hash" do
      voice = Mac::Say.voice(:name, :alex)
      voice.must_be_kind_of Hash
    end

    it "::voice must return an Array of voices if > 1" do
      voices = Mac::Say.voice(:country, :gb)
      voices.must_be_kind_of Array
    end

    it "::say must return 0 in successive speech" do
      Mac::Say.say('42').must_equal 0
    end

    it "::say must use custom voice" do
      Mac::Say.say('42', :alex).must_equal 0
    end

    it "::say must work with multiple lines" do
      Mac::Say.say(<<-TEXT, :alex).must_equal 0
        1
        2
        3
      TEXT
    end
  end

  describe 'On an instance level' do
    before do
      @reader = Mac::Say.new
    end

    it 'must instantiate Mac::Say' do
      @reader.must_be_instance_of Mac::Say
    end

    it "#say must return 0 in successive speech" do
      @reader.say(string: '42').must_equal 0
    end
  end
end
