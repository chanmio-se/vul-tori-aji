# frozen_string_literal: true

RSpec.describe CveTriage::Trivy do
  let(:runner) { CveTriage::FakeRunner.new }
  let(:trivy) { described_class.new(runner: runner) }

  it "builds the filesystem vulnerability command" do
    trivy.fs_vulnerabilities(path: "/src", output: "/out/vuln-fs.json",
                             severity: "CRITICAL,HIGH", ignore_unfixed: true)

    expect(runner.calls.last).to eq(
      ["trivy", "fs", "--scanners", "vuln", "--format", "json",
       "--output", "/out/vuln-fs.json", "--severity", "CRITICAL,HIGH",
       "--exit-code", "0", "--ignore-unfixed", "/src"]
    )
  end

  it "builds the CycloneDX SBOM command" do
    trivy.fs_sbom(path: "/src", output: "/out/sbom-fs.cdx.json")

    expect(runner.calls.last).to eq(
      ["trivy", "fs", "--format", "cyclonedx", "--output", "/out/sbom-fs.cdx.json", "/src"]
    )
  end

  it "builds config and image commands" do
    trivy.config(path: "/src", output: "/out/misconfig-fs.json", severity: "HIGH")
    trivy.image_vulnerabilities(image: "ubuntu:24.04", output: "/out/v.json", severity: "HIGH")
    trivy.image_sbom(image: "ubuntu:24.04", output: "/out/s.cdx.json")

    expect(runner.calls[0]).to eq(
      ["trivy", "config", "--format", "json", "--output", "/out/misconfig-fs.json",
       "--severity", "HIGH", "--exit-code", "0", "/src"]
    )
    expect(runner.calls[1]).to eq(
      ["trivy", "image", "--scanners", "vuln", "--format", "json", "--output", "/out/v.json",
       "--severity", "HIGH", "--exit-code", "0", "ubuntu:24.04"]
    )
    expect(runner.calls[2]).to eq(
      ["trivy", "image", "--format", "cyclonedx", "--output", "/out/s.cdx.json", "ubuntu:24.04"]
    )
  end
end
