# frozen_string_literal: true

RSpec.describe CveTriage::Ai::ResponseParser do
  let(:keys) { ["vuln-fs.json|Gemfile.lock|CVE-2025-0004|puma|6.0.0"] }

  it "parses a plain JSON object" do
    text = JSON.generate(findings: [{
      key: keys.first, priority: "P1", rationale: "internet facing",
      recommended_action: "Upgrade puma", confidence: "High"
    }])

    assessment = described_class.call(text, keys: keys).first

    expect(assessment.priority).to eq("P1")
    expect(assessment.confidence).to eq("high")
    expect(assessment.recommended_action).to eq("Upgrade puma")
  end

  it "strips markdown fences and ignores unknown keys" do
    text = <<~TEXT
      Here is the result:
      ```json
      {"findings":[
        {"key":"#{keys.first}","priority":"P0","rationale":"critical","recommended_action":"patch","confidence":"high"},
        {"key":"unknown","priority":"P3","rationale":"noise"}
      ]}
      ```
    TEXT

    assessments = described_class.call(text, keys: keys)

    expect(assessments.map(&:key)).to eq(keys)
  end

  it "accepts a bare array and supplies defaults" do
    text = JSON.generate([{ key: keys.first }])

    assessment = described_class.call(text, keys: keys).first

    expect(assessment.priority).to eq("P3")
    expect(assessment.confidence).to eq("low")
  end

  it "raises when no JSON is present" do
    expect { described_class.call("I cannot help with that.", keys: keys) }
      .to raise_error(CveTriage::Ai::ResponseParser::ResponseError, /no JSON/)
  end
end
