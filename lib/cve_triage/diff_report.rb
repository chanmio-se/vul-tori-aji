# frozen_string_literal: true

module CveTriage
  # 差分結果を人間向け Markdown に変換する。
  class DiffReport
    SECTIONS = [
      [:added, "新規 CVE"],
      [:updated, "更新 CVE"],
      [:removed, "解消 CVE"]
    ].freeze

    def initialize(result)
      @result = result
    end

    def render
      lines = []
      lines << "# CVE diff: #{result.snapshot || '-'}"
      lines << ""
      lines << "- Previous snapshot: `#{result.previous_snapshot || '(none)'}`"
      lines << "- Added: **#{result.added.length}** / Updated: **#{result.updated.length}** / Removed: **#{result.removed.length}**"
      lines << ""
      lines << "> 初回スナップショットのため、全件が新規として扱われています。" if result.first_run
      lines << "" if result.first_run

      if result.changes.empty?
        lines << "前回から変化はありません。"
        lines << ""
        return lines.join("\n")
      end

      SECTIONS.each do |status, title|
        changes = result.public_send(status)
        lines << "## #{title} (#{changes.length})"
        lines << ""
        if changes.empty?
          lines << "(none)"
          lines << ""
          next
        end
        lines << "| Status | Severity | CVE | Package | Installed | Fixed | Source |"
        lines << "|---|---|---|---|---|---|---|"
        changes.each do |change|
          finding = change.current || change.previous
          fixed = change.status == :removed ? "-" : (finding.fixed_version || "-")
          lines << "| #{status} | #{finding.severity} | #{finding.id} | #{finding.package} | " \
                   "#{finding.installed_version} | #{fixed} | #{finding.source} |"
        end
        lines << ""
      end

      lines.join("\n")
    end

    private

    attr_reader :result
  end
end
