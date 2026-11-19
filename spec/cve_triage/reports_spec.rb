# frozen_string_literal: true

RSpec.describe "CveTriage::Reports" do
  let(:fixtures) { Pathname.new(File.expand_path("../fixtures", __dir__)) }

  describe CveTriage::Reports::Vulnerabilities do
    subject(:report) { described_class.new(fixtures.join("vuln-fs.json")) }

    it "counts findings by severity" do
      expect(report.counts).to eq(
        "CRITICAL" => 1, "HIGH" => 1, "MEDIUM" => 1, "LOW" => 0, "UNKNOWN" => 0
      )
      expect(report.total).to eq(3)
    end

    it "returns only CRITICAL/HIGH findings with escaped titles" do
      rows = report.top

      expect(rows.length).to eq(2)
      expect(rows.first).to include(
        severity: "CRITICAL",
        id: "CVE-2025-0001",
        package: "rails",
        installed: "7.0.1",
        fixed: "7.0.8",
        title: "Rails issue \\| with pipe"
      )
    end

    it "respects the limit" do
      expect(report.top(limit: 1).length).to eq(1)
    end
  end

  describe CveTriage::Reports::Sbom do
    it "counts CycloneDX components" do
      expect(described_class.new(fixtures.join("sbom-fs.cdx.json")).component_count).to eq(3)
    end
  end

  describe CveTriage::Reports::Misconfigurations do
    it "sums findings across results" do
      expect(described_class.new(fixtures.join("misconfig-fs.json")).count).to eq(3)
    end
  end
end
