require_relative 'say/version'
require 'English'

module Mac
  class Say
    DEFAULTS = {
      say_path: ENV['USE_FAKE_SAY'] ? ENV['USE_FAKE_SAY'] : '/usr/bin/say',
      voice: :alex,
      rate: 175,
      file: nil
    }

    VOICES_PATTERN = %r{(^[\w-]+)\s+([\w-]+)\s+#\s([\p{Graph}\p{Zs}]+$)}i

    class CommandNotFound < StandardError; end
    class FileNotFound < StandardError; end
    class VoiceNotFound < StandardError; end
    class UnknownVoiceFeature < StandardError; end

    attr_reader :voices

    # @param say_path [String] ('/usr/bin/say') the full path to the say app binary
    # @param voice [Symbol] (:alex) voice to be used by the say command
    # @param rate [Integer] (175) speech ratei words per minute (175..720)
    # @param file [String] (nil) path to the file to read
    def initialize(**args)
      @config = DEFAULTS.merge args
      @voices = nil
      load_voices
      raise VoiceNotFound, "Voice '#{@config[:voice]}' isn't a valid voice" unless valid_voice? @config[:voice]
    end

    def self.say(string, voice = :alex)
      mac = self.new(voice: voice.downcase.to_sym)
      mac.say(string: string)
    end

    def say(string: nil, file: nil, voice: nil)
      if voice
        raise VoiceNotFound, "Voice '#{voice}' isn't a valid voice" unless valid_voice?(voice)
        @config[:voice] = voice
      end

      if file
        raise FileNotFound, "File '#{file}' wasn't found or it's not readable by the current user" unless valid_file_path?(file)
        @config[:file] = file
      end

      execute_command(string)
    end

    def self.voice(feature, name)
      mac = self.new
      mac.voice(feature, name)
    end

    def voice(feature, value)
      raise UnknownVoiceFeature, "Voice has no '#{feature}' feature" unless [:name, :language, :country].include?(feature)

      return @voices.find_all {|v| v[feature] == value} if feature == :name
      found_voices = @voices.find_all {|v| v[:iso_code][feature] == value}
      found_voices.count == 1 ? found_voices.first : found_voices
    end

    def self.voices
      mac = self.new
      mac.voices
    end

    alias_method :read, :say

    private

    def execute_command(string = nil)
      say = IO.popen(generate_command, 'w+')
      say.write(string) if string
      say.close
      $CHILD_STATUS.exitstatus
    end

    def generate_command
      raise CommandNotFound, "Command `say` couldn't be found by '#{@config[:say_path]}' path" unless valid_command_path? @config[:say_path]

      if @config[:file] && !valid_file_path?(@config[:file])
        raise FileNotFound, "File '#{@config[:file]}' wasn't found or it's not readable by the current user"
      end

      file = @config[:file] ? " -f #{@config[:file]}" : ''
      "#{@config[:say_path]}#{file} -v '#{@config[:voice]}' -r #{@config[:rate].to_i}"
    end

    def load_voices
      return if @voices
      raise CommandNotFound, "Command `say` couldn't be found by '#{@config[:say_path]}' path" unless valid_command_path? @config[:say_path]

      output = `#{@config[:say_path]} -v '?'`

      @voices = output.scan VOICES_PATTERN
      @voices.map! do |voice|
        lang = voice[1].split(/[_-]/)

        {
          name: voice[0].downcase.to_sym,
          iso_code: {language: lang[0].downcase.to_sym, country: lang[1].downcase.to_sym},
          sample: voice[2]
        }
      end
    end

    def valid_voice?(name)
      v = voice(:name, name)
      v && !v.empty?
    end

    def valid_command_path?(path)
      File.exist?(path) && File.executable?(path)
    end

    def valid_file_path?(path)
      path && File.exists?(path) && File.readable?(path)
    end
  end
end
