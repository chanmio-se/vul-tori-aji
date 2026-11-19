# frozen_string_literal: true

RSpec.describe CveTriage::Differ do
  let(:fixtures) { Pathname.new(File.expand_path("../fixtures", __dir__)) }
  let(:previous) { CveTriage::Reports::Findings.new([fixtures.join("previous/vuln-fs.json")]).all }
  let(:current) { CveTriage::Reports::Findings.new([fixtures.join("current/vuln-fs.json")]).all }

  def diff(previous_findings: previous, previous_snapshot: "20261119T180000Z-1")
    described_class.new(
      previous: previous_findings,
      current: current,
      snapshot: "20261120T180000Z-2",
      previous_snapshot: previous_snapshot
    ).call
  end

  it "detects added, updated and removed findings" do
    result = diff

    expect(result.counts).to eq(added: 1, updated: 1, removed: 1)
    expect(result.added.first.current.id).to eq("CVE-2025-0004")
    expect(result.updated.first.previous.fixed_version).to eq("2.2.1")
    expect(result.updated.first.current.fixed_version).to eq("2.2.2")
    expect(result.removed.first.previous.id).to eq("CVE-2025-0003")
    expect(result.first_run).to be(false)
  end

  it "treats every finding as added on the first run" do
    result = diff(previous_findings: [], previous_snapshot: nil)

    expect(result.first_run).to be(true)
    expect(result.added.length).to eq(3)
    expect(result.updated).to be_empty
    expect(result.removed).to be_empty
  end

  it "serializes and restores the result for bin/triage" do
    restored = CveTriage::Differ::Result.from_h(JSON.parse(JSON.generate(diff.to_h)))

    expect(restored.counts).to eq(added: 1, updated: 1, removed: 1)
    expect(restored.triage_targets.map(&:id)).to contain_exactly("CVE-2025-0002", "CVE-2025-0004")
  end

  it "renders a markdown report" do
    markdown = CveTriage::DiffReport.new(diff).render

    expect(markdown).to include("# CVE diff: 20261120T180000Z-2")
    expect(markdown).to include("| added | HIGH | CVE-2025-0004 |")
    expect(markdown).to include("| removed | MEDIUM | CVE-2025-0003 |")
  end
end
