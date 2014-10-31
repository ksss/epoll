require 'io/epoll/epoll'

class IO
  class Epoll
    class Event < Struct.new(:data, :events)
    end

    class << self
      alias create new
    end

    def add(io, events)
      ctl(CTL_ADD, io, events)
    end

    def mod(io, events)
      ctl(CTL_MOD, io, events)
    end

    def del(io)
      ctl(CTL_DEL, io)
    end

    def closed?
      fileno < 0
    end
  end

  def self.epoll(ios, events)
    ios = ios.to_a
    open_len = ios.length
    ep = Epoll.create
    ios.each do |io|
      ep.add(io, events)
    end
    if block_given?
      while 0 < open_len
        evlist = ep.wait
        evlist.each do |ev|
          yield ev
          if ev.events & (Epoll::HUP|Epoll::ERR)
            open_len -= 1
            ev.data.close
          end
        end
      end
      ep.close
    else
      evlist = ep.wait
      ep.close
      evlist
    end
  end
end
