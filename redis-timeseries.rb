require 'rubygems'
require 'base64'
require 'redis'

class RedisTimeSeries
    def initialize(prefix,timestep,redis)
        @prefix = prefix
        @timestep = timestep
        @redis = redis
    end

    def getkey(t)
        t = t-(t % @timestep)
        "ts:#{@prefix}:#{t}"
    end

    def tsencode(data)
        if data.index("\x00") or data.index("\x01")
            "E#{Base64.encode64(data)}"
        else
            "R#{data}"
        end
    end

    def tsdecode(data)
        if data[0..0] == 'E'
            Base64.decode64(data[1..-1])
        else
            data[1..-1]
        end
    end

    def add(data,origin_time=nil)
        data = tsencode(data)
        origin_time = tsencode(origin_time) if origin_time
        now = Time.now.to_f
        value = "#{now}\x01#{data}"
        value << "\x01#{origin_time}" if origin_time
        value << "\x00"
        @redis.append(getkey(now.to_i),value)
    end

    def decode_record(r)
        res = {}
        s = r.split("\x01")
        res[:time] = s[0].to_f
        res[:data] = tsdecode(s[1])
        if s[2]
            res[:origin_time] = tsdecode(s[2])
        else
            res[:origin_time] = nil
        end
        return res
    end

    def seek(time)
        rangelen = 64
        key = getkey(time.to_i)
        len = @redis.strlen(key)
        return 0 if len == 0
        min = 0
        max = len-1
        while min < max
            p = min+((max-min)/2)
            puts "Min: #{min} Max: #{max} P: #{p}"
            # Seek the first complete record starting from position 'p'.
            # We need to search for two consecutive \x00 chars, and enlarnge
            # the range if needed as we don't know how big the record is.
            while true
                range_end = p+rangelen-1
                range_end = max if range_end > max
                r = @redis.getrange(key,p,range_end)
                sep = r.index("\x00")
                sep2 = r.index("\x00",sep+1) if sep
                if sep and sep2
                    record = r[((sep+1)...sep2)]
                    record_start = p+sep+1
                    record_end = p+sep2-1
                    break
                end
                if range_end >= max
                    record = nil
                    break
                end
                # We need to enlrange the range, it is interesting to note
                # that we take the enlarged value: likely other time series
                # will be the same size on average.
                rangelen *= 2
            end
            return max+1 if !record
            dr = decode_record(record)
            puts dr.inspect
            return record_start if dr[:time] == time
            if dr[:time] > time
                max = record_start-1
            else
                min = record_start-1
            end
        end
        return min+1
    end
end

ts = RedisTimeSeries.new("test",3600*24,Redis.new)
puts ts.seek(1299142304.70)
puts ts.seek(1299142311.3)
puts ts.seek(1299142301.2)
=begin
(0..100).each{|i|
    ts.add(i.to_s)
    sleep 0.1
}
=end
