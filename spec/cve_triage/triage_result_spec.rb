# frozen_string_literal: true

RSpec.describe CveTriage::TriageResult do
  let(:fixtures) { Pathname.new(File.expand_path("../fixtures", __dir__)) }
  let(:diff) do
    previous = CveTriage::Reports::Findings.new([fixtures.join("previous/vuln-fs.json")]).all
    current = CveTriage::Reports::Findings.new([fixtures.join("current/vuln-fs.json")]).all
    CveTriage::Differ.new(previous: previous, current: current,
                          snapshot: "20261120T180000Z-2", previous_snapshot: "20261119T180000Z-1").call
  end
  let(:assessment) do
    CveTriage::Ai::ResponseParser::Assessment.new(
      key: diff.added.first.current.key, priority: "P1", rationale: "internet | facing",
      recommended_action: "Upgrade puma", confidence: "high"
    )
  end

  def result(status: "ok", assessments: [assessment], error: nil)
    described_class.new(diff: diff, assessments: assessments, model: "claude-haiku-4.5",
                        generated_at: "2026-11-20T18:05:00Z", status: status, error: error)
  end

  it "serializes assessments with CVE context" do
    data = result.to_h

    expect(data[:status]).to eq("ok")
    expect(data[:counts]).to eq(added: 1, updated: 1, removed: 1, triaged: 1)
    expect(data[:findings].first).to include(cve: "CVE-2025-0004", package: "puma", priority: "P1")
  end

  it "renders a markdown table with escaped pipes" do
    markdown = result.render

    expect(markdown).to include("| P1 | CVE-2025-0004 | puma | HIGH | internet \\| facing |")
  end

  it "renders an error status without a table" do
    markdown = result(status: "error", assessments: [], error: "Copilot CLI failed").render

    expect(markdown).to include("Status: **error**")
    expect(markdown).to include("AI triage failed: Copilot CLI failed")
    expect(markdown).not_to include("| Priority |")
  end

  it "renders a skipped status when there are no changes" do
    markdown = result(status: "skipped", assessments: []).render

    expect(markdown).to include("スキップしました")
  end
end
