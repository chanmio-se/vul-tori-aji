# frozen_string_literal: true

RSpec.describe CveTriage::CommandRunner do
  let(:runner) { described_class.new(logger: ->(_message) {}) }

  it "captures stdout without requiring chdir" do
    expect(runner.run("ruby", "-e", "print 'ok'")).to eq("ok")
  end

  it "supports chdir" do
    Dir.mktmpdir do |dir|
      expect(runner.run("pwd", chdir: dir).strip).to eq(File.realpath(dir))
    end
  end

  it "raises on a non-zero exit" do
    expect { runner.run("ruby", "-e", "abort 'boom'") }
      .to raise_error(CveTriage::CommandRunner::Error, /command failed/)
  end
end
