RSpec.describe Slock::Semaphore do
  let(:opts) { { redis: redis, lifetime: 10, size: size, timeout: lock_timeout } }
  let(:lifetime) { 10 }
  let(:lock_timeout) { 0.4 }
  let(:semaphore) { Slock::Semaphore.new(key, opts) }
  let(:same_semaphore) { Slock::Semaphore.new(key, opts) }
  let(:size) { 3 }
  let(:key) { SecureRandom.uuid }
  let(:token) { rand(0..10).to_s }
  let(:now) { Time.now }

  it '#tokens_path' do
    expect(semaphore.tokens_path).to eq("#{semaphore.key}:tokens")
  end

  it '#init_path' do
    expect(semaphore.init_path).to eq("#{semaphore.key}:init")
  end

  it '#size' do
    expect(semaphore.size).to eq size
  end

  it '#initialize_semaphore' do
    expect { semaphore }.to \
      change { redis.lrange("#{key}:tokens", 0, -1)&.sort }.from([]).to(size.times.map(&:to_s)).and \
      change { redis.get("#{key}:init") }.from(nil).to('1')

    same_semaphore
  end

  describe '#acquire' do
    let(:size) { 2 }
    let(:lock_timeout) { 0.2 }

    before do
      expect(semaphore).to \
        receive(:check_health!).at_least(size).at_least(size).times.and_call_original
    end

    it 'should acquire and release the locks' do
      timeout_reached = nil

      test_lock = proc do |lock|
        expect(lock.live?).to eq true
        expect(lock.owned?).to eq true
        expect(lock.locked?).to eq true
        expect(lock.client.lrange(lock.semaphore.tokens_path, 0, -1)).not_to \
          include(lock.token)
      end

      acquire = proc do
        semaphore.acquire do |l0|
          test_lock.call(l0)

          semaphore.acquire do |l1|
            test_lock.call(l1)

            expect(redis.lrange(semaphore.tokens_path, 0, -1).sort).to eq([])

            semaphore.acquire do |l2|
              raise "Never should be acquired!"
            end
          rescue Slock::Errors::TimeoutError
            timeout_reached = true
          end
        end
      end

      3.times do
        timeout_reached = false
        expect { acquire.call }.to change { timeout_reached }.from(false).to(true)
        expect(redis.lrange(semaphore.tokens_path, 0, -1).sort).to eq(size.times.map(&:to_s))
      end
    end
  end

  describe '#check_health!' do
    context 'when missing some tokens' do
      let(:size) { 4 }
      let(:missing) { [] }

      before do
        semaphore # initalize semaphore
        2.times { missing << redis.lpop(semaphore.tokens_path) }

        expect(missing.count).to eq 2
        missing.each do |n|
          lock = Slock::Semaphore::Lock.new(semaphore, n.to_s).tap(&:own)
          expect(redis.exists?(lock.id_path)).to eq true
        end
      end

      it 'should fix missing tokens' do
        expect { semaphore.check_health! }.to \
          change { redis.llen(semaphore.tokens_path) }.from(size-2).to(size).and \
          change { redis.lrange(semaphore.tokens_path, 0, -1).sort }.to(size.times.map(&:to_s))

        missing.each do |n|
          lock = Slock::Semaphore::Lock.new(semaphore, n.to_s)
          expect(redis.exists?(lock.id_path)).to eq false
        end
      end
    end
  end
end