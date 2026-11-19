# frozen_string_literal: true

RSpec.describe CveTriage::Reports::Findings do
  let(:fixtures) { Pathname.new(File.expand_path("../../fixtures", __dir__)) }

  it "normalizes Trivy entries into stable findings" do
    finding = described_class.new([fixtures.join("current/vuln-fs.json")]).all
                             .find { |item| item.id == "CVE-2025-0002" }

    expect(finding.source).to eq("vuln-fs.json")
    expect(finding.target).to eq("Gemfile.lock")
    expect(finding.key).to include("CVE-2025-0002", "rack", "2.2.0")
    expect(finding.fixed_version).to eq("2.2.2")
    expect(finding.extra["PrimaryURL"]).to eq("https://example.test/CVE-2025-0002")
  end

  it "ignores missing files and entries without an id" do
    Dir.mktmpdir do |dir|
      broken = Pathname.new(dir).join("vuln-broken.json")
      broken.write(JSON.generate(Results: [{ Target: "x", Vulnerabilities: [{ PkgName: "rack" }] }]))

      findings = described_class.new([broken, Pathname.new(dir).join("missing.json")]).all

      expect(findings).to be_empty
    end
  end
end
