require 'io/epoll/epoll'

class IO
  class Epoll
    class << self
      alias create new
    end

    def add(io, events)
      ctl CTL_ADD, io, events
    end

    def mod(io, events)
      ctl CTL_MOD, io, events
    end

    def del(io)
      ctl CTL_DEL, io
    end
  end
end
