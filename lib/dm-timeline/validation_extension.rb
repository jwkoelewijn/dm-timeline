module DataMapper
  module Validation
    alias_method :original_errors, :errors

    def errors
      errors = original_errors || ValidationSet.new(self)
      if errors && self.class.respond_to?(:is_on_timeline)
        inverted_mappings = self.class.property_mappings.invert
        violations = errors.instance_variable_get("@violations")
        new_violations = OrderedHash.new{|h,k| h[k] = []}
        violations.each do |attribute_name, violation|
          if inverted_mappings.has_key?(attribute_name)
            new_violations[inverted_mappings[attribute_name]] = violation
          else
            new_violations[attribute_name] = violation
          end
        end
        errors.instance_variable_set("@violations", new_violations)
      end
      errors
    end
  end
end
