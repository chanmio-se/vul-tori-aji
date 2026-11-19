# frozen_string_literal: true

RSpec.describe CveTriage::Config do
  describe ".from_env" do
    let(:base_env) do
      {
        "TARGET_NAME" => "rails-app",
        "OUT_DIR" => "/tmp/scan",
        "TARGET_DIR" => "/tmp/target"
      }
    end

    it "defaults to a filesystem scan" do
      config = described_class.from_env(base_env)

      expect(config.scan_type).to eq("fs")
      expect(config.fs_scan?).to be(true)
      expect(config.image_scan?).to be(false)
      expect(config.enable_misconfig?).to be(true)
      expect(config.ignore_unfixed?).to be(false)
      expect(config.severity).to eq("CRITICAL,HIGH,MEDIUM,LOW,UNKNOWN")
    end

    it "parses boolean inputs" do
      config = described_class.from_env(
        base_env.merge("ENABLE_MISCONFIG" => "false", "IGNORE_UNFIXED" => "true")
      )

      expect(config.enable_misconfig?).to be(false)
      expect(config.ignore_unfixed?).to be(true)
    end

    it "splits image refs into lines" do
      config = described_class.from_env(
        base_env.merge("SCAN_TYPE" => "both", "IMAGE_REFS" => " ubuntu:24.04 \n\nghcr.io/x/y:1\n")
      )

      expect(config.images).to eq(["ubuntu:24.04", "ghcr.io/x/y:1"])
      expect(config.fs_scan?).to be(true)
      expect(config.image_scan?).to be(true)
    end

    it "requires IMAGE_REFS for image scans" do
      expect { described_class.from_env(base_env.merge("SCAN_TYPE" => "image")) }
        .to raise_error(CveTriage::Config::ValidationError, /IMAGE_REFS/)
    end

    it "rejects unknown scan types" do
      expect { described_class.from_env(base_env.merge("SCAN_TYPE" => "rootfs")) }
        .to raise_error(CveTriage::Config::ValidationError, /SCAN_TYPE/)
    end

    it "rejects unsafe target names" do
      expect { described_class.from_env(base_env.merge("TARGET_NAME" => "../etc")) }
        .to raise_error(CveTriage::Config::ValidationError, /TARGET_NAME/)
    end

    it "rejects unknown severities" do
      expect { described_class.from_env(base_env.merge("SEVERITY" => "CRITICAL,BOGUS")) }
        .to raise_error(CveTriage::Config::ValidationError, /BOGUS/)
    end
  end
end
