require 'spec_helper'

RSpec.describe SmoothQueue do
  let(:processor) do
    Class.new(Object) do
      def process_async(id, _message)
        SmoothQueue.done(id)
      end
    end
  end

  let(:heavy_lifting_worker) { processor.new }
  let(:very_heavy_lifting_worker) { processor.new }

  describe 'integration' do
    before do
      SmoothQueue.configure do |config|
        config.add_queue('heavy_lifting', 5) do |id, message|
          heavy_lifting_worker.process_async(id, message)
        end

        config.add_queue('very_heavy_lifting', 2) do |id, message|
          very_heavy_lifting_worker.process_async(id, message)
        end
      end
    end

    it 'works' do
      expect(heavy_lifting_worker).to receive(:process_async).and_wrap_original do |m, id, message|
        expect(id).to be_a(String)
        expect(id.length).to eq 24
        expect(message).to eq('foo' => 'bar')
        m.call(id, message)
      end
      expect(very_heavy_lifting_worker).to receive(:process_async).and_wrap_original do |m, id, message|
        expect(id).to be_a(String)
        expect(id.length).to eq 24
        expect(message).to eq('bar' => 'baz')
        m.call(id, message)
      end

      Thread.new { SmoothQueue.wait_for_work }
      sleep 0.1
      SmoothQueue.enqueue('heavy_lifting', 'foo' => 'bar')
      SmoothQueue.enqueue('very_heavy_lifting', 'bar' => 'baz')
      sleep 0.1
    end
  end
end
