# frozen_string_literal: true

RSpec.describe CveTriage::Ai::CopilotClient do
  let(:runner) { CveTriage::FakeRunner.new }
  let(:logger) { ->(_message) {} }

  it "runs Copilot in programmatic mode with a pinned model" do
    client = described_class.new(runner: runner, model: "claude-haiku-4.5", logger: logger)

    expect(client.call("triage these CVEs")).to eq("")

    expect(runner.calls.last).to eq(
      ["copilot", "-p", "triage these CVEs", "-s", "--no-ask-user",
       "--model", "claude-haiku-4.5"]
    )
  end

  it "omits the model when not specified" do
    described_class.new(runner: runner, logger: logger).call("prompt")

    expect(runner.calls.last).not_to include("--model")
  end

  it "wraps command failures" do
    failing = CveTriage::FakeRunner.new do |_args|
      raise CveTriage::CommandRunner::Error, "command failed (exit 1): copilot"
    end

    expect { described_class.new(runner: failing, logger: logger).call("prompt") }
      .to raise_error(CveTriage::Ai::CopilotClient::Error, /Copilot CLI failed/)
  end

  it "rejects an empty prompt" do
    expect { described_class.new(runner: runner, logger: logger).call("  ") }
      .to raise_error(CveTriage::Ai::CopilotClient::Error, /prompt is empty/)
  end
end
