# Add the at accessor to a collection. This makes it possible
# to find all children objects for the same timeframe
module DataMapper
  class Collection
    attr_accessor :timeline

    def all(query = {})
      if model.respond_to?(:all_without_timeline)
        query_arguments     = query

        if query.respond_to?(:has_key?) && !query.has_key?(model.key)
          conditions          = Timeline::Util.extract_timeline_options(query)
          query_arguments     = query.merge(Timeline::Util.generation_timeline_conditions(conditions))
        end

        super(query_arguments)
      else
        super
      end
    end

    def first(*args)
      if model.respond_to?(:first_without_timeline)
        query            = args.last.respond_to?(:merge) ? args.pop : {}
        conditions       = Timeline::Util.extract_timeline_options(query)
        query_arguments  = Timeline::Util.generation_timeline_conditions(conditions)

        super(*(args << query.merge(query_arguments)))
      else
        super(*args)
      end

    end
  end
end
