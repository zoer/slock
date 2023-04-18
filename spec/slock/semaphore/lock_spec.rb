RSpec.describe Slock::Semaphore::Lock do
  let(:opts) { { redis: redis, lifetime: 10, size: size } }
  let(:lifetime) { 10 }
  let(:semaphore) { Slock::Semaphore.new(key, opts) }
  let(:size) { 1 }
  let(:key) { SecureRandom.uuid }
  let(:lock) { described_class.new(semaphore, token, opts) }
  let(:samelock) { described_class.new(semaphore, token, opts) }
  let(:token) { rand(0..10).to_s }
  let(:now) { Time.now }

  def timeout(time = 0.3, &block)
    Timeout.timeout(time, &block)
  end

  it '#tokens_path' do
    expect(lock.tokens_path).to eq "#{key}:tokens"
  end

  it '#id_path' do
    expect(lock.id_path).to eq "#{key}:tokens:#{token}:id"
  end

  it '#live_path' do
    expect(lock.live_path).to eq "#{key}:tokens:#{token}:live"
  end

  it '#own' do
    expect { lock.own }.to \
      change { redis.exists?(lock.id_path) }.to(true).and \
        change { redis.get(lock.id_path) }.from(nil).to(lock.id)
  end

  describe '#owned?' do
    it 'with empty owner' do
      expect(lock.owned?(true)).to be true
      expect(lock.owned?(false)).to be false
    end

    context 'with correct owner' do
      before { redis.set(lock.id_path, lock.id) }

      it 'owns' do
        expect(lock.owned?(true)).to be true
        expect(lock.owned?(false)).to be true
      end
    end

    context 'with wrong owner' do
      before { redis.set(lock.id_path, SecureRandom.uuid) }

      it 'owns' do
        expect(lock.owned?(true)).to be false
        expect(lock.owned?(false)).to be false
      end
    end
  end

  it '#live?' do
    expect { redis.set(lock.live_path, key) }.to \
      change(lock, :live?).to(true)
  end

  it '#locked?' do
    expect { redis.set(lock.id_path, lock.id) }.to \
      change(lock, :locked?).to(true)
    expect { redis.set(lock.id_path, SecureRandom.uuid) }.to \
      change(lock, :locked?).to(false)
    expect { redis.set(lock.id_path, nil) }.to \
      avoid_changing { lock.locked? }.from(false)
  end

  it '#renew' do
    expect { lock.renew }.to \
      change { redis.get(lock.live_path) }.to eq(lock.id)
    expect(redis.ttl(lock.live_path)).to be_within(1).of(lifetime)
  end

  describe '#lock' do
    it do
      expect(lock).to receive(:check_owner!).with(true).and_call_original

      expect { timeout(123_124) { lock.lock } }.to \
        change(lock, :locked?).to(true).and \
          change(lock, :live?).to(true)

      expect { timeout { samelock.lock } }.to \
        raise_error Slock::Errors::WrongLockOwnerError
    end
  end

  describe '#change' do
    context 'when already is in changable mode' do
      before do
        lock.instance_variable_set(:@changable, true)
        expect(lock.client).not_to receive(:set)
      end

      it 'yields' do
        expect(lock.change { 123 }).to eq 123
      end
    end

    context 'when is not in changable mode yet' do
      before do
        expect(lock.client).to receive(:set).and_call_original
      end

      it 'yields' do
        expect(lock.instance_variable_get(:@changable)).to be_nil

        res = lock.change do
          expect(lock.instance_variable_get(:@changable)).to be true
          321
        end

        expect(res).to eq 321
      end
    end

    describe '#release' do
      context 'when lock is owned' do
        let(:token) { size.to_s }

        before do
          lock.own
          lock.renew
          expect(lock).to receive(:owned?).with(no_args).and_call_original
          expect(lock).to receive(:_release).and_call_original
        end

        it 'releases the lock' do
          expect { lock.release }.to \
            change { lock.client.exists?(lock.id_path) }.to(false).and \
              change { lock.client.exists?(lock.live_path) }.to(false).and \
                change { lock.client.lrange(lock.tokens_path, 0, -1).sort }.to(size.times.map(&:to_s) + [token])
        end
      end

      context 'when lock is not owned' do
        it 'releases lock' do
          expect(lock).to receive(:owned?).with(no_args).and_return(false)
          expect(lock).not_to receive(:_release)

          lock.release
        end
      end
    end

    describe '#fix!' do
      let(:token) { size.to_s }

      before do
        lock.client.set(lock.id_path, SecureRandom.uuid)
        lock.client.set(lock.live_path, SecureRandom.uuid)
        expect(lock).to receive(:change).and_call_original
      end

      it 'fixes the lock' do
        expect { lock.fix! }.to \
          change { lock.client.exists?(lock.id_path) }.to(false).and \
            change { lock.client.exists?(lock.live_path) }.to(false).and \
              change { lock.client.lrange(lock.tokens_path, 0, -1).sort }.to(size.times.map(&:to_s) + [token])
      end
    end
  end
end
