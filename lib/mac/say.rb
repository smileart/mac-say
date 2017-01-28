require_relative 'say/version'
require 'English'

# Wrapper namespace module for a Say class
module Mac

  # A class wrapper around the MacOS `say` commad
  # Allows to use simple TTS on Mac right from Ruby scripts
  class Say
    # Default Say configuration
    # Use USE_FAKE_SAY environment variable to fake the actual `say` command
    DEFAULTS = {
      say_path: ENV['USE_FAKE_SAY'] ? ENV['USE_FAKE_SAY'] : '/usr/bin/say',
      voice: :alex,
      rate: 175,
      file: nil
    }

    # A regex pattern to parse say voices list output
    VOICES_PATTERN = %r{(^[\w-]+)\s+([\w-]+)\s+#\s([\p{Graph}\p{Zs}]+$)}i

    # An error raised when `say` command couldn't be found
    class CommandNotFound < StandardError; end

    # An error raised when a text file couldn't be found
    class FileNotFound < StandardError; end

    # An error raised when the given voice isn't valid
    class VoiceNotFound < StandardError; end

    # An error raised when there is no a feature of voice to match
    class UnknownVoiceFeature < StandardError; end

    # Current voices list
    #
    # @return [Array<Hash>] an array of voices Hashes supported by the say command
    # @example Get all the voices
    #   Mac::Say.voices #=>
    #      [
    #          {
    #              :name => :agnes,
    #              :iso_code => {
    #                  :language => :en,
    #                  :country => :us
    #              },
    #              :sample => "Isn't it nice to have a computer that will talk to you?"
    #          },
    #          {
    #              :name => :albert,
    #              :iso_code => {
    #                  :language => :en,
    #                  :country => :us
    #              },
    #              :sample => " I have a frog in my throat. No, I mean a real frog!"
    #          },
    #          ...
    #      ]
    attr_reader :voices

    # Current config
    # @return [Hash] a Hash with current configuration
    attr_reader :config

    # Say constructor: sets initial configuration for say command to use
    #
    # @param say_path [String] the full path to the say app binary (default: '/usr/bin/say')
    # @param voice [Symbol] voice to be used by the say command (default: :alex)
    # @param rate [Integer] speech rate in words per minute (default: 175) accepts values in (175..720)
    # @param file [String] path to the file to read (default: nil)
    #
    # @raise [VoiceNotFound] if the given voice doesn't exist or wasn't installed
    def initialize(voice: :alex, rate: 175, file: nil, say_path: '/usr/bin/say')
      args = {
        voice: voice,
        rate: rate,
        file: file,
        say_path: say_path
      }

      @config = DEFAULTS.merge(args)
      @voices = nil
      load_voices

      raise VoiceNotFound, "Voice '#{@config[:voice]}' isn't a valid voice" unless valid_voice? @config[:voice]
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
      mac = self.new(voice: voice.downcase.to_sym)
      mac.say(string: string)
    end

    # Read the given string/file with the given voice and rate
    #
    # Providing file, voice or rate arguments changes instance state and influence
    # all the subsequent #say calls unless they have their own custom arguments
    #
    # @param string [String] a text to read using say command
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

    # Find a voice by one of its features (e.g. :name, :language, :country)
    #
    # @return [Array<Hash>, Hash] an array with all the voices matched by the feature or
    #   a voice Hash if only one voice corresponds to the feature
    #
    # @raise [UnknownVoiceFeature] if the voice feature isn't supported
    def self.voice(feature, name)
      mac = self.new
      mac.voice(feature, name)
    end

    # Find a voice by one of its features (e.g. :name, :language, :country)
    #
    # @return [Array<Hash>, Hash] an array with all the voices matched by the feature or
    #   a voice Hash if only one voice corresponds to the feature
    #
    # @raise [UnknownVoiceFeature] if the voice feature isn't supported
    def voice(feature, value)
      raise UnknownVoiceFeature, "Voice has no '#{feature}' feature" unless [:name, :language, :country].include?(feature)

      if feature == :name
        found_voices = @voices.find_all {|v| v[feature] == value}
      else
        found_voices = @voices.find_all {|v| v[:iso_code][feature] == value}
      end

      found_voices.count == 1 ? found_voices.first : found_voices
    end

    # Get all the voices supported by the say command on current machine
    #
    # @return [Array<Hash>] an array of voices Hashes supported by the say command
    # @example Get all the voices
    #   Mac::Say.voices #=>
    #      [
    #          {
    #              :name => :agnes,
    #              :iso_code => {
    #                  :language => :en,
    #                  :country => :us
    #              },
    #              :sample => "Isn't it nice to have a computer that will talk to you?"
    #          },
    #          {
    #              :name => :albert,
    #              :iso_code => {
    #                  :language => :en,
    #                  :country => :us
    #              },
    #              :sample => " I have a frog in my throat. No, I mean a real frog!"
    #          },
    #          ...
    #      ]
    def self.voices
      mac = self.new
      mac.voices
    end

    alias_method :read, :say

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

      return say_command, $CHILD_STATUS.exitstatus
    end

    # Command generation using current config
    #
    # @return [String] a command to be executed with all the arguments
    #
    # @raise [CommandNotFound] if the say command wasn't found
    # @raise [FileNotFound] if the given file wasn't found or isn't readable by the current user
    def generate_command
      raise CommandNotFound, "Command `say` couldn't be found by '#{@config[:say_path]}' path" unless valid_command_path? @config[:say_path]

      if @config[:file] && !valid_file_path?(@config[:file])
        raise FileNotFound, "File '#{@config[:file]}' wasn't found or it's not readable by the current user"
      end

      file = @config[:file] ? " -f #{@config[:file]}" : ''
      "#{@config[:say_path]}#{file} -v '#{@config[:voice]}' -r #{@config[:rate].to_i}"
    end

    # Parsing voices list from the `say` command itself
    # Memoise voices list for the instance
    #
    # @return [Array<Hash>, nil] an array of voices Hashes supported by the say command or nil
    #   if voices where parsed before and stored in @voices instance variable
    #
    # @raise [CommandNotFound] if the say command wasn't found
    def load_voices
      return if @voices
      raise CommandNotFound, "Command `say` couldn't be found by '#{@config[:say_path]}' path" unless valid_command_path? @config[:say_path]

      output = `#{@config[:say_path]} -v '?'`

      @voices = output.scan VOICES_PATTERN
      @voices.map! do |voice|
        lang = voice[1].split(/[_-]/)

        {
          name: voice[0].downcase.to_sym,
          iso_code: { language: lang[0].downcase.to_sym, country: lang[1].downcase.to_sym },
          sample: voice[2]
        }
      end
    end

    # Checks voice existence by the name
    # Loads voices if they weren't loaded before
    #
    # @return [Boolean] if the voices name in the list of voices
    #
    # @raise [CommandNotFound] if the say command wasn't found
    def valid_voice?(name)
      load_voices unless @voices

      v = voice(:name, name)
      v && !v.empty?
    end

    # Checks say command existence by the path
    #
    # @return [Boolean] if the command exists and if it is executable
    def valid_command_path?(path)
      File.exist?(path) && File.executable?(path)
    end

    # Checks text file existence by the path
    #
    # @return [Boolean] if the file exists and if it is readable
    def valid_file_path?(path)
      path && File.exist?(path) && File.readable?(path)
    end
  end
end
