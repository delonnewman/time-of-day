# TimeOfDay

## Synopsis

### Arithmetic

```ruby
(TimeOfDay('1:12PM') + 1).to_s # => "1:13 PM"

(TimeOfDay('1:12PM') - 1).to_s # => "1:12 PM"
```

### Range Support

```ruby
(TimeOfDay('8:00AM')..TimeOfDay('5:00PM')).map(&:to_s) # => ["8:00 AM", "8:15 AM", "8:30 AM", ...]
```

### Rounding the nearest 15min interval

```ruby
TimeOfDay('8:34AM').round.to_s # => "8:30 AM"
```

### Rounded time calculations

```ruby
TimeOfDay::Series('8:34AM', '12:05PM').hours.to_f # => 3.5

TimeOfDay::Series('8:34AM', '12:05PM', '1:34PM', '5:23PM').hours.to_f # => 7.5

TimeOfDay::Series('8:34AM', '12:05PM', '1:34PM', '5:23PM').work_time.to_f # 450.0 (in minutes)

TimeOfDay::Series('8:34AM', '12:05PM', '1:34PM', '5:23PM').break_time.to_f # 90.0 (in minutes)
```

## Why?



## Installation

Add this line to your application's Gemfile:

```ruby
gem 'time-of-day'
```

And then execute:

    $ bundle install

Or install it yourself as:

    $ gem install time-of-day

## License

The gem is available as open source under the terms of the [MIT License](https://opensource.org/licenses/MIT).

## Code of Conduct

Everyone interacting in the TimeOfDay project's codebases, issue trackers, chat rooms and mailing lists is expected to follow the [code of conduct](https://github.com/[USERNAME]/time-of-day/blob/master/CODE_OF_CONDUCT.md).
