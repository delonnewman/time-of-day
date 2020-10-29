class TimeOfDay
  class Series
    include Enumerable

    attr_reader :start_at, :end_at, :count

    def self.empty
      @empty ||= new(nil, nil, 0)
    end

    def self.from_enumerable(times)
      return empty if times.nil? or times.count.zero? or times.count.odd?
      return new(*times.map { |t| TimeOfDay(t) }) if times.count == 2

      times.to_a.reverse.reduce do |interval, time|
        if self === interval
          new(TimeOfDay(time), interval, interval.count + 1)
        else
          new(TimeOfDay(time), TimeOfDay(interval))
        end
      end
    end

    def self.[](*times)
      from_enumerable(times)
    end

    def initialize(start_at, end_at, count = 2, with_break_deducting: false)
      @start_at     = start_at
      @end_at       = end_at
      @count        = count
      @deduct_break = with_break_deducting
    end

    def should_deduct_break?
      @deduct_break
    end

    alias first start_at
    alias next  end_at

    def each
      return self if empty?

      yield first

      unless series?
        yield self.next
        return self
      end

      self.next.each(&Proc.new)
      self
    end

    def [](n)
      return nil             if empty?
      return first           if n == 0
      return self.next       if n == 1 and interval?
      return self.next.first if n == 1 and series?
      return nil             if n == 2 and interval?

      self.next[n - 1]
    end

    def work_time
      return 0 if empty?

      (1...count).select(&:odd?).map do |i|
        self[i].round - self[i - 1].round
      end.sum
    end

    def break_time
      return 0 if empty?

      (2...count).select(&:even?).map do |i|
        self[i].round - self[i - 1].round
      end.sum
    end

    def break_deduction_applied?
      should_deduct_break? and break_time < 30 and work_time >= MINUTES_WHEN_BREAK_DEDUCTION_REQUIRED
    end

    def with_break_deducting
      self.class.new(start_at, end_at, count, with_break_deducting: true)
    end

    def without_break_deducting
      self.class.new(start_at, end_at, count, with_break_deducting: false)
    end

    def empty?
      count.zero?
    end

    def series?
      self.class === end_at
    end

    def interval?
      !series?
    end

    def minutes
      return work_time unless break_deduction_applied?

      work_time - 30
    end

    def hours
      minutes / 60
    end

    def seconds
      minutues * 60
    end

    private

    MINUTES_WHEN_BREAK_DEDUCTION_REQUIRED = 375 # 6.25 hours
  end
end
