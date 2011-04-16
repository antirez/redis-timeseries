require 'rubygems'
require 'redis'
require './sorted-set'

# To show the lib implementation here we use a timestep of just one second.
# Then we sample every 0.1 seconds, producing on average 10 samples per key.
# This way we should how multi-key range queries are working.
ts = RedisTimeSeries.new("test",1,Redis.new)

now = Time.now.to_f
puts "Adding data points: "
(0..300).each{|i|
    print "#{i} "
    STDOUT.flush
    time = (now+(i/10.0))
    ts.add({:time => time, :data => i.to_s}, time)
}
puts ""

# Get the second in the middle of our sampling.
begin_time = now+1
end_time = now+2
puts "\nGet range from #{begin_time} to #{end_time}"

ts.fetch_range(begin_time,end_time).each{|record|
    puts "Record time #{record[:time]}, data #{record[:data]}"
}

# Show API to get a single timestep
puts "\nGet a single timestep near #{begin_time}"
ts.fetch_timestep(begin_time).each{|record|
    puts "Record time #{record[:time]}, data #{record[:data]}"
}
