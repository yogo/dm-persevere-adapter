module DataMapper
  module Persevere
    module Aggregates
        def aggregate(query)
          records = []
          fields = query.fields
          field_size = fields.size
      
          connect if @persevere.nil?
          resources = Array.new

          query = Persevere.enhance(query)

          json_query, headers = query.to_json_query
          path = "/#{query.model.storage_name}/#{json_query}"
    
          response = @persevere.retrieve(path, headers)

          if response.code == "200"
            results = [response.body]
            results.each do |row_of_results|
             row = query.fields.zip([row_of_results].flatten).map do |field, value|
                if field.respond_to?(:operator)
                  send(field.operator, field.target, value)
                else
                  field.typecast(value)
                end
              end            
              records << (field_size > 1 ? row : row[0])
            end
          end
          records
        end # aggregate method
    
        private
    
        def count(property, value)
          value.to_i
        end
    
        def min(property, value)
          values = JSON.parse("[#{value}]").flatten.compact
          if values.is_a?(Array)
            values.map! { |v| property.typecast(v) }
            return values.sort[0].new_offset(Rational(Time.now.getlocal.gmt_offset/3600, 24)) if property.type == DateTime
            return values.sort[0]
          end
          property.typecast(value)
        end
    
        def max(property, value)
          values = JSON.parse("[#{value}]").flatten.compact
          if values.is_a?(Array)
            values.map! { |v| property.typecast(v) }
            return values.sort[-1].new_offset(Rational(Time.now.getlocal.gmt_offset/3600, 24)) if property.type == DateTime
            return values.sort[-1]
          end
          property.typecast(value)
        end
    
        def avg(property, value)
          values = JSON.parse(value).compact
          result = values.inject(0.0){|sum,i| sum+=i }/values.length
          property.type == Integer ? result.to_f : property.typecast(result)
        end
    
        def sum(property, value)
          property.typecast(value)
        end
    end # module Aggregates
  end # module Persevere

  DataMapper::Persevere::Adapter.send(:include, DataMapper::Persevere::Aggregates)
end # module DataMapper