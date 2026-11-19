# frozen_string_literal: true

RSpec.describe CveTriage::Summarizer do
  around do |example|
    Dir.mktmpdir("cve-triage-summarizer") do |dir|
      @out_dir = Pathname.new(dir)
      fixtures = Pathname.new(File.expand_path("../fixtures", __dir__))
      %w[vuln-fs.json sbom-fs.cdx.json misconfig-fs.json].each do |name|
        FileUtils.cp(fixtures.join(name), @out_dir.join(name))
      end
      example.run
    end
  end

  let(:metadata) do
    described_class::Metadata.new(
      target: "rails-app",
      scanned_at: "2026-11-19T18:00:00Z",
      snapshot: "20261119T180000Z-12345",
      run_id: "12345",
      repository: "example/rails-app"
    )
  end

  let(:paths) { CveTriage::Paths.new(@out_dir) }

  def summarize
    described_class.new(
      artifacts: CveTriage::Artifacts.discover(@out_dir),
      metadata: metadata,
      paths: paths
    ).call
  end

  it "writes summary.md with counts and CVE details" do
    summarize

    markdown = paths.summary.read
    expect(markdown).to include("# Trivy scan: rails-app")
    expect(markdown).to include("| sbom-fs.cdx.json | 3 |")
    expect(markdown).to include("| CRITICAL | 1 |")
    expect(markdown).to include("CVE-2025-0001")
    expect(markdown).to include("Rails issue \\| with pipe")
    expect(markdown).to include("| misconfig-fs.json | 3 |")
  end

  it "writes machine readable meta.json" do
    summarize

    meta = JSON.parse(paths.meta.read)
    expect(meta).to include(
      "target" => "rails-app",
      "snapshot" => "20261119T180000Z-12345",
      "run_id" => "12345",
      "misconfiguration_count" => 3
    )
    expect(meta["vulnerability_counts"]).to eq("CRITICAL" => 1, "HIGH" => 1, "MEDIUM" => 1)
  end

  it "handles an empty artifact set" do
    FileUtils.rm_f(Dir.glob(@out_dir.join("*")))
    summarize

    markdown = paths.summary.read
    expect(markdown).to include("No vulnerability scan results.")
    expect(markdown).to include("| (none) | 0 |")
    expect(JSON.parse(paths.meta.read)["vulnerability_counts"]).to eq({})
  end
end
