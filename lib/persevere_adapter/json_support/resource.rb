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
          relations = self.model.relationships.keys

          self.model.relationships.each do |nom, relation|
            value = relation.get!(self)
            unless value.nil?
              json_rsrc[nom] = case relation
                # KEEP THIS CASE AT THE TOP BECAUSE IT IS_A OneToMany ARGH
              when DataMapper::Associations::ManyToMany::Relationship then
                [value].flatten.map{ |v| { "$ref" => "../#{v.model.storage_name}/#{v.key.first}" } }
              when DataMapper::Associations::ManyToOne::Relationship then 
                { "$ref" => "../#{value.model.storage_name}/#{value.key.first}" }
              when DataMapper::Associations::OneToMany::Relationship then
                value.map{ |v| { "$ref" => "../#{v.model.storage_name}/#{v.key.first}" } }
              when DataMapper::Associations::OneToOne::Relationship then
                { "$ref" => "../#{value.model.storage_name}/#{value.first.key.first}" }
              end
            end
          end

          attributes(:property).each do |property, value|
            next if value.nil? || (value.is_a?(Array) && value.empty?) || relations.include?(property.name.to_s)

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
