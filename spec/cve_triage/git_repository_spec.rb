# frozen_string_literal: true

RSpec.describe CveTriage::GitRepository do
  let(:runner) { CveTriage::FakeRunner.new }
  let(:git) { described_class.new(dir: "/repo", runner: runner) }

  it "runs git with -C so no shell is involved" do
    git.configure_author(name: "bot", email: "bot@example.com")
    git.fetch("main")
    git.reset_hard("origin/main")
    git.add("results/rails-app")
    git.commit("chore(scan): update")
    git.push("main")

    expect(runner.calls).to eq([
      ["git", "-C", "/repo", "config", "user.name", "bot"],
      ["git", "-C", "/repo", "config", "user.email", "bot@example.com"],
      ["git", "-C", "/repo", "fetch", "--quiet", "origin", "main"],
      ["git", "-C", "/repo", "reset", "--hard", "--quiet", "origin/main"],
      ["git", "-C", "/repo", "add", "--", "results/rails-app"],
      ["git", "-C", "/repo", "commit", "--quiet", "-m", "chore(scan): update"],
      ["git", "-C", "/repo", "push", "--quiet", "origin", "HEAD:main"]
    ])
  end

  it "detects staged changes via the exit status" do
    allow(runner).to receive(:success?).and_return(false)
    expect(git.changes_staged?("results/rails-app")).to be(true)

    allow(runner).to receive(:success?).and_return(true)
    expect(git.changes_staged?("results/rails-app")).to be(false)
  end
end
