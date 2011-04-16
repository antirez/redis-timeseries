require 'base64'

class RedisTimeSeries
    def initialize(prefix,timestep,redis)
        @prefix = prefix
        @timestep = timestep
        @redis = redis
    end

    def normalize_time(t)
        t = t.to_i
        t - (t % @timestep)
    end

    def getkey(t)
        "ts:#{@prefix}:#{normalize_time t}"
    end

    def add(data,timestamp=nil,marshal=true)
        timestamp ||= Time.now.to_f
        data = marshal ? Marshal.dump(data) : data
        @redis.zadd(getkey(timestamp), timestamp, data)
    end

    def fetch_range(begin_time,end_time,marshal=true)
      begin_time = begin_time.to_f
      end_time = end_time.to_f
      result = (0..((end_time - begin_time) / @timestep)).collect do |i|
        key = getkey(begin_time + (i*@timestep))
        
        r = @redis.zrangebyscore(key, begin_time.to_f,end_time.to_f)
        marshal ? r.collect{|elem| Marshal.load(elem) } : r
      end
      result.flatten
    end

    def fetch_timestep(time, marshal=true)
        t = time.to_f
        r = @redis.zrangebyscore(getkey(time), t, t)
        marshal ? r.collect{|elem| Marshal.load(elem) } : r
    end
end
