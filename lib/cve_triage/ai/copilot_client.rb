# frozen_string_literal: true

module CveTriage
  module Ai
    # GitHub Copilot CLI をプログラムモード（-p）で呼び出す薄いラッパー。
    # Copilot の利用枠は GITHUB_TOKEN で消費される（Actions では copilot-requests: write が必要）。
    # このタスクではファイル読み書きもコマンド実行も不要なので、tool 権限は一切与えない。
    class CopilotClient
      class Error < CveTriage::Error; end

      def initialize(runner: CommandRunner.new, model: nil, chdir: nil, logger: nil, bin: "copilot")
        @runner = runner
        @model = model
        @chdir = chdir
        @logger = logger || ->(message) { $stderr.puts(message) }
        @bin = bin
      end

      def call(prompt)
        raise Error, "prompt is empty" if prompt.to_s.strip.empty?

        logger.call("==> Copilot triage (model: #{model.to_s.empty? ? 'default' : model})")
        runner.run(*arguments(prompt), chdir: chdir, log_command: log_command(prompt))
      rescue CommandRunner::Error => e
        raise Error, "Copilot CLI failed: #{e.message.lines.first&.chomp}"
      end

      def command_for(prompt)
        [bin, "-p", prompt, "-s", "--no-ask-user", *model_arguments]
      end

      private

      attr_reader :runner, :model, :chdir, :logger, :bin

      def arguments(prompt)
        command_for(prompt)
      end

      # プロンプト全文はログに出さない（長い上に CVE の説明が含まれるため）。
      def log_command(prompt)
        ([bin, "-p", "<#{prompt.to_s.length} chars>", "-s", "--no-ask-user"] + model_arguments).join(" ")
      end

      def model_arguments
        return [] if model.nil? || model.to_s.strip.empty?

        ["--model", model.to_s.strip]
      end
    end
  end
end
