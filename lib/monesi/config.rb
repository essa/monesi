
module Monesi
  class Config
    CONFIG_PATH='config.yaml'
    def self.setup
      unless File::exists?(CONFIG_PATH)
        puts "creating default config..."
        File::open(CONFIG_PATH, "w") do |f| 
          f.puts <<~EOC
          visibility: unlisted # visibility of toots, one of public, unlisted, private, direct
          interval: 120 # interval between toots
          EOC
        end
        puts "created #{CONFIG_PATH}, check and edit it before starting bot."
      end
      load
    end

    def self.load
      @@instance = new
      @@instance.load
    end

    def self.[](key)
      @@instance[key]
    end

    def initialize
    end

    def load
      @config = YAML::load(File::open(CONFIG_PATH))
    end

    def [](key)
      p @config, key.to_s
      @config[key.to_s]
    end
  end
end
