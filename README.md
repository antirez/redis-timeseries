Redis timeseries README
=======================

Warning: this library is considered unstable, this is just the first public
         release. Please allow for more development time before using it
         in production environments.

Redis timeseries is a Ruby library implementing time series on top of Redis.
There are many ways to store time series into Redis, for instance using Lists
or Sorted Sets. This library takes a different approach storing time series
into Redis strings using the Redis APPEND command.

A central concept in this library is the "timestep", that is an interval of
time so that all the data points received in such an interval will be stored
in the same key.

The timestep is specified when creating the time series object:
    
    ts = RedisTimeSeries.new("test",3600,Redis.new)

In the above example a timestep of one hour (3600 seconds) was specified.
All the timeseries added will be segmented into keys containing just one
hour of data. Note that the timestep is aligned with the GMT time, so
for instance Redis will use different keys for all the time series sent
at 5pm and 6pm. This means that the segmentation is absolute and does not
use a timer created when the time series object is created.

Basically the name of the key is created using the following algorithm:

    key = ts:prefix:(UNIX_TIME - UNIX_TIME % TIMESTEP)

In the above example we used "test" as prefix, so you can have different
time series for different things in the same Redis server.

To add a data point you just need to perform the following call:

    ts.add("data")

The library will take care to store the time information in the data point.
Note that you may have an origin time that is different from the insertion time
so the add method accepts an additional argument where you can optionally
specify the origin time. In that case the origin time is returned when you
fetch data, together with the insertion time.

Actually the origin time is handled as a string, so you can add whatever
meta data you want inside.

You can query data in two ways:

    ts.fetch_range(start,end)
    ts.fetch_timestep(time)

The fetch_range method will fetch all the data samples in the specified
interval, while fetch_timestamp will fetch a whole single key (a timestep)
worth of data, accordingly to the time specified.

HOW IT WORKS
============

The library appends every data point as a string terminated by \x00 byte.
Every field inside the data point is delimited by \x01 byte.
If the data or metadata you add contains \x00 or \x01 characters, the library
will use base64 encoding to handle it transparently.

So every key is a single string containing multiple \x00 separated data points
that are mostly ordered in time. I say mostly since you may add data points
using multiple clients, and the clocks may not be perfectly synchronized, so
when performing range queries it is a good idea to enlarge the range a bit
to be sure you get everything.

Range queries are performed using binary search with Redis's GETRANGE inside
the string. Since the records are of different size we use a modified version
of binary search that is able to check for delimiters and adapt the search
accordingly. Range queries work correctly even when they spawn across multiple
keys.

The fetch_timestep method does not need any binary search, it is just a
single key lookup and is extremely fast.

ADVANTAGES
==========

- Very space efficient. Every timestep is stored inside a single Redis string so there is no overhead at all.
- Very fast. Adding a data point consists of just a single O(1) operation.
- It is designed to work with Redis Cluster (once released), and in general with different sharding policies: no multi keys op, nor big data structures into a single key. Even distributing the keys across multiple instances using a simple hashing algorithm will work well.
- Keys are already into a serialized format: it is trivial to move keys related to old time series into the file system or other big data systems, just using the Redis GET command, or to import back into Redis using SET.

DISADVANTAGES
=============

- Adding into the middle is not possible.

WARNINGS
========

It is not a good idea to change the used timestep. There is currently no
support for this. You'll not corrupt data but will make older data harder
to query.

CREDITS
=======

Thanks to Derek Collison and Pieter Noordhuis for design feedbacks.
The library was implemented by Salvatore Sanfilippo.

