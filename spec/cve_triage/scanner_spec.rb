# frozen_string_literal: true

RSpec.describe CveTriage::Scanner do
  around do |example|
    Dir.mktmpdir("cve-triage-scanner") do |dir|
      @root = Pathname.new(dir)
      @target_dir = @root.join("target")
      @out_dir = @root.join("scan")
      @target_dir.mkpath
      @target_dir.join("Gemfile.lock").write("gem 'rails'")
      example.run
    end
  end

  let(:runner) do
    CveTriage::FakeRunner.new do |args|
      index = args.index("--output")
      File.write(args[index + 1], "{}") if index
    end
  end
  let(:trivy) { CveTriage::Trivy.new(runner: runner) }
  let(:messages) { [] }
  let(:logger) { ->(message) { messages << message } }

  def config_for(**overrides)
    CveTriage::Config.new(
      **{
        target_name: "rails-app",
        out_dir: @out_dir.to_s,
        target_dir: @target_dir.to_s,
        scan_type: "fs"
      }.merge(overrides)
    )
  end

  def scanner_for(config)
    described_class.new(config: config, paths: CveTriage::Paths.new(@out_dir),
                        trivy: trivy, logger: logger)
  end

  it "scans the filesystem and returns all artifacts" do
    artifacts = scanner_for(config_for).run

    expect(artifacts.vulnerabilities.map(&:basename).map(&:to_s)).to eq(["vuln-fs.json"])
    expect(artifacts.sboms.map(&:basename).map(&:to_s)).to eq(["sbom-fs.cdx.json"])
    expect(artifacts.misconfigurations.map(&:basename).map(&:to_s)).to eq(["misconfig-fs.json"])
    expect(runner.calls.length).to eq(3)
  end

  it "scans each image in both vulnerability and SBOM modes" do
    config = config_for(scan_type: "both", image_refs: "ubuntu:24.04\nghcr.io/x/y:1.0\n")
    artifacts = scanner_for(config).run

    expect(artifacts.vulnerabilities.map(&:basename).map(&:to_s)).to eq(
      ["vuln-fs.json", "vuln-image-ubuntu_24.04.json", "vuln-image-ghcr.io_x_y_1.0.json"]
    )
    expect(artifacts.sboms.length).to eq(3)
    expect(runner.calls.length).to eq(7)
  end

  it "continues when the config scan fails" do
    failing_runner = CveTriage::FakeRunner.new do |args|
      raise CveTriage::CommandRunner::Error, "failed" if args.include?("config")

      index = args.index("--output")
      File.write(args[index + 1], "{}") if index
    end
    scanner = described_class.new(
      config: config_for,
      paths: CveTriage::Paths.new(@out_dir),
      trivy: CveTriage::Trivy.new(runner: failing_runner),
      logger: logger
    )

    artifacts = scanner.run

    expect(artifacts.misconfigurations).to be_empty
    expect(messages.join("\n")).to include("warning: config scan")
  end

  it "raises when the scan target is missing" do
    config = config_for(target_dir: @root.join("missing").to_s)

    expect { scanner_for(config).run }.to raise_error(CveTriage::Scanner::Error, /not found/)
  end
end
