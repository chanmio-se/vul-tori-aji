# frozen_string_literal: true

module CveTriage
  # スキャン成果物から人間向けの summary.md と機械向けの meta.json を生成する。
  class Summarizer
    Metadata = Struct.new(:target, :scanned_at, :snapshot, :run_id, :repository, keyword_init: true)

    def initialize(artifacts:, metadata:, paths:)
      @artifacts = artifacts
      @metadata = metadata
      @paths = paths
    end

    def call
      paths.prepare!
      paths.summary.write(render_markdown)
      paths.meta.write("#{JSON.pretty_generate(meta_hash)}\n")
      self
    end

    private

    attr_reader :artifacts, :metadata, :paths

    def vulnerability_reports
      @vulnerability_reports ||= artifacts.vulnerabilities.map do |path|
        [path, Reports::Vulnerabilities.new(path)]
      end
    end

    def sbom_reports
      @sbom_reports ||= artifacts.sboms.map do |path|
        [path, Reports::Sbom.new(path)]
      end
    end

    def aggregated_counts
      vulnerability_reports.each_with_object(Hash.new(0)) do |(_path, report), totals|
        report.counts.each { |severity, count| totals[severity] += count }
      end
    end

    def misconfiguration_count
      artifacts.misconfigurations.sum { |path| Reports::Misconfigurations.new(path).count }
    end

    def meta_hash
      {
        target: metadata.target,
        scanned_at: metadata.scanned_at,
        snapshot: metadata.snapshot,
        run_id: metadata.run_id,
        repository: metadata.repository,
        vulnerability_counts: aggregated_counts.reject { |_severity, count| count.zero? },
        misconfiguration_count: misconfiguration_count
      }
    end

    def render_markdown
      lines = []
      lines << "# Trivy scan: #{metadata.target}"
      lines << ""
      lines << "- Scanned at: **#{metadata.scanned_at}**"
      lines << "- Snapshot: `#{metadata.snapshot}`"
      lines << "- Source repository: `#{metadata.repository}`"
      lines << "- GitHub run ID: `#{metadata.run_id}`"
      lines << ""
      lines.concat(render_sboms)
      lines.concat(render_vulnerabilities)
      lines.concat(render_misconfigurations)
      lines << "---"
      lines << ""
      lines << "Phase 1 は可視化のみです。CVE の調査・優先度付けは Phase 2 以降で実装します。"
      lines << ""
      lines.join("\n")
    end

    def render_sboms
      lines = ["## SBOM (CycloneDX)", "", "| File | Components |", "|---|---:|"]
      if sbom_reports.empty?
        lines << "| (none) | 0 |"
      else
        sbom_reports.each do |path, report|
          lines << "| #{path.basename} | #{report.component_count} |"
        end
      end
      lines << ""
      lines
    end

    def render_vulnerabilities
      lines = ["## Vulnerabilities", ""]
      if vulnerability_reports.empty?
        lines << "No vulnerability scan results."
        lines << ""
        return lines
      end

      vulnerability_reports.each do |path, report|
        lines << "#### #{path.basename}"
        lines << ""
        lines << "| Severity | Count |"
        lines << "|---|---:|"
        Reports::Vulnerabilities::SEVERITIES.each do |severity|
          lines << "| #{severity} | #{report.counts.fetch(severity, 0)} |"
        end
        lines << ""
        lines << "<details><summary>CRITICAL / HIGH の CVE（最大 20 件）</summary>"
        lines << ""
        lines << "| Severity | CVE | Package | Installed | Fixed | Title |"
        lines << "|---|---|---|---|---|---|"
        rows = report.top
        if rows.empty?
          lines << "| - | - | - | - | - | (none) |"
        else
          rows.each do |row|
            lines << "| #{row[:severity]} | #{row[:id]} | #{row[:package]} | " \
                     "#{row[:installed]} | #{row[:fixed] || '-'} | #{row[:title]} |"
          end
        end
        lines << ""
        lines << "</details>"
        lines << ""
      end
      lines
    end

    def render_misconfigurations
      lines = ["## Misconfigurations", ""]
      if artifacts.misconfigurations.empty?
        lines << "Misconfig scan was not run (or produced no file)."
      else
        lines << "| File | Count |"
        lines << "|---|---:|"
        artifacts.misconfigurations.each do |path|
          lines << "| #{path.basename} | #{Reports::Misconfigurations.new(path).count} |"
        end
      end
      lines << ""
      lines
    end
  end
end
