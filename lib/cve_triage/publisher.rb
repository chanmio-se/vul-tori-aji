# frozen_string_literal: true

module CveTriage
  # fetch -> reset -> stage -> commit -> push を、push 衝突時に再試行する。
  class Publisher
    class Error < CveTriage::Error; end

    MAX_ATTEMPTS = 5

    def initialize(store:, git:, target:, snapshot:, branch:, attempts: MAX_ATTEMPTS, logger: nil)
      @store = store
      @git = git
      @target = target
      @snapshot = snapshot
      @branch = branch
      @attempts = attempts
      @logger = logger || ->(message) { $stderr.puts(message) }
    end

    def call
      attempts.times do |index|
        logger.call("Publish attempt #{index + 1}")
        begin
          git.fetch(branch)
          git.reset_hard("origin/#{branch}")
          store.stage
          git.add(store.relative_path)

          return :unchanged unless git.changes_staged?(store.relative_path)

          git.commit("chore(scan): update #{target} (#{snapshot})")
          git.push(branch)
          return :published
        rescue CveTriage::Error => e
          logger.call("warning: publish failed; retrying (#{e.message.lines.first&.chomp})")
        end
      end

      raise Error, "failed to publish results after #{attempts} attempts"
    end

    private

    attr_reader :store, :git, :target, :snapshot, :branch, :attempts, :logger
  end
end
