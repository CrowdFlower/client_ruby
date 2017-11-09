# encoding: UTF-8

require 'prometheus/client'
require 'prometheus/client/formats/text'
require 'sys-cpu'

module Prometheus
  module Middleware
    # Exporter is a Rack middleware that provides a sample implementation of a
    # Prometheus HTTP exposition endpoint.
    #
    # By default it will export the state of the global registry and expose it
    # under `/metrics`. Use the `:registry` and `:path` options to change the
    # defaults.
    class Exporter
      attr_reader :app, :registry, :path, :cpu_load_gauge

      FORMATS  = [Client::Formats::Text].freeze
      FALLBACK = Client::Formats::Text

      def initialize(app, options = {})
        @app = app
        @registry = options[:registry] || Client.registry
        @path = options[:path] || '/metrics'
        @acceptable = build_dictionary(FORMATS, FALLBACK)
        init_cpu_metrics
      end

      def call(env)
        if env['PATH_INFO'] == @path
          instrument_cpu
          format = negotiate(env, @acceptable)
          format ? respond_with(format) : not_acceptable(FORMATS)
        else
          @app.call(env)
        end
      end

      private

      def init_cpu_metrics
        @cpu_load_gauge = Prometheus::Client::Gauge.new(:cpu_load, 'Current CPU Load')
        @registry.register(@cpu_load_gauge)
      end

      def instrument_cpu
        @cpu_load_gauge.set({ 'load_avg': '1_min', 'pid': Process.pid }, ::Sys::CPU.load_avg[0])
        @cpu_load_gauge.set({ 'load_avg': '5_min', 'pid': Process.pid  }, ::Sys::CPU.load_avg[1])
        @cpu_load_gauge.set({ 'load_avg': '15_min', 'pid': Process.pid  }, ::Sys::CPU.load_avg[2])
      end

      def negotiate(env, formats)
        parse(env.fetch('HTTP_ACCEPT', '*/*')).each do |content_type, _|
          return formats[content_type] if formats.key?(content_type)
        end

        nil
      end

      def parse(header)
        header.split(/\s*,\s*/).map do |type|
          attributes = type.split(/\s*;\s*/)
          quality = extract_quality(attributes)

          [attributes.join('; '), quality]
        end.sort_by(&:last).reverse
      end

      def extract_quality(attributes, default = 1.0)
        quality = default

        attributes.delete_if do |attr|
          quality = attr.split('q=').last.to_f if attr.start_with?('q=')
        end

        quality
      end

      def respond_with(format)
        [
          200,
          { 'Content-Type' => format::CONTENT_TYPE },
          [format.marshal(@registry)],
        ]
      end

      def not_acceptable(formats)
        types = formats.map { |format| format::MEDIA_TYPE }

        [
          406,
          { 'Content-Type' => 'text/plain' },
          ["Supported media types: #{types.join(', ')}"],
        ]
      end

      def build_dictionary(formats, fallback)
        formats.each_with_object('*/*' => fallback) do |format, memo|
          memo[format::CONTENT_TYPE] = format
          memo[format::MEDIA_TYPE] = format
        end
      end
    end
  end
end
