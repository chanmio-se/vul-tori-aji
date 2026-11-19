# frozen_string_literal: true

RSpec.describe CveTriage::Slugger do
  it "turns image refs into filename-safe slugs" do
    expect(described_class.call("ubuntu:24.04")).to eq("ubuntu_24.04")
  end

  it "handles registries, tags and digests" do
    expect(described_class.call("ghcr.io/mioarai/base-ubuntu:22.04@sha256:abc"))
      .to eq("ghcr.io_mioarai_base-ubuntu_22.04_sha256_abc")
  end
end
