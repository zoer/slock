RSpec.describe Slock::Semaphore::Health do
  let(:opts) { { redis: redis, lifetime: 10, size: size, timeout: lock_timeout } }
  let(:lifetime) { 10 }
  let(:lock_timeout) { 0.4 }
  let(:semaphore) { Slock::Semaphore.new(key, opts) }
  let(:tokens_path) { semaphore.tokens_path }
  let(:health) { described_class.new(semaphore) }
  let(:token) { rand(0..10).to_s }

  let(:size) { 3 }
  let(:key) { SecureRandom.uuid }

  describe '#check' do
    let(:size) { 4 }
    let(:missing) { [] }

    context 'when tokens pool is not changed during the fix' do
      before do
        semaphore # initialize semaphore
        missing << redis.lpop(tokens_path)
        expect(missing.count).to eq 1
        allow_any_instance_of(Slock::Semaphore::Lock).to receive(:live?).and_return(false)
      end

      it 'missing keys must be restored' do
        expect { health.check }.to \
          change { redis.lrange(tokens_path, 0, -1).sort }.to(size.times.map(&:to_s))
      end
    end

    context 'when tokens pool is changed during the fix' do
      let(:tokens) { size.times.map(&:to_s) }

      before do
        semaphore # initialize semaphore
        missing << redis.lpop(tokens_path)
        expect(missing.count).to eq 1
      end

      it 'transaction must be interupted' do
        # add a hook to change tokens pool during Redis transaction
        allow_any_instance_of(Slock::Semaphore::Lock).to \
          receive(:live?) {
            redis.lpush(tokens_path, size)
            false
          }

        # expecting that missing key is not restored because of cancelled transaction
        expect { health.check }.to change { redis.lrange(tokens_path, 0, -1).sort }
          .from(tokens - missing).to(tokens - missing + [size.to_s])
      end
    end
  end
end
