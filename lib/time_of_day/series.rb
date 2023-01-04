# frozen_string_literal: true

class TimeOfDay
  # A series of TimeOfDay objects
  class Series
    include Enumerable

    attr_reader :start_at, :end_at, :count, :options

    alias length count
    alias size count

    # Return the empty TimeOfDay series
    #
    # @return [TimeOfDay::Series]
    def self.empty
      @empty ||= new(nil, nil, 0)
    end

    # Convert an array of objects that can be coerced into TimeOfDay objects
    # into a TimeOfDay::Series.
    #
    # @param [Array] times
    #
    # @return [TimeOfDay::Series]
    def self.from_array(times, **options)
      return empty if times.nil? or times.empty?

      times.reduce_right(empty) do |interval, time|
        new(TimeOfDay(time), interval, interval.count + 1, **options)
      end
    end

    # Convert an enumerable of objects that can be coerced into TimeOfDay objects
    # into a TimeOfDay::Series.
    #
    # @param [Enumerable] times
    #
    # @return [TimeOfDay::Series]
    def self.from_enumerable(times, **options)
      from_array(times.to_a, **options)
    end

    # Convert a sequence of objects that can be coerced into TimeOfDay objects
    # into a TimeOfDay::Series.
    #
    # @param [Array] times
    #
    # @return [TimeOfDay::Series]
    def self.[](*times)
      from_array(times)
    end

    def self.break_deduction_limit
      @break_deduction_limit
    end

    def self.break_deduction_limit=(value)
      @break_deduction_limit = value
    end

    def self.valid_interval?(series)
      return false unless series.is_a?(self) && series.interval?
      return true if series.start_at.nil? || series.end_at.nil?

      series.end_at >= series.start_at
    end

    def self.valid_series?(series)
      return false unless series.is_a?(self) && series.series?
      return true if series.empty? || series.end_at.empty?

      series.end_at.start_at >= series.start_at
    end

    def self.valid?(series)
      valid_series?(series) || valid_interval?(series)
    end

    def self.validate!(series)
      raise TypeError, "not a valid series: #{series.inspect}:#{series.class}" unless valid?(series)
    end

    DEFAULT_OPTIONS = {
      deduct_break: false,
      deduction_limit: 375, # 6.25 hours
      deducted_break: 30,
      rounding_factor: 15,
    }.freeze

    # @param [TimeOfDay, nil] start_at
    # @param [TimeOfDay, TimeOfDay::Series, nil] end_at
    # @param [Integer] count
    #
    # @param [Hash] options
    # @option options [Boolean] :deduct_break
    # @option options [Numeric] :deduction_limit
    # @option options [Integer] :rounding_factor
    def initialize(start_at, end_at, count = 2, **options)
      @start_at = start_at
      @end_at   = end_at
      @count    = count
      @options  = options.empty? ? DEFAULT_OPTIONS : DEFAULT_OPTIONS.merge(options).freeze

      self.class.validate!(self)
      freeze
    end

    def deduct_break?
      options.fetch(:deduct_break)
    end
    alias break_deducting_enabled? deduct_break?

    def deducted_break
      options.fetch(:deducted_break)
    end

    def deduction_limit
      options.fetch(:deduction_limit)
    end
    alias break_deduction_limit deduction_limit

    def rounding_factor
      options.fetch(:rounding_factor)
    end

    alias first start_at
    alias next  end_at

    # @return [Series]
    def prepend(time)
      raise TypeError, 'cannot prepend intervals' if interval?

      self.class.new(TimeOfDay(time), self, count + 1)
    end

    # @return [Series]
    def append(time)
      raise TypeError, 'cannot append intervals' if interval?

      new = self.class.new(TimeOfDay(time), self.class.empty, 1)
      return new if empty?

      end_at.append(time).prepend(start_at)
    end
    alias << append

    def last_pair
      return if interval? || empty?

      pair = self
      pair = pair.end_at until pair.end_at.empty?

      pair
    end

    def last
      return end_at if interval?
      return start_at if end_at.empty?

      last_pair&.start_at
    end

    # Iterate over each element in the series yielding it to the block.
    #
    # @yieldparam time [TimeOfDay]
    #
    # @return [Series]
    def each(&block)
      return self if empty?

      block.call(start_at)

      if interval?
        block.call(end_at)
        return self
      end

      self.next.each(&block)
      self
    end

    # @return [TimeOfDay, nil]
    def at(n)
      return nil             if empty?
      return first           if n == 0
      return self.next       if n == 1 and interval?
      return self.next.first if n == 1 and series?
      return nil             if n == 2 and interval?

      self.next[n - 1]
    end
    alias [] at

    # @return [TimeOfDay, nil]
    def rounded(n)
      at(n)&.round(rounding_factor)
    end

    # Return the amount of time within intervals in minutes
    #
    # @return [Integer]
    def interval_time
      return 0 if empty?

      (1...count).step(2).reduce(0) do |sum, i|
        sum + (rounded(i) - rounded(i - 1))
      end
    end
    alias interval_minutes interval_time

    def interval_hours
      interval_minutes / 60
    end

    def interval_seconds
      interval_minutes * 60
    end

    # Return the amount of time within interval gaps in minutes
    #
    # @return [Integer]
    def gap_time
      return 0 if empty?

      (2...count).step(2).reduce(0) do |sum, i|
        sum + (rounded(i) - rounded(i - 1))
      end
    end
    alias gap_minutes gap_time

    def gap_hours
      gap_minutes / 60
    end

    def gap_seconds
      gap_minutes * 60
    end

    def break_deduction_applied?
      break_deducting_enabled? and break_deduction_required?
    end

    def break_deduction_required?
      gap_time < deducted_break and interval_time >= break_deduction_limit
    end

    def with_break_deducting(**options)
      self.class.new(start_at, end_at, count, deduct_break: true, **options)
    end

    def without_break_deducting
      self.class.new(start_at, end_at, count, deduct_break: false)
    end

    def empty?
      count.zero?
    end

    def series?
      empty? or end_at.is_a?(self.class)
    end

    def interval?
      !series?
    end

    def minutes
      return interval_time unless break_deduction_applied?

      interval_time - deducted_break
    end
    alias duration minutes

    def hours
      minutes / 60
    end

    def seconds
      minutes * 60
    end

    def even?
      count.even?
    end

    def odd?
      !even?
    end

    def to_s
      str = +"("

      if odd?
        str << map(&:to_s).join(', ')
      else
        str << each_slice(2).map { |(s, e)| "#{s} => #{e}" }.join(', ')
      end

      str << ")"
      str.freeze
    end
    alias inspect to_s

    # @return [Hash{TimeOfDay => TimeOfDay}]
    def pairs
      each_slice(2).to_h
    end
    alias to_h pairs

    # @return [Range, nil]
    def to_range
      return unless interval?

      start_at..end_at
    end
  end
end
