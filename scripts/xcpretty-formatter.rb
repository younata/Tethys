class RNewsTestCase
  attr_accessor :test_case, :time

  def initialize(test_case, time)
    @test_case = test_case.to_s
    @time = time
  end 
end

require 'pry'

class RNewsFormatter < XCPretty::Formatter
  FAIL = "F"
  PASS = "."
  PENDING = "P"
  MEASURING = 'T'

  def initialize(use_unicode, colorize)
    super(use_unicode, colorize)
    @testCases = []
  end

  def optional_newline
    ''
  end

  def format_passing_test(suite, test_case, time)
    if time.to_f > 0.02
      @testCases << RNewsTestCase.new(suite + " - " + test_case, time)
    end
    green(PASS)
  end

  def format_failing_test(test_suite, test_case, reason, file)
    red(FAIL)
  end

  def format_pending_test(suite, test_case)
    yellow(PENDING)
  end

  def format_measuring_test(suite, test_case, time)
    yellow(MEASURING)
  end

  def format_test_summary(message, failures_per_suite)
    sortedTestCases = @testCases.sort {|x,y| y.time <=> x.time}
    longestTestCases = sortedTestCases.take(5)
    append = "#{longestTestCases.length} Slowest test cases:\n" + longestTestCases.map{|t| "    #{t.test_case} - #{t.time} seconds" }.join("\n")
    super + append + "\n"
  end
end

RNewsFormatter
