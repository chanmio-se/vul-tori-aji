# frozen_string_literal: true

RSpec.describe CveTriage::History do
  around do |example|
    Dir.mktmpdir do |dir|
      @root = Pathname.new(dir)
      @history = @root.join("results/rails-app/history")
      %w[20261118T180000Z-1 20261119T180000Z-2 20261120T180000Z-3].each do |name|
        @history.join(name).mkpath
      end
      example.run
    end
  end

  let(:history) { described_class.new(central_dir: @root, target: "rails-app") }

  it "returns the latest snapshot excluding the current one" do
    expect(history.latest(exclude: "20261120T180000Z-3").basename.to_s).to eq("20261119T180000Z-2")
    expect(history.latest(exclude: "20261121T180000Z-4").basename.to_s).to eq("20261120T180000Z-3")
  end

  it "returns no previous snapshot when only the current one exists" do
    Dir.mktmpdir do |dir|
      Pathname.new(dir).join("results/rails-app/history/20261121T180000Z-4").mkpath

      single = described_class.new(central_dir: dir, target: "rails-app")
      expect(single.latest(exclude: "20261121T180000Z-4")).to be_nil
    end
  end

  it "lists only vulnerability reports in a snapshot" do
    dir = @history.join("20261119T180000Z-2")
    dir.join("vuln-fs.json").write("{}")
    dir.join("vuln-image-ubuntu_24.04.json").write("{}")
    dir.join("summary.md").write("# summary")

    expect(history.vulnerability_paths(dir).map(&:basename).map(&:to_s)).to eq(
      %w[vuln-fs.json vuln-image-ubuntu_24.04.json]
    )
  end

  it "rejects unsafe target names" do
    expect { described_class.new(central_dir: @root, target: "../evil") }
      .to raise_error(ArgumentError, /invalid target/)
  end
end
