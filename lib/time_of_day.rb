require 'date'

require "time_of_day/version"
require 'time_of_day/series'

module Kernel
  def TimeOfDay(value = nil)
    case value
    when TimeOfDay
      value
    when String
      TimeOfDay.parse(value)
    when Numeric
      TimeOfDay.from_number(value)
    when Time, DateTime
      TimeOfDay.from_time(value)
    when Enumerable
      TimeOfDay::Series.from_enumerable(value)
    when nil
      TimeOfDay.now
    else
      raise "Don't know how to coerce #{value.inspect} into a TimeOfDay"
    end
  end
  
  def TimeInterval(start_at, end_at)
    TimeOfDay::Series.new(TimeOfDay(start_at), TimeOfDay(end_at))
  end
end

class TimeOfDay
  include Comparable

  def self.format(string)
    if string =~ /\A\d{1,2}:\d\d (AM|PM)\z/
      '%l:%M %P'
    elsif string =~ /\A\d{1,2}:\d\d(AM|PM)\z/
      '%l:%M%P'
    elsif string =~ /\A\d{1,2}:\d\d\z/
      '%H:%M'
    end
  end

  def self.parse(string)
    return nil if string.nil? or string.empty?

    fmt = format(string)
    return nil unless fmt

    from_time(Time.strptime(string, fmt))
  end

  def self.now
    from_time(Time.now)
  end

  def self.at_beginning_of_day
    @at_beginning_of_day ||= new(0)
  end

  def self.at_end_of_day
    @at_end_of_day ||= new(23, 59)
  end

  def self.from_time(t)
    new(t.hour, t.min)
  end

  def self.from_number(num)
    hours = (num.to_r / 60)
    hour  = hours.floor
    min   = (hours - hour) * 60

    new(hour, min)
  end

  attr_reader :hour, :min

  def initialize(hour = 0, min = 0)
    @hour    = hour == 24 ? 0 : hour
    @min     = min
    @minutes = ((hour * 60) + min).to_r
  end

  def to_r
    @minutes
  end

  def round
    self.class.from_number((to_r / 15).round * 15)
  end

  def +(minutes)
    m = min + minutes
    return self.class.new(hour, m) if m < 60

    self.class.new(hour + 1, m - 60)
  end

  def -(other)
    return to_r - other.to_r if self.class === other

    m = min - other
    return self.class.new(hour, m) if m > -1

    self.class.new(hour - 1, m + 60)
  end

  def succ
    round + 15
  end

  def to_time(date)
    Time.local(date.year, date.month, date.day, hour, min)
  end

  def to_datetime(date)
    DateTime.new(date.year, date.month, date.day, hour, min)
  end
  alias with_date to_datetime

  def today
    with_date(Date.today)
  end

  def yesterday
    with_date(Date.today - 1)
  end

  def tomorrow
    with_date(Date.today + 1)
  end

  def ===(other)
    hour == other.hour && min == other.min
  end

  def <=>(other)
    return nil unless self.class === other

    cmp = hour <=> other.hour
    return min <=> other.min if cmp == 0
    
    cmp
  end

  def pm?
    hour >= 12
  end

  def am?
    hour < 12
  end

  def to_s
    ampm = pm? ? 'PM' : 'AM'
    h    = hour >  12 ? hour % 12 : hour
    
    sprintf("%d:%02d %s", h, min, ampm)
  end
end
