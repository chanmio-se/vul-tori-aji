# frozen_string_literal: true

module CveTriage
  # 集約リポジトリ内の results/<target>/ に成果物を配置し、古い快照を整理する。
  class SnapshotStore
    class ValidationError < Error; end

    SAFE_NAME = Config::SAFE_NAME
    SAFE_SNAPSHOT = /\A\d{8}T\d{6}Z-[\w-]+\z/.freeze

    def initialize(central_dir:, out_dir:, target:, snapshot:, keep: 30)
      @central_dir = Pathname.new(central_dir)
      @out_dir = Pathname.new(out_dir)
      @target = target
      @snapshot = snapshot
      @keep = keep.to_i
      validate!
    end

    def relative_path
      "results/#{target}"
    end

    def stage
      FileUtils.rm_rf(snapshot_dir)
      FileUtils.mkdir_p(snapshot_dir)

      out_dir.children.each { |child| FileUtils.cp_r(child, snapshot_dir) }
      FileUtils.cp(out_dir.join("summary.md"), target_dir.join("latest.md"))
      FileUtils.cp(out_dir.join("meta.json"), target_dir.join("latest.json"))

      prune
      self
    end

    def history_dirs
      return [] unless history_dir.exist?

      history_dir.children.select(&:directory?).sort_by(&:basename)
    end

    def prune
      return if keep <= 0

      dirs = history_dirs
      removable = dirs.first([dirs.length - keep, 0].max)
      removable.each { |dir| FileUtils.rm_rf(dir) }
      removable
    end

    private

    attr_reader :central_dir, :out_dir, :target, :snapshot, :keep

    def target_dir
      central_dir.join("results", target)
    end

    def history_dir
      target_dir.join("history")
    end

    def snapshot_dir
      history_dir.join(snapshot)
    end

    def validate!
      raise ValidationError, "invalid target: #{target.inspect}" unless SAFE_NAME.match?(target)
      unless SAFE_SNAPSHOT.match?(snapshot)
        raise ValidationError, "invalid snapshot: #{snapshot.inspect}"
      end
      raise ValidationError, "OUT_DIR not found: #{out_dir}" unless out_dir.directory?
      %w[summary.md meta.json].each do |name|
        raise ValidationError, "missing #{name} in OUT_DIR" unless out_dir.join(name).file?
      end
    end
  end
end
