require 'date'
require 'time'
require 'forwardable'

require 'time_of_day/core_ext'
require 'time_of_day/series'
require 'time_of_day/version'

module Kernel
  def TimeOfDay(value = nil)
    case value
    when TimeOfDay
      value
    when String
      TimeOfDay.parse!(value)
    when Numeric
      TimeOfDay.from_minutes(value)
    when Time, DateTime
      TimeOfDay.from_time(value)
    when nil
      TimeOfDay.now
    else
      raise "Don't know how to coerce #{value.inspect} into a TimeOfDay"
    end
  end

  def TimeSeries(*times, **options)
    return TimeOfDay::Series.empty if times.length < 1
    return TimeOfDay::Series.from_array(times, **options) if times.length > 1

    case times[0]
    when Enumerable
      TimeOfDay::Series.from_enumerable(times[0], **options)
    else
      TimeOfDay::Series.from_array(times, **options) # return a series with one element
    end
  end

  def TimeInterval(start_at, end_at, **options)
    TimeOfDay::Series.new(TimeOfDay(start_at), TimeOfDay(end_at), 2, **options)
  end
end

# Represents a given time-of-day separate from any Date information.
# Makes it easy to perform work time calculations
class TimeOfDay
  include Comparable

  extend Forwardable
  def_delegators :today, :strftime
  def_delegators :to_r, :to_i, :to_f

  def self.registered_formats
    @registered_formats ||= []
  end

  def self.formats
    registered_formats.map { |fmt| fmt[1] }
  end

  def self.register_format(regex, format)
    registered_formats << [regex, format]
  end

  register_format /\A\d{1,2}:\d\d (AM|PM|am|pm)\z/, '%l:%M %P'
  register_format /\A\d{1,2}:\d\d(AM|PM|am|pm)\z/, '%l:%M%P'
  register_format /\A\d{1,2} (AM|PM|am|pm)\z/, '%l %P'
  register_format /\A\d{1,2}(AM|PM|am|pm)\z/, '%l%P'
  register_format /\A\d{1,2}:\d\d\z/, '%H:%M'
  register_format /\A\d{1,2}\z/, '%H'

  def self.format(string)
    registered_formats.each do |(regex, fmt)|
      return fmt if string =~ regex
    end
  end

  # @param [String] string
  #
  # @return [TimeOfDay, nil]
  def self.parse(string)
    return nil if string.nil? or string.empty?

    fmt = format(string)
    return nil unless fmt

    strptime(string, fmt)
  end

  # @param [String] string
  #
  # @return [TimeOfDay]
  def self.parse!(string)
    time = parse(string)
    raise "can't parse time in this format: #{string.inspect}" unless time

    time
  end

  # @param [String] string
  # @param [String] format
  #
  # @return [TimeOfDay]
  def self.strptime(string, format)
    from_time(Time.strptime(string, format))
  end

  # @return [TimeOfDay]
  def self.now
    from_time(Time.now)
  end

  # @return [TimeOfDay]
  def self.at_beginning_of_day
    @at_beginning_of_day ||= new(0, 0)
  end

  # @return [TimeOfDay]
  def self.at_end_of_day
    @at_end_of_day ||= new(23, 59)
  end

  # @return [TimeOfDay::Series]
  def self.all_day
    Series.from_enumerable(at_beginning_of_day..at_end_of_day - 14)
  end

  # @return [TimeOfDay]
  def self.at(time)
    if time.is_a?(Integer)
      from_minutes(time)
    elsif time.respond_to?(:hour) && time.respond_to?(:min)
      from_time(time)
    elsif time.is_a?(String)
      parse!(time)
    else
      raise TypeError, "can't coerce #{time.inspect} into a TimeOfDay"
    end
  end

  # @param [#hour, #min] time
  #
  # @return [TimeOfDay]
  def self.from_time(time)
    new(time.hour, time.min)
  end

  # @param [Numeric] minutes
  #
  # @return [TimeOfDay]
  def self.from_minutes(minutes)
    hours = (minutes.to_r / 60)
    hour  = hours.floor
    min   = (hours - hour) * 60

    new(hour, min)
  end

  # @param [Numeric] minute
  def self.valid_minute?(minute)
    minute >= 0 && minute < 60
  end

  # @param [Numeric] minute
  def self.validate_minute!(minute)
    raise TypeError, "#{minute} is not a valid minute value" unless valid_minute?(minute)
  end

  # @param [Numeric] hour
  def self.valid_hour?(hour)
    hour >= 0 && hour <= 24
  end

  # @param [Numeric] hour
  def self.validate_hour!(hour)
    raise TypeError, "#{hour} is not a valid hour value" unless valid_hour?(hour)
  end

  attr_reader :hour, :min, :rounding_factor

  # @param [Integer] hour
  # @param [Integer] min
  def initialize(hour = 0, min = 0)
    self.class.validate_hour!(hour)
    self.class.validate_minute!(min)

    @hour    = hour == 24 ? 0 : hour
    @min     = min
    @minutes = ((hour * 60) + min).to_r

    freeze
  end

  # @return [Rational]
  def to_r
    @minutes
  end

  DEFAULT_ROUNDING_FACTOR = 15

  # @param [Integer] factor
  #
  # @return [TimeOfDay] a new rounded TimeOfDay
  def round(factor = DEFAULT_ROUNDING_FACTOR)
    self.class.from_minutes((to_r / factor).round * factor)
  end

  # @param [Numeric] minutes
  #
  # @return [TimeOfDay]
  def +(minutes)
    m = min + minutes
    return TimeOfDay.new(hour, m) if m < 60

    TimeOfDay.new(hour + 1, m - 60)
  end

  # @param [TimeOfDay, Numeric] other
  #
  # @return [TimeOfDay, Numeric]
  def -(other)
    return to_r - other.to_r if other.is_a?(self.class) # returns the difference

    # assume 'other' is a number and subtract that number of minutes
    m = min - other
    return TimeOfDay.new(hour, m) if m > -1

    TimeOfDay.new(hour - 1, m + 60)
  end

  def succ(step = 15)
    round(step) + step
  end

  # @param [#year, #month, #day] date
  #
  # @return [Time]
  def to_time(date)
    Time.local(date.year, date.month, date.day, hour, min)
  end

  # @param [#year, #month, #day] date
  #
  # @return [DateTime]
  def to_datetime(date)
    DateTime.new(date.year, date.month, date.day, hour, min)
  end
  alias with_date to_datetime
  alias on_date to_datetime

  # @return [DateTime]
  def today
    with_date(Date.today)
  end

  # @return [DateTime]
  def yesterday
    with_date(Date.today - 1)
  end

  # @return [DateTime]
  def tomorrow
    with_date(Date.today + 1)
  end

  # @param [#hour, #min] other
  #
  # @return [Boolean]
  def ===(other)
    return false unless other.respond_to?(:hour) && other.respond_to?(:min)

    hour == other.hour && min == other.min
  end

  # @param [#hour, #min] other
  #
  # @return [1, 0, -1]
  def <=>(other)
    return nil unless other.respond_to?(:hour) && other.respond_to?(:min)

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
  alias inspect to_s

  DECONSTRUCTION_KEYS = %i[hour min].freeze

  def deconstruct_keys(keys)
    keys.inject({}) do |res, key|
      case key
      when :hour then res.merge!(hour: hour)
      when :min then res.merge!(min: min)
      end
    end
  end

  # @return [Hash]
  def to_h
    deconstruct_keys(DECONSTRUCTION_KEYS)
  end

  # @return [Array]
  def deconstruct
    [hour, min]
  end

  alias to_a deconstruct

  def to_series
    Series.empty.prepend(self)
  end

  def to_interval(end_at)
    Series.new(self, end_at)
  end
end
