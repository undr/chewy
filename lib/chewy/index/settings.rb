module Chewy
  class Index

    # Stores ElasticSearch index settings and resolves `analysis`
    # hash. At first, you need to store sone analyzers or other
    # analysis options to the corresponding repository:
    #
    #   Chewy.analyzer :title_analyzer, type: 'custom', filter: %w(lowercase icu_folding title_nysiis)
    #   Chewy.filter :title_nysiis, type: 'phonetic', encoder: 'nysiis', replace: false
    #
    # `title_nysiis` filter here will be expanded automatically when
    # `title_analyzer` analyser will be used in index settings:
    #
    #   class ProductsIndex < Chewy::Index
    #     settings analysis: {
    #       analyzer: [
    #         'title_analyzer',
    #         {one_more_analyzer: {type: 'custom', tokenizer: 'lowercase'}}
    #       ]
    #     }
    #   end
    #
    # Additional analysing options, which wasn't stored in repositories,
    # might be used as well.
    #
    class Settings
      def initialize(params = {})
        @params = params
      end

      def to_hash
        return {} unless @params.present?

        params = @params.deep_dup
        params[:analysis] = resolve_analysis(params[:analysis]) if params[:analysis]

        {settings: params}
      end

    private

      def resolve_analysis(analysis)
        analyzer = resolve(analysis[:analyzer], Chewy.analyzers)

        options = [:tokenizer, :filter, :char_filter].each.with_object({}) do |type, result|
          dependencies = collect_dependencies(type, analyzer)
          resolved = resolve(dependencies.push(analysis[type]), Chewy.send(type.to_s.pluralize))
          result.merge!(type => resolved) if resolved.present?
        end

        options.merge!(analyzer: analyzer) if analyzer.present?
        options
      end

      def collect_dependencies(type, analyzer)
        analyzer.map { |_, options| options[type] }.compact.flatten.uniq
      end

      def resolve(params, repository)
        if params.is_a?(Array)
          params.flatten.reject(&:blank?).each.with_object({}) do |name_or_hash, result|
            options = if name_or_hash.is_a?(Hash)
              name_or_hash
            else
              name_or_hash = name_or_hash.to_sym
              resolved = repository[name_or_hash]
              resolved ? {name_or_hash => resolved} : {}
            end
            result.merge!(options)
          end
        else
          params || {}
        end
      end
    end
  end
end
