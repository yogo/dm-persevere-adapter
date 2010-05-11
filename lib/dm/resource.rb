module DataMapper
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
      relations = Array.new

      model.relationships.each_value do |relation|
        # This is where we put the references in the current object
        # But what if they don't have id's (ie they haven't been saved yet?)
        value = relation.get!(self)
        if ! value.nil?
          # puts "#{self.model.name} -> related to : #{value.inspect}"
          if value.is_a?(Array)
            json_rsrc[value.model.storage_name] = value.map{ |v| "../#{v.model.storage_name}/#{v.id}" }
          else
            json_rsrc[value.model.storage_name] = "../#{value.model.storage_name}/#{value.id}"
          end
          relations << value.model.storage_name.to_sym
        else 
          # puts "#{self.model.name} -> related to : #{relation.inspect}"
        end
      end

      # require 'ruby-debug'
      # debugger if self.model == Comment || self.model == BlogPost        

      attributes(:property).each do |property, value|
        if relations.include?(property.name)
          # puts "VALUES: #{value.inspect}"
        end

        next if value.nil? || (value.is_a?(Array) && value.empty?) || relations.include?(property.name)

        json_rsrc[property.field] = case value
        when DateTime then value.new_offset(0).strftime("%Y-%m-%dT%H:%M:%SZ")
        when Date then value.to_s
        when Time then value.strftime("%H:%M:%S")
        when Float then value.to_f
        when BigDecimal then value.to_f
        when Integer then value.to_i
        else # when String, TrueClass, FalseClass then
          # require 'ruby-debug'
          # debugger if self.model == Comment || self.model == BlogPost
          self[property.name]
        end
      end

      json_rsrc
    end
  end
end