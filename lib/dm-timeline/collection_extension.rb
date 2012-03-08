# Add the at accessor to a collection. This makes it possible
# to find all children objects for the same timeframe
module DataMapper
  class Collection
    attr_accessor :timeline

    alias_method :first_without_timeline, :first
    alias_method :count_without_timeline, :count

    def all(query = {})
      super
    end

    def count(*args)
      args = extract_query_arguments(*args)
      count_without_timeline(*args)
    end

    def first(*args)
      args = extract_query_arguments(*args)
      first_without_timeline(*args)
    end

    def extract_query_arguments(*args)
      if model.respond_to?(:is_on_timeline)
        query            = args.last.respond_to?(:merge) ? args.pop : {}
        conditions       = Timeline::Util.extract_timeline_options(query)
        query_arguments  = Timeline::Util.generation_timeline_conditions(conditions)

        query_arguments = query.merge(query_arguments)
        query_arguments = model.send(:replace_mapped_attributes, query_arguments)
        args << query_arguments
      end
      args
    end
  end
end
