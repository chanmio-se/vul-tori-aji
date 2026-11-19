# frozen_string_literal: true

module CveTriage
  # 集約リポジトリに対する git 操作をまとめる。引数は配列で渡すのでシェル展開されない。
  class GitRepository
    def initialize(dir:, runner: CommandRunner.new)
      @dir = Pathname.new(dir)
      @runner = runner
    end

    def configure_author(name:, email:)
      git("config", "user.name", name)
      git("config", "user.email", email)
    end

    def fetch(branch)
      git("fetch", "--quiet", "origin", branch)
    end

    def reset_hard(ref)
      git("reset", "--hard", "--quiet", ref)
    end

    def add(path)
      git("add", "--", path)
    end

    def changes_staged?(path)
      !runner.success?("git", "-C", dir.to_s, "diff", "--cached", "--quiet", "--", path)
    end

    def commit(message)
      git("commit", "--quiet", "-m", message)
    end

    def push(branch)
      git("push", "--quiet", "origin", "HEAD:#{branch}")
    end

    private

    attr_reader :dir, :runner

    def git(*args)
      runner.run("git", "-C", dir.to_s, *args)
    end
  end
end
