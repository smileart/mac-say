# frozen_string_literal: true
require_relative 'say/version'
require_relative 'say/voices_attributes'

require 'English'

# Wrapper namespace module for a Say class
module Mac
  # A class wrapper around the MacOS `say` commad
  # Allows to use simple TTS on Mac right from Ruby scripts
  class Say
    # A regex pattern to parse say voices list output
    VOICE_PATTERN = /(^[\w\s-]+)\s+([\w-]+)\s+#\s([\p{Graph}\p{Zs}]+$)/i

    # An error raised when `say` command couldn't be found
    class CommandNotFound < StandardError; end

    # An error raised when a text file couldn't be found
    class FileNotFound < StandardError; end

    # An error raised when the given voice isn't valid
    class VoiceNotFound < StandardError; end

    # An error raised when there is no a attribute of voice to match
    class UnknownVoiceAttribute < StandardError; end

    # The list of the voice attributes available
    VOICE_ATTRIBUTES = [
      :name,
      :language,
      :country,
      :sample,
      :gender,
      :joke,
      :quality,
      :singing
    ]

    # Current voices list
    #
    # @return [Array<Hash>] an array of voices Hashes supported by the say command
    # @example Get all the voices
    #   Mac::Say.voices #=>
    #      [
    #          {
    #              :name     => :agnes,
    #              :language => :en,
    #              :country  => :us,
    #              :sample   => "Isn't it nice to have a computer that will talk to you?",
    #              :gender   => :female,
    #              :joke     => false,
    #              :quality  => :low,
    #              :singing  => false
    #          },
    #          {
    #              :name      => :albert,
    #              :language  => :en,
    #              :country   => :us,
    #              :sample    => "I have a frog in my throat. No, I mean a real frog!",
    #              :gender    => :male,
    #              :joke      => true,
    #              :quality   => :medium,
    #              :singing   => false
    #          },
    #          ...
    #      ]
    attr_reader :voices

    # Current config
    # @return [Hash] a Hash with current configuration
    attr_reader :config

    # Say constructor: sets initial configuration for say command to use
    #
    # @param say_path [String] the full path to the say app binary (default: '/usr/bin/say' or USE_FAKE_SAY environment variable)
    # @param voice [Symbol] voice to be used by the say command (default: :alex)
    # @param rate [Integer] speech rate in words per minute (default: 175) accepts values in (175..720)
    # @param file [String] path to the file to read (default: nil)
    #
    # @raise [VoiceNotFound] if the given voice doesn't exist or wasn't installed
    def initialize(voice: :alex, rate: 175, file: nil, say_path: ENV['USE_FAKE_SAY'] || '/usr/bin/say')
      @config = {
        say_path: say_path,
        voice: voice,
        rate: rate,
        file: file
      }

      @voices = nil
      load_voices

      raise VoiceNotFound, "Voice '#{voice}' isn't a valid voice" unless valid_voice? voice
    end

    # Read the given string with the given voice
    #
    # @param string [String] a text to read using say command
    # @param voice [Symbol] voice to be used by the say command (default: :alex)
    #
    # @return [Array<String, Integer>] an array with the actual say command used
    #  and it's exit code. E.g.: ["/usr/bin/say -v 'alex' -r 175", 0]
    #
    # @raise [CommandNotFound] if the say command wasn't found
    # @raise [VoiceNotFound] if the given voice doesn't exist or wasn't installed
    def self.say(string, voice = :alex)
      mac = new(voice: voice.downcase.to_sym)
      mac.say(string: string)
    end

    # Read the given string/file with the given voice and rate
    #
    # Providing file, voice or rate arguments changes instance state and influence
    # all the subsequent #say calls unless they have their own custom arguments
    #
    # @param string [String] a text to read using say command (default: nil)
    # @param file [String] path to the file to read (default: nil)
    # @param voice [Symbol] voice to be used by the say command (default: :alex)
    # @param rate [Integer] speech rate in words per minute (default: 175) accepts values in (175..720)
    #
    # @return [Array<String, Integer>] an array with the actual say command used
    #  and it's exit code. E.g.: ["/usr/bin/say -v 'alex' -r 175", 0]
    #
    # @raise [CommandNotFound] if the say command wasn't found
    # @raise [VoiceNotFound] if the given voice doesn't exist or wasn't installed
    # @raise [FileNotFound] if the given file wasn't found or isn't readable by the current user
    #
    # @example Say something (for more examples check README.md or examples/examples.rb files)
    #   Mac::Say.new.say string: 'Hello world' #=> ["/usr/bin/say -v 'alex' -r 175", 0]
    #   Mac::Say.new.say string: 'Hello world', voice: :fiona #=> ["/usr/bin/say -v 'fiona' -r 175", 0]
    #   Mac::Say.new.say file: /tmp/text.txt, rate: 300 #=> ["/usr/bin/say -f /tmp/text.txt -v 'alex' -r 300", 0]
    def say(string: nil, file: nil, voice: nil, rate: nil)
      if voice
        raise VoiceNotFound, "Voice '#{voice}' isn't a valid voice" unless valid_voice?(voice)
        @config[:voice] = voice
      end

      if file
        raise FileNotFound, "File '#{file}' wasn't found or it's not readable by the current user" unless valid_file_path?(file)
        @config[:file] = file
      end

      @config[:rate] = rate if rate

      execute_command(string)
    end

    # Look for voices by their attributes (e.g. :name, :language, :country, :gender, etc.)
    #
    # @overload voice(attribute, value)
    #   @param attribute [Symbol] the attribute to search voices by
    #   @param value [Symbol, String] the value of the attribute to search voices by
    # @overload voice(&block)
    #   @yield [voice] Passes the given block to @voices.find_all
    #
    # @return [Array<Hash>, Hash, nil] an array with all the voices matched by the attribute or
    #   a voice Hash if only one voice corresponds to the attribute, nil if no voices found
    #
    # @example Find voices by one or more attributes
    #
    #   Mac::Say.new.voice(:joke, false)
    #   Mac::Say.new.voice(:gender, :female)
    #
    #   Mac::Say.new.voice { |v| v[:joke] == true && v[:gender] == :female }
    #   Mac::Say.new.voice { |v| v[:language] == :en && v[:gender] == :male && v[:quality] == :high && v[:joke] == false }
    #
    # @raise [UnknownVoiceAttribute] if the voice attribute isn't supported    def self.voice(attribute = nil, value = nil, &block)
    def self.voice(attribute = nil, value = nil, &block)
      mac = new

      if block_given?
        mac.voice(&block)
      else
        mac.voice(attribute, value)
      end
    end

    # Look for voices by their attributes (e.g. :name, :language, :country, :gender, etc.)
    #
    # @overload voice(attribute, value)
    #   @param attribute [Symbol] the attribute to search voices by
    #   @param value [Symbol, String] the value of the attribute to search voices by
    # @overload voice(&block)
    #   @yield [voice] Passes the given block to @voices.find_all
    #
    # @return [Array<Hash>, Hash, nil] an array with all the voices matched by the attribute or
    #   a voice Hash if only one voice corresponds to the attribute, nil if no voices found
    #
    # @example Find voices by one or more attributes
    #
    #   Mac::Say.new.voice(:joke, false)
    #   Mac::Say.new.voice(:gender, :female)
    #
    #   Mac::Say.new.voice { |v| v[:joke] == true && v[:gender] == :female }
    #   Mac::Say.new.voice { |v| v[:language] == :en && v[:gender] == :male && v[:quality] == :high && v[:joke] == false }
    #
    # @raise [UnknownVoiceAttribute] if the voice attribute isn't supported
    def voice(attribute = nil, value = nil, &block)
      return unless (attribute && !value.nil?) || block_given?
      raise UnknownVoiceAttribute, "Voice has no '#{attribute}' attribute" if attribute && !VOICE_ATTRIBUTES.include?(attribute)

      if block_given?
        found_voices = @voices.find_all(&block)
      else
        found_voices = @voices.find_all {|voice| voice[attribute] === value }
      end

      return if found_voices.empty?
      found_voices.count == 1 ? found_voices.first : found_voices
    end

    # Get all the voices supported by the say command on current machine
    #
    # @return [Array<Hash>] an array of voices Hashes supported by the say command
    # @example Get all the voices
    #   Mac::Say.voices #=>
    #      [
    #          {
    #              :name      => :agnes,
    #              :language  => :en,
    #              :country   => :us,
    #              :sample    => "Isn't it nice to have a computer that will talk to you?",
    #              :gender    => :female,
    #              :joke      => false,
    #              :quality   => :low,
    #              :singing   => false
    #          },
    #          {
    #              :name      => :albert,
    #              :language  => :en,
    #              :country   => :us,
    #              :sample    => "I have a frog in my throat. No, I mean a real frog!",
    #              :gender    => :male,
    #              :joke      => true,
    #              :quality   => :medium,
    #              :singing   => false
    #          },
    #          ...
    #      ]
    def self.voices
      mac = new
      mac.voices
    end

    alias read say

    private

    # Actual command execution using current config and the string given
    #
    # @param string [String] a text to read using say command
    #
    # @return [Array<String, Integer>] an array with the actual say command used
    #  and it's exit code. E.g.: ["/usr/bin/say -v 'alex' -r 175", 0]
    #
    # @raise [CommandNotFound] if the say command wasn't found
    # @raise [FileNotFound] if the given file wasn't found or isn't readable by the current user
    def execute_command(string = nil)
      say_command = generate_command
      say = IO.popen(say_command, 'w+')
      say.write(string) if string
      say.close

      [say_command, $CHILD_STATUS.exitstatus]
    end

    # Command generation using current config
    #
    # @return [String] a command to be executed with all the arguments
    #
    # @raise [CommandNotFound] if the say command wasn't found
    # @raise [FileNotFound] if the given file wasn't found or isn't readable by the current user
    def generate_command
      say_path = @config[:say_path]
      file     = @config[:file]

      raise CommandNotFound, "Command `say` couldn't be found by '#{@config[:say_path]}' path" unless valid_command_path? say_path

      if file && !valid_file_path?(file)
        raise FileNotFound, "File '#{file}' wasn't found or it's not readable by the current user"
      end

      file = file ? " -f #{@config[:file]}" : ''
      "#{@config[:say_path]}#{file} -v '#{@config[:voice]}' -r #{@config[:rate].to_i}"
    end

    # Parsing voices list from the `say` command itself
    # Memoize voices list for the instance
    #
    # @return [Array<Hash>, nil] an array of voices Hashes supported by the say command or nil
    #   if voices where parsed before and stored in @voices instance variable
    #
    # @raise [CommandNotFound] if the say command wasn't found
    def load_voices
      return if @voices

      say_path = @config[:say_path]
      raise CommandNotFound, "Command `say` couldn't be found by '#{say_path}' path" unless valid_command_path? say_path

      @voices = `#{say_path} -v '?'`.scan(VOICE_PATTERN).map do |voice|
        lang = voice[1].split(/[_-]/)
        name = voice[0].strip.downcase.to_sym

        additional_attributes = ADDITIONAL_VOICE_ATTRIBUTES[name] || ADDITIONAL_VOICE_ATTRIBUTES[:_unknown_voice]

        {
          name: name,
          language: lang[0].downcase.to_sym,
          country: lang[1].downcase.to_sym,
          sample: voice[2].strip
        }.merge(additional_attributes)
      end
    end

    # Checks voice existence by the name
    # Loads voices if they weren't loaded before
    #
    # @param name [String, Symbol] the name of the voice to validate
    #
    # @return [Boolean] if the voices name in the list of voices
    #
    # @raise [CommandNotFound] if the say command wasn't found
    def valid_voice?(name)
      load_voices unless @voices
      voice(:name, name)
    end

    # Checks say command existence by the path
    #
    # @param path [String] the path of the `say` command to validate
    #
    # @return [Boolean] if the command exists and if it is executable
    def valid_command_path?(path)
      File.exist?(path) && File.executable?(path)
    end

    # Checks text file existence by the path
    #
    # @param path [String] the path of the text file validate
    #
    # @return [Boolean] if the file exists and if it is readable
    def valid_file_path?(path)
      path && File.exist?(path) && File.readable?(path)
    end
  end
end
