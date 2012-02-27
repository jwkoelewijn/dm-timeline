# Add the at accessor to a collection. This makes it possible
# to find all children objects for the same timeframe
module DataMapper
  module Resource
    attr_accessor :timeline

    unless method_defined?(:original_values)
      def original_values
        Hash[original_attributes.map do |key, value|
          [key.name, value]
        end]
      end
    end
  end
end

class Object
  unless method_defined?(:blank?)
    def blank?
      nil? || (respond_to?(:empty?) && empty?)
    end
  end
end
