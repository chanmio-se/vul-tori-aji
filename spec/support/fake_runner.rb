# frozen_string_literal: true

module CveTriage
  # 外部コマンドの代わりに呼び出しを記録するテスト用ランナー。
  class FakeRunner
    attr_reader :calls

    def initialize(&on_run)
      @calls = []
      @on_run = on_run
    end

    def run(*args, **_kwargs)
      calls << args
      @on_run&.call(args)
      ""
    end

    def success?(*args, **_kwargs)
      calls << args
      true
    end
  end
end
