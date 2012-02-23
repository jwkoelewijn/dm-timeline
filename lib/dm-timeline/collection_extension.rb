# Add the at accessor to a collection. This makes it possible
# to find all children objects for the same timeframe
module DataMapper
  class Collection
    attr_accessor :timeline

    alias_method :all_without_timeline, :all
    alias_method :first_without_timeline, :first

    def all(query = {})
      if model.respond_to?(:all_without_timeline)
        query_arguments     = query

        if query.respond_to?(:has_key?) && !query.has_key?(model.key)
          conditions          = Timeline::Util.extract_timeline_options(query)
          query_arguments     = query.merge(Timeline::Util.generation_timeline_conditions(conditions))
        end

        all_without_timeline(query_arguments)
      else
        all_without_timeline(query)
      end
    end

    def first(*args)
      if model.respond_to?(:first_without_timeline)
        query            = args.last.respond_to?(:merge) ? args.pop : {}
        conditions       = Timeline::Util.extract_timeline_options(query)
        query_arguments  = Timeline::Util.generation_timeline_conditions(conditions)

        first_without_timeline(*(args << query.merge(query_arguments)))
      else
        first_without_timeline(*args)
      end

    end
  end
end
