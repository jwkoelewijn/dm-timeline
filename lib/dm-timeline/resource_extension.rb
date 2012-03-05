# Add the at accessor to a collection. This makes it possible
# to find all children objects for the same timeframe
module DataMapper
  module Resource
    attr_accessor :timeline

    def original_values
      if self.class.respond_to?(:is_on_timeline)
        inverted_mappings = self.class.property_mappings.invert
        Hash[original_attributes.map do |key, value|
          key_name = key.name
          key_name = inverted_mappings[key_name] if inverted_mappings.has_key?(key_name)
          [key_name, value]
        end]
      else
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
