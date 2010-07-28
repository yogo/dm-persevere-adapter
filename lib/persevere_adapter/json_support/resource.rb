module DataMapper
  module Persevere
    module JSONSupport
      module Resource

        ##
        # Convert a DataMapper Resource to a JSON.
        #
        # @param [Query] query
        #   The DataMapper query object passed in
        #
        # @api semipublic
        def to_json_hash
          json_rsrc = Hash.new
          

          attributes(:property).each do |property, value|
            next if value.nil? #|| (value.is_a?(Array) && value.empty?) || relations.include?(property.name.to_s)

            json_rsrc[property.field] = case value
              when DateTime then value.new_offset(0).strftime("%Y-%m-%dT%H:%M:%SZ")
              when Date then value.to_s
              when Time then value.strftime("%H:%M:%S")
              when Float then value.to_f
              when BigDecimal then value.to_f
              when Integer then value.to_i
              else # when String, TrueClass, FalseClass then
                self[property.name]
            end
          end

          json_rsrc
        end
      end # Resource
    end # JSON
  end # Persevere
end # DataMapper
