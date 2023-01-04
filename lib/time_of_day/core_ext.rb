# frozen_string_literal: true

class Array
  def reduce_right(init = nil, &block)
    idx  = length - 1
    memo = init

    if init.nil?
      idx  = length - 2
      memo = self[length - 1]
    end

    while idx > -1
      memo = block.call(memo, self[idx])
      idx -= 1
    end

    memo
  end
end

module DateTimeExtensions
  def to_time_of_day
    TimeOfDay.from_time(self)
  end
  alias time_of_day to_time_of_day
end

class DateTime
  include DateTimeExtensions
end

class Time
  include DateTimeExtensions
end
