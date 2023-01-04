require 'spec_helper'

class MatchExample
  def initialize(example)
    @example = example
  end

  def matches?(time)
    @time = time
    !@time.nil? && @time.hour == @example[:hour] && @time.min == @example[:min]
  end

  def failure_message
    "expected #{@time.inspect} to match #{@example.inspect}"
  end

  def failure_message_when_negated
    "expected #{@time.inspect} not to match #{@example.inspect}"
  end
end

RSpec.describe TimeOfDay do
  def expect_examples_to_be_valid(examples)
    examples.each do |example|
      time = described_class.parse(example[:string])
      time = yield time if block_given? && time
    
      expect(time).to match_example(example)
    end
  end

  def match_example(expected)
    MatchExample.new(expected)
  end

  describe '.parse' do
    it 'should parse in "HH:MM PP" format' do
      examples = [
        { string: '8:23 AM', hour: 8, min: 23 },
        { string: '8:35 PM', hour: 20, min: 35 },
        { string: '12:05 PM', hour: 12, min: 5 },
      ]

      expect_examples_to_be_valid(examples)
    end

    it 'should parse "HH:MM" format' do
      examples = [
        { string: '8:23', hour: 8, min: 23 },
        { string: '20:35', hour: 20, min: 35 },
        { string: '12:05', hour: 12, min: 5 },
      ]

      expect_examples_to_be_valid(examples)
    end

    it 'should parse "HH:MMPP" format' do
      examples = [
        { string: '8:23AM', hour: 8, min: 23 },
        { string: '8:35PM', hour: 20, min: 35 },
        { string: '12:05PM', hour: 12, min: 5 },
      ]

      expect_examples_to_be_valid(examples)
    end

    it 'should parse "HH:MM PP" format' do
      examples = [
        { string: '8:23 AM', hour: 8, min: 23 },
        { string: '8:35 PM', hour: 20, min: 35 },
        { string: '12:05 PM', hour: 12, min: 5 },
      ]

      expect_examples_to_be_valid(examples)
    end

    it 'should parse "HH:MM pp" format' do
      examples = [
        { string: '8:23 am', hour: 8, min: 23 },
        { string: '8:35 pm', hour: 20, min: 35 },
        { string: '12:05 pm', hour: 12, min: 5 },
      ]

      expect_examples_to_be_valid(examples)
    end
  end

  describe '#round' do
    it 'should round to the nearest 15 minutes' do
      examples = [
        { string: '8:00', hour: 8, min: 0 },
        { string: '8:01', hour: 8, min: 0 },
        { string: '8:05', hour: 8, min: 0 },
        { string: '8:07', hour: 8, min: 0 },
        { string: '8:08', hour: 8, min: 15 },
        { string: '8:09', hour: 8, min: 15 },
        { string: '8:14', hour: 8, min: 15 },
        { string: '8:15', hour: 8, min: 15 },
        { string: '8:22', hour: 8, min: 15 },
        { string: '8:23', hour: 8, min: 30 },
      ]
      
      expect_examples_to_be_valid(examples) { |time| time.round }
    end
  end
end
