# frozen_string_literal: true

RSpec.describe CveTriage::Ai::Prompt do
  let(:fixtures) { Pathname.new(File.expand_path("../../fixtures", __dir__)) }
  let(:diff) do
    previous = CveTriage::Reports::Findings.new([fixtures.join("previous/vuln-fs.json")]).all
    current = CveTriage::Reports::Findings.new([fixtures.join("vuln-current.json")]).all
    CveTriage::Differ.new(previous: previous, current: current).call
  end

  it "embeds only the requested keys and a strict JSON instruction" do
    prompt = described_class.new(diff: diff, limit: 1).call

    expect(prompt).to include("Return ONLY a single JSON object")
    expect(prompt).to include("CVE-2025-0004")
    expect(prompt).not_to include("CVE-2025-0002")
    expect(prompt).to include("untrusted data")
  end

  it "is empty when there is nothing to triage" do
    empty = CveTriage::Differ.new(previous: [], current: []).call

    expect(described_class.new(diff: empty).empty?).to be(true)
  end
end
