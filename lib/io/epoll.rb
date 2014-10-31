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
end
