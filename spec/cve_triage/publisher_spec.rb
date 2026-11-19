# frozen_string_literal: true

RSpec.describe CveTriage::Publisher do
  let(:store) do
    instance_double(CveTriage::SnapshotStore, relative_path: "results/rails-app", stage: nil)
  end
  let(:git) do
    instance_double(CveTriage::GitRepository, fetch: nil, reset_hard: nil, add: nil,
                                              commit: nil, push: nil, changes_staged?: true)
  end
  let(:logger) { ->(_message) {} }

  def publisher(attempts: 5)
    described_class.new(store: store, git: git, target: "rails-app",
                        snapshot: "20261119T180000Z-1", branch: "main",
                        attempts: attempts, logger: logger)
  end

  it "fetches, stages, commits and pushes" do
    expect(publisher.call).to eq(:published)

    expect(git).to have_received(:fetch).with("main")
    expect(git).to have_received(:reset_hard).with("origin/main")
    expect(store).to have_received(:stage)
    expect(git).to have_received(:commit).with("chore(scan): update rails-app (20261119T180000Z-1)")
    expect(git).to have_received(:push).with("main")
  end

  it "skips commit and push when nothing changed" do
    allow(git).to receive(:changes_staged?).and_return(false)

    expect(publisher.call).to eq(:unchanged)
    expect(git).not_to have_received(:commit)
    expect(git).not_to have_received(:push)
  end

  it "re-fetches and retries after a failed push" do
    pushes = 0
    allow(git).to receive(:push) do
      pushes += 1
      raise CveTriage::CommandRunner::Error, "push rejected" if pushes == 1
    end

    expect(publisher.call).to eq(:published)
    expect(pushes).to eq(2)
    expect(git).to have_received(:fetch).twice
    expect(store).to have_received(:stage).twice
  end

  it "gives up after the configured number of attempts" do
    allow(git).to receive(:push).and_raise(CveTriage::CommandRunner::Error, "push rejected")

    expect { publisher(attempts: 2).call }
      .to raise_error(CveTriage::Publisher::Error, /after 2 attempts/)
    expect(git).to have_received(:fetch).twice
  end
end
