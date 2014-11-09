require 'test/unit'
require 'timeout'
require_relative '../lib/epoll'

class TestIOEpoll < Test::Unit::TestCase
  def test_initalize
    assert_instance_of(Epoll, Epoll.new);
    assert_instance_of(Epoll, Epoll.create);
  end

  def test_create_with_block
    instance = nil
    ret_val = Epoll.create do |ep|
      instance = ep
      assert { instance.closed? == false }
      :block_end
    end
    assert { instance.kind_of?(Epoll) == true }
    assert { instance.closed? == true }
    assert { ret_val == :block_end }
  end

  def test_create_with_block_ensure_close
    instance = nil
    catch do |ok|
      Epoll.create do |ep|
        instance = ep
        throw ok
      end
    end
    assert { true == instance.closed? }

    assert_nothing_raised do
      Epoll.create do |ep|
        ep.close
      end
    end
  end

  def test_inspect
    Epoll.create do |ep|
      fd = ep.fileno
      assert { "#<Epoll:fd #{fd}>" == ep.inspect }
      ep.close
      assert { "#<Epoll:(closed)>" == ep.inspect }
    end
  end

  def test_fileno
    ep = Epoll.create
    assert { 0 < ep.fileno }
    ep.close
    assert_raise(IOError) { ep.fileno }
  end

  def test_ctl
    Epoll.create do |ep|
      io = IO.new(1, 'w')
      assert { ep == ep.ctl(Epoll::CTL_ADD, io , Epoll::OUT) }
      assert_raise(ArgumentError) { ep.ctl }
      assert_raise(ArgumentError) { ep.ctl(Epoll::CTL_ADD) }
      assert_raise(ArgumentError) { ep.ctl(Epoll::CTL_ADD, io) }
      assert_raise(ArgumentError) { ep.ctl(-1, io) }
      assert_raise(TypeError) { ep.ctl(nil, nil, nil) }
    end
  end

  def test_add
    ep = Epoll.create
    io = IO.new(1, 'w')
    assert_raise(IOError) { ep.add(io, 0) }
    assert { ep == ep.add(io, Epoll::IN|Epoll::PRI|Epoll::RDHUP|Epoll::ET|Epoll::OUT) }
    ep.close
    assert_raise(Errno::EBADF) { ep.add(io, Epoll::OUT) }
  end

  def test_mod
    ep = Epoll.create
    io = IO.new(1, 'w')
    assert_raise(Errno::ENOENT) { ep.mod(io, Epoll::IN) }
    ep == ep.add(io, Epoll::OUT)
    assert { ep == ep.mod(io, Epoll::IN) }
    ep.close
    assert_raise(Errno::EBADF) { ep.add(io, Epoll::OUT) }
  end

  def test_del
    ep = Epoll.create
    io = IO.new(1, 'w')
    assert_raise(Errno::ENOENT) { ep.del(io) }
    ep.add(io, Epoll::OUT)
    assert { ep == ep.del(io) }
    ep.close
    assert_raise(Errno::EBADF) { ep.del(io) }
  end

  def test_wait
    Epoll.create do |ep|
      IO.pipe do |r, w|
        ep.add(r, Epoll::IN|Epoll::ET)
        ep.add(w, Epoll::OUT|Epoll::ET)
        evlist = ep.wait
        assert { [Epoll::Event.new(w, Epoll::OUT)] == evlist }
        assert_instance_of(IO, evlist[0].data)
        assert_instance_of(Fixnum, evlist[0].events)

        w.write('ok')
        assert { [Epoll::Event.new(r, Epoll::IN)] == ep.wait }

        assert_raise(IOError) { Epoll.create.wait }
      end
    end
  end

  def test_wait_with_timeout
    Epoll.create do |ep|
      io = IO.new(1, 'w')
      ep.add(io, Epoll::IN)
      assert { [] == ep.wait(0) }
      assert { [] == ep.wait(1) }
      assert_raise(TimeoutError) do
        timeout(0.01) { ep.wait(-1) }
      end
      assert_raise(TypeError) { ep.wait(nil) }
    end
  end

  def test_size
    Epoll.create do |ep|
      IO.pipe do |r, w|
        ep.add(r, Epoll::IN)
        assert { 1 == ep.size }
        ep.add(w, Epoll::OUT)
        assert { 2 == ep.size }
        ep.del(w)
        assert { 1 == ep.size }
        ep.del(r)
        assert { 0 == ep.size }
      end
    end
  end

  def test_close
    assert_nothing_raised do
      fileno = nil
      10.times do
        ep = Epoll.create
        fileno = ep.fileno unless fileno
        assert { fileno == ep.fileno }
        ep.close

        Epoll.create do
        end
      end
    end

    ep = Epoll.create
    ep.close
    assert_raise(IOError){ ep.close }
  end

  def test_closed?
    ep = Epoll.create
    assert { false == ep.closed? }
    ep.close
    assert { true == ep.closed? }
  end

  def test_dup
    Epoll.create do |ep|
      IO.pipe do |r, w|
        ep.add(r, Epoll::IN|Epoll::ET)
        ep.add(w, Epoll::OUT|Epoll::ET)
        dup = ep.dup
        assert { ep != dup }
        assert { ep.fileno != dup.fileno }
        assert { 2 == dup.size }
        assert { [Epoll::Event.new(w, Epoll::OUT)] == dup.wait }
        w.write 'ok'
        assert { [Epoll::Event.new(r, Epoll::IN)] == dup.wait }
      end
    end
  end

  def test_close_on_exec
    if defined? Fcntl::FD_CLOEXEC
      Epoll.create do |ep|
        assert { true == ep.close_on_exec? }
        ep.close_on_exec = false
        assert { false == ep.close_on_exec? }
        ep.close_on_exec = true
        assert { true == ep.close_on_exec? }
        ep.close_on_exec = false
        assert { false == ep.close_on_exec? }
        ep.close
        assert_raise { ep.close_on_exec = true }
        assert_raise { ep.close_on_exec? }
      end
    else
      pend "Fcntl::FD_CLOEXEC undefined"
    end
  end

  def test_thread
    Epoll.create do |ep|
      io = IO.new(1, 'w')
      ep.add(io, Epoll::OUT)
      ret = nil
      Thread.start {
        ret = ep.wait
      }.join
      assert { io == ret[0].data }
    end
  end
end
