# encoding: UTF-8

require 'prometheus/client/gauge'
require 'examples/metric_example'

describe Prometheus::Client::Gauge do
  let(:gauge) { Prometheus::Client::Gauge.new(:foo, 'foo description') }

  it_behaves_like Prometheus::Client::Metric do
    let(:type) { NilClass }
  end

  describe '#set' do
    it 'sets a metric value' do
      expect do
        gauge.set({}, 42)
      end.to change { gauge.get.get }.from(nil).to(42)
    end

    it 'sets a metric value for a given label set' do
      expect do
        expect do
          gauge.set({ test: 'value' }, 42)
        end.to change { gauge.get(test: 'value').get }.from(nil).to(42)
      end.to_not change { gauge.get.get }
    end

    context 'given an invalid value' do
      it 'raises an ArgumentError' do
        expect do
          gauge.set({}, nil)
        end.to raise_exception(ArgumentError)
      end
    end
  end
end
