# frozen_string_literal: true

module CveTriage
  # 集約リポジトリにコミット済みのスナップショットを参照する。
  class History
    def initialize(central_dir:, target:)
      @root = Pathname.new(central_dir).join("results", target, "history")
      unless Config::SAFE_NAME.match?(target.to_s)
        raise ArgumentError, "invalid target: #{target.inspect}"
      end
    end

    def dirs
      return [] unless root.directory?

      root.children.select(&:directory?).sort_by(&:basename)
    end

    # 今回のスナップショットを除外して、直前のものを返す。
    def latest(exclude: nil)
      dirs.reject { |dir| dir.basename.to_s == exclude.to_s }.last
    end

    def vulnerability_paths(dir)
      return [] unless dir

      Pathname.new(dir).glob("vuln-*.json").sort
    end

    private

    attr_reader :root
  end
end
