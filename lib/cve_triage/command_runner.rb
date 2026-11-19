# frozen_string_literal: true

module CveTriage
  # 外部コマンドを実行する薄いラッパー。テストでは FakeRunner に差し替える。
  class CommandRunner
    class Error < CveTriage::Error; end

    def initialize(logger: nil)
      @logger = logger || ->(message) { $stderr.puts(message) }
    end

    def run(*args, chdir: nil, env: {}, log_command: nil)
      @logger.call("+ #{log_command || args.join(' ')}")
      stdout, stderr, status = Open3.capture3(env, *args, **options(chdir))
      return stdout if status.success?

      raise Error, "command failed (exit #{status.exitstatus}): #{args.join(' ')}\n#{stderr}"
    rescue Errno::ENOENT => e
      raise Error, "command not found: #{args.first} (#{e.message})"
    end

    # 終了コードだけが知りたい場合（git diff --quiet など）に使う。
    def success?(*args, chdir: nil, env: {})
      _stdout, _stderr, status = Open3.capture3(env, *args, **options(chdir))
      status.success?
    rescue Errno::ENOENT
      false
    end

    # Ruby 4 では chdir: nil を渡すと TypeError になるため、指定時だけ渡す。
    def options(chdir)
      chdir ? { chdir: chdir } : {}
    end
    private :options
  end
end
