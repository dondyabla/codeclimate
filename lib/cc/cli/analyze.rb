require "securerandom"

module CC
  module CLI
    class Analyze < Command
      include CC::Analyzer

      def initialize(args = [])
        super

        process_args
      end

      def run
        require_codeclimate_yml

        formatter.started

        engines.each do |engine|
          formatter.engine_running(engine) do
            engine.run(formatter)
          end
        end

        formatter.finished
      end

      private

      def process_args
        case @args.first
        when '-f'
          @args.shift # throw out the -f
          @formatter = Formatters.resolve(@args.shift)
        end
      rescue Formatters::Formatter::InvalidFormatterError => e
        $stderr.puts e.message
        exit 1
      end

      def config
        @config ||= if filesystem.exist?(CODECLIMATE_YAML)
          config_body = filesystem.read_path(CODECLIMATE_YAML)
          config = Config.new(config_body)
        else
          config = NullConfig.new
        end
      end

      def engine_registry
        @engine_registry ||= EngineRegistry.new
      end

      def engine_config(engine_name)
        config.engine_config(engine_name).
          merge!(exclude_paths: exclude_paths).to_json
      end

      # Make a file in the code directory to mount into the
      # engine container
      def engine_config_file(engine_name)
        filename = "config-#{SecureRandom.uuid}.json"
        tmp_path = File.join("/tmp/cc-config", filename)

        File.write(tmp_path, engine_config(engine_name))

        tmp_path
      end

      def exclude_paths
        if config.exclude_paths
          filesystem.files_matching(config.exclude_paths)
        else
          []
        end
      end

      def engines
        @engines ||= config.engine_names.map do |engine_name|
          Engine.new(
            engine_name,
            engine_registry[engine_name],
            path,
            engine_config_file(engine_name),
            SecureRandom.uuid
          )
        end
      end

      def formatter
        @formatter ||= Formatters::PlainTextFormatter.new
      end

      def path
        ENV['CODE_PATH']
      end

    end
  end
end
