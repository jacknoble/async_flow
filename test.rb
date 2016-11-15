require_relative './async_flow'
class TestA
  def call(n)
    n + 7
  end
end
class TestB
  def self.call(n)
    n * 2
  end
end

class AsyncTest
  include AsyncFlow

  def implementation(data)
    other_data = a(TestA.new).call(data)
    resp = a(TestB).call(other_data)
    puts resp
  end
end

AsyncTest.new.call(123)


