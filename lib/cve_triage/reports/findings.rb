# frozen_string_literal: true

module CveTriage
  module Reports
    # 複数の Trivy 脆弱性 JSON を読み込み、Finding の配列に変換する。
    class Findings
      PROMPT_EXTRA_KEYS = %w[PrimaryURL PublishedDate LastModifiedDate].freeze

      def initialize(paths)
        @paths = Array(paths).map { |path| Pathname.new(path) }
      end

      def all
        paths.flat_map { |path| from_file(path) }
      end

      def by_key
        all.to_h { |finding| [finding.key, finding] }
      end

      private

      attr_reader :paths

      def from_file(path)
        return [] unless path.file?

        data = JSON.parse(path.read)
        source = path.basename.to_s
        Array(data["Results"]).flat_map do |result|
          target = result["Target"].to_s
          Array(result["Vulnerabilities"]).filter_map do |entry|
            finding_from(entry, source, target)
          end
        end
      rescue JSON::ParserError => e
        warn "warning: skipping unreadable vulnerability report #{path} (#{e.message.lines.first&.chomp})"
        []
      end

      def finding_from(entry, source, target)
        id = entry["VulnerabilityID"].to_s
        return nil if id.empty?

        Finding.new(
          source: source,
          target: target,
          id: id,
          package: entry["PkgName"].to_s,
          installed_version: entry["InstalledVersion"].to_s,
          fixed_version: entry["FixedVersion"],
          severity: entry["Severity"].to_s,
          title: entry["Title"].to_s,
          extra: entry.slice(*PROMPT_EXTRA_KEYS)
        )
      end
    end
  end
end
