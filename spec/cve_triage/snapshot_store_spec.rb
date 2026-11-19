# frozen_string_literal: true

RSpec.describe CveTriage::SnapshotStore do
  around do |example|
    Dir.mktmpdir("cve-triage-store") do |dir|
      @root = Pathname.new(dir)
      @central = @root.join("central")
      @out = @root.join("out")
      @out.mkpath
      @out.join("summary.md").write("# summary")
      @out.join("meta.json").write("{}")
      @out.join("vuln-fs.json").write("{}")
      @central.mkpath
      example.run
    end
  end

  def store(snapshot: "20261119T180000Z-1", keep: 2)
    described_class.new(central_dir: @central, out_dir: @out, target: "rails-app",
                        snapshot: snapshot, keep: keep)
  end

  it "stages artifacts and latest files" do
    result = store.stage

    snapshot_dir = @central.join("results/rails-app/history/20261119T180000Z-1")
    expect(result).to be_a(described_class)
    expect(snapshot_dir.join("vuln-fs.json")).to exist
    expect(@central.join("results/rails-app/latest.md").read).to eq("# summary")
    expect(@central.join("results/rails-app/latest.json").read).to eq("{}")
  end

  it "keeps only the newest snapshots" do
    %w[20261119T180000Z-1 20261119T180100Z-2 20261119T180200Z-3].each do |snapshot|
      store(snapshot: snapshot).stage
    end

    expect(store.history_dirs.map { |dir| dir.basename.to_s }).to eq(
      %w[20261119T180100Z-2 20261119T180200Z-3]
    )
  end

  it "does not prune when keep is zero" do
    3.times { |i| store(snapshot: "20261119T180000Z-#{i}", keep: 0).stage }

    expect(store(keep: 0).history_dirs.length).to eq(3)
  end

  it "rejects path traversal in target names" do
    expect do
      described_class.new(central_dir: @central, out_dir: @out, target: "../evil",
                          snapshot: "20261119T180000Z-1")
    end.to raise_error(CveTriage::SnapshotStore::ValidationError)
  end
end
