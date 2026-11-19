# frozen_string_literal: true

module CveTriage
  module Reports
    # Trivy の脆弱性 JSON を読み取り、件数と上位 CVE を提供する。
    class Vulnerabilities
      SEVERITIES = Config::SEVERITIES
      HIGH_SEVERITIES = %w[CRITICAL HIGH].freeze

      def initialize(path)
        @path = Pathname.new(path)
        @data = JSON.parse(@path.read)
      end

      def counts
        @counts ||= SEVERITIES.to_h do |severity|
          [severity, entries.count { |entry| entry["Severity"] == severity }]
        end
      end

      def total
        entries.length
      end

      def top(limit: 20)
        entries
          .select { |entry| HIGH_SEVERITIES.include?(entry["Severity"]) }
          .uniq { |entry| entry["VulnerabilityID"] }
          .sort_by { |entry| [SEVERITIES.index(entry["Severity"]) || 99, entry["VulnerabilityID"].to_s] }
          .first(limit)
          .map { |entry| row(entry) }
      end

      private

      attr_reader :path, :data

      def entries
        @entries ||= Array(data["Results"]).flat_map { |result| Array(result["Vulnerabilities"]) }
      end

      def row(entry)
        {
          severity: entry["Severity"],
          id: entry["VulnerabilityID"],
          package: entry["PkgName"],
          installed: entry["InstalledVersion"],
          fixed: entry["FixedVersion"],
          title: escape_pipe(entry["Title"].to_s)
        }
      end

      def escape_pipe(value)
        value.gsub("|", "\\|")
      end
    end
  end
end
