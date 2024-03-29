# frozen_string_literal: true
require 'helper'
require 'mac/say'
require 'mac/say/voices_attributes'

describe 'Mac::Say as a macOS `say` wrapper' do
  describe 'On a class level' do
    before do
      @say_path = ENV['USE_FAKE_SAY'] ? ENV['USE_FAKE_SAY'] : '/usr/bin/say'
    end

    it 'must have a VERSION constant' do
      _(Mac::Say.const_get('VERSION')).wont_be_empty
    end

    it 'must return available voices as an Array of Hashes' do
      _(Mac::Say.voices).wont_be_empty
      _(Mac::Say.voices).must_be_kind_of Array
    end

    it 'must return specific Hash structure for a voice' do
      voice = Mac::Say.voice(:name, :alex)
      _(voice).wont_be_empty
      _(voice).must_be_kind_of Hash
      _(voice.keys).must_equal Mac::Say::VOICE_ATTRIBUTES
    end

    it 'must return additional attributes for known voices' do
      voice_name = :alex
      voice = Mac::Say.voice(:name, voice_name)
      additional_voice_attributes = ADDITIONAL_VOICE_ATTRIBUTES[voice_name]

      _(voice[:gender]).must_equal additional_voice_attributes[:gender]
      _(voice[:joke]).must_equal additional_voice_attributes[:joke]
      _(voice[:quality]).must_equal additional_voice_attributes[:quality]
    end

    it '.voice must search for a voice using single attribute' do
      voice = Mac::Say.voice(:name, :alex)
      _(voice[:name]).must_equal :alex
    end

    it '.voice must search for a voice using block given' do
      voices = Mac::Say.voice {|voice| voice[:language] == :en && voice[:joke] == false }
      _(voices).must_be_kind_of Array
    end

    it '.voice must return one voice as a Hash' do
      voice = Mac::Say.voice(:name, :alex)
      _(voice).must_be_kind_of Hash
    end

    # For this test to pass you'd have to have more than
    # one British voice on your machine!
    it '.voice must return an Array of voices if > 1' do
      voices = Mac::Say.voice(:country, :gb)
      _(voices).must_be_kind_of Array
    end

    it ".voice must return nil if voice wasn't found" do
      voices = Mac::Say.voice(:name, :xxx)
      _(voices).must_be_nil
    end


    it '.say must return 0 in successive speech' do
      expectation = ["#{@say_path} -v 'alex' -r 175", 0]
      _(Mac::Say.say('42')).must_equal expectation
    end

    it '.say must use custom voice' do
      expectation = ["#{@say_path} -v 'alex' -r 175", 0]
      _(Mac::Say.say('42', :alex)).must_equal expectation
    end

    it '.say must work with multiple lines' do
      expectation = ["#{@say_path} -v 'alex' -r 175", 0]
      _(Mac::Say.say(<<-TEXT, :alex)).must_equal expectation
        1
        2
        3
      TEXT
    end

    it '.say must fail on wrong voice' do
      _{
        Mac::Say.say 'OMG! I lost my voice!', :wrong
      }.must_raise Mac::Say::VoiceNotFound
    end

    it '.voice must fail on wrong voice attribute' do
      _{
        Mac::Say.voice(:tone, :enthusiastic)
      }.must_raise Mac::Say::UnknownVoiceAttribute
    end
  end

  describe "On an instance level" do
    before do
      @reader   = Mac::Say.new
      @say_path = @reader.config[:say_path]
    end

    it 'must instantiate Mac::Say' do
      _(@reader).must_be_instance_of Mac::Say
    end

    it '#say must return 0 on successive speech' do
      expectation = ["#{@say_path} -v 'alex' -r 175", 0]
      _(@reader.say(string: '42')).must_equal expectation
    end

    it '#read must be a synonym of #say' do
      expectation = ["#{@say_path} -v 'alex' -r 175", 0]
      _(@reader.read(string: '42')).must_equal expectation
    end

    it '#say must support :file' do
      absolute_path = File.absolute_path './fixtures/text/en_gb_test.txt', File.dirname(__FILE__)
      expectation = ["#{@say_path} -f #{absolute_path} -v 'alex' -r 175", 0]

      _(@reader.say(file: absolute_path)).must_equal expectation
    end

    it '#say must read :file from initial config' do
      absolute_path = File.absolute_path './fixtures/text/en_gb_test.txt', File.dirname(__FILE__)
      expectation = ["#{@say_path} -f #{absolute_path} -v 'alex' -r 175", 0]

      @reader = Mac::Say.new(file: absolute_path)
      _(@reader.say).must_equal expectation
    end

    it 'must return nil additional attrs for unknown voices' do
      if ENV['USE_FAKE_SAY']
        voice = @reader.voice(:name, :test)

        _(voice[:gender]).must_be_nil
        _(voice[:joke]).must_be_nil
        _(voice[:quality]).must_be_nil
      end
    end

    it '#say must change :file from initial config' do
      gb_absolute_path = File.absolute_path './fixtures/text/en_gb_test.txt', File.dirname(__FILE__)
      us_absolute_path = File.absolute_path './fixtures/text/en_us_test.txt', File.dirname(__FILE__)

      expectation = ["#{@say_path} -f #{us_absolute_path} -v 'alex' -r 175", 0]

      # init
      @reader = Mac::Say.new(file: gb_absolute_path)
      _(@reader.config[:file]).must_equal gb_absolute_path

      # change
      _(@reader.say(file: us_absolute_path)).must_equal expectation
      _(@reader.config[:file]).must_equal us_absolute_path
    end

    it '#say must prioritise :file over :string' do
      absolute_path = File.absolute_path './fixtures/text/en_gb_test.txt', File.dirname(__FILE__)
      expectation = ["#{@say_path} -f #{absolute_path} -v 'alex' -r 175", 0]

      _(@reader.say(string: 'test', file: absolute_path)).must_equal expectation
    end

    it '#say must support custom :rate' do
      expectation = ["#{@say_path} -v 'alex' -r 250", 0]
      _(@reader.say(string: '42', rate: 250)).must_equal expectation
    end

    it '#say must support custom :voice' do
      expectation = ["#{@say_path} -v 'fiona' -r 175", 0]
      _(@reader.say(string: '42', voice: :fiona)).must_equal expectation
    end

    it '#say must change the :voice' do
      expectation = ["#{@say_path} -v 'fiona' -r 175", 0]
      _(@reader.config[:voice]).must_equal :alex

      _(@reader.say(string: '42', voice: :fiona)).must_equal expectation
      _(@reader.config[:voice]).must_equal :fiona

      _(@reader.say(string: '13')).must_equal expectation
    end

    it '#say must change the :rate' do
      expectation = ["#{@say_path} -v 'alex' -r 300", 0]
      _(@reader.config[:rate]).must_equal 175

      _(@reader.say(string: '42', rate: 300)).must_equal expectation
      _(@reader.config[:rate]).must_equal 300

      _(@reader.say(string: '13')).must_equal expectation
    end

    it '#say must fail on wrong initial voice' do
      _{
        talker = Mac::Say.new(voice: :wrong)
        talker.say string: 'OMG! I lost my voice!'
      }.must_raise Mac::Say::VoiceNotFound
    end

    it '#say must fail on wrong dynamic voice' do
      _{
        talker = Mac::Say.new
        talker.say string: 'OMG! I lost my voice!', voice: :wrong
      }.must_raise Mac::Say::VoiceNotFound
    end

    it '#voice must fail on wrong say path' do
      _{
        Mac::Say.new(say_path: '/wrong/wrong/path').voice(:name, :alex)
      }.must_raise Mac::Say::CommandNotFound
    end

    it '#say must fail on wrong say path' do
      _{
        Mac::Say.new(say_path: '/wrong/wrong/path').say 'test'
      }.must_raise Mac::Say::CommandNotFound
    end

    it '#say must fail on wrong file path' do
      _{
        Mac::Say.new.say(file: '/wrong/wrong/path')
      }.must_raise Mac::Say::FileNotFound
    end

    it '#voice must fail on wrong attribute' do
      _{
        Mac::Say.new.voice(:articulation, :nostalgic)
      }.must_raise Mac::Say::UnknownVoiceAttribute
    end

    it '#say must fail on initial wrong file path' do
      _{
        Mac::Say.new(file: '/wrong/wrong/path').say
      }.must_raise Mac::Say::FileNotFound
    end
  end
end
