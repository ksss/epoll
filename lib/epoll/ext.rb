class Epoll
  include Epoll::Constants

  class << self
    alias create open
  end

  def add(io, ev)
    ctl CTL_ADD, io, ev
  end

  def mod(io, ev)
    ctl CTL_MOD, io, ev
  end

  def del(io)
    ctl CTL_DEL, io
  end
end
