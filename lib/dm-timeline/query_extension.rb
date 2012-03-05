# Update the #assert_valid_order method to replace mapped properties
module DataMapper
  class Query
    alias_method :original_assert_valid_order, :assert_valid_order

    def assert_valid_order(order, fields)
      new_order = order
      if model.respond_to?(:is_on_timeline) && order
        order.each_with_index do |order_operator, index|
          if order_operator.is_a?(Symbol) || order_operator.is_a?(String)
            new_order[index] = model.property_mappings[order_operator] if model.property_mappings.has_key?(order_operator)
          else
            operator = order_operator.instance_variable_get("@target")
            order_operator.instance_variable_set("@target", model.property_mappings[operator]) if model.property_mappings.has_key?(operator)
          end
        end
      end
      original_assert_valid_order(new_order, fields)
    end
  end
end
