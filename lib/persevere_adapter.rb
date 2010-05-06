require 'rubygems'
require 'dm-core'
require 'dm-aggregates'
require 'dm-types'
require 'extlib'
# require 'json'
require 'bigdecimal'

require 'model_json_support'
require 'persevere'

require 'types/property'
require 'types/json_reference'
require 'types/json_reference_collection'

class BigDecimal
  alias to_json_old to_json
  
  def to_json
    to_s
  end
end

module DataMapper
  module Aggregates
    module PersevereAdapter
      def aggregate(query)
        records = []
        fields = query.fields
        field_size = fields.size
        
        connect if @persevere.nil?
        resources = Array.new
        json_query = make_json_query(query)
        path = "/#{query.model.storage_name}/#{json_query}"

        response = @persevere.retrieve(path)

        if response.code == "200"
          # results = JSON.parse(response.body)
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
    end # module PersevereAdapter
  end # module Aggregates

  module Migrations
    module PersevereAdapter
      # @api private
      def self.included(base)  
        DataMapper.extend(Migrations::SingletonMethods)

        [ :Repository, :Model ].each do |name|
          DataMapper.const_get(name).send(:include, Migrations.const_get(name))
        end
      end

      # Returns whether the storage_name exists.
      #
      # @param [String] storage_name
      #   a String defining the name of a storage, for example a table name.
      #
      # @return [Boolean]
      #   true if the storage exists
      #
      # @api semipublic
      def storage_exists?(storage_name)
        class_names = JSON.parse(@persevere.retrieve('/Class/[=id]').body)
        return true if class_names.include?("Class/"+storage_name)
        false
      end

      ##
      # Creates the persevere schema from the model.
      #
      # @param [DataMapper::Model] model
      #   The model that corresponds to the storage schema that needs to be created.
      #
      # @api semipublic
      def create_model_storage(model)
        name       = self.name
        properties = model.properties_with_subclasses(name)
        
        
        return false if storage_exists?(model.storage_name(name))
        return false if properties.empty?

        # Make sure storage for referenced objects exists
        model.relationships.each_pair do |n, r|
          if ! storage_exists?(r.child_model.storage_name)
            put_schema({'id' => r.child_model.storage_name, 'properties' => {}})
          end
        end
        schema_hash = model.to_json_schema_compatible_hash()
        
        return true unless put_schema(schema_hash) == false
        false
      end

      ##
      # Updates the persevere schema from the model.
      #
      # @param [DataMapper::Model] model
      #   The model that corresponds to the storage schema that needs to be updated.
      #
      # @api semipublic
      def upgrade_model_storage(model)
        name       = self.name
        properties = model.properties_with_subclasses(name)

        if success = create_model_storage(model)
          return properties
        end
        
        new_schema_hash = model.to_json_schema_compatible_hash()
        current_schema_hash = get_schema(new_schema_hash['id'])[0]
        # Diff of what is there and what will be added.

        new_properties = properties.map do |property|
          prop_name = property.name.to_s
          prop_type = property.type
          next if prop_name == 'id' || 
                  (current_schema_hash['properties'].has_key?(prop_name) && 
                  new_schema_hash['properties'][prop_name]['type'] == current_schema_hash['properties'][prop_name]['type'] )
          property
        end.compact
        
        return new_properties unless update_schema(new_schema_hash) == false
        return nil
      end

      ##
      # Destroys the persevere schema from the model.
      #
      # @param [DataMapper::Model] model
      #   The model that corresponds to the storage schema that needs to be destroyed.
      #
      # @api semipublic
      def destroy_model_storage(model)
        return true unless storage_exists?(model.storage_name(name))
        schema_hash = model.to_json_schema_compatible_hash()
        return true unless delete_schema(schema_hash) == false
        false
      end

    end # module PersevereAdapter
  end # module Migrations

  module Adapters
    class PersevereAdapter < AbstractAdapter
      extend Chainable
      extend Deprecate
      
      RESERVED_CLASSNAMES = ['User','Transaction','Capability','File','Class', 'Object', 'Versioned']

      include Migrations::PersevereAdapter
      
      # Default types for all data object based adapters.
      #
      # @return [Hash] default types for data objects adapters.
      #
      # @api private
      chainable do
        def type_map
          length    = Property::DEFAULT_LENGTH
          precision = Property::DEFAULT_PRECISION
          scale     = Property::DEFAULT_SCALE_BIGDECIMAL

          @type_map ||= {
            Types::Serial => { :primitive => 'integer' },
            Types::Boolean => { :primitive => 'boolean' },
            Integer     => { :primitive => 'integer'},
            String      => { :primitive => 'string'},
            Class       => { :primitive => 'string'},
            BigDecimal  => { :primitive => 'number'},
            Float       => { :primitive => 'number'},
            DateTime    => { :primitive => 'string', :format => 'date-time'},
            Date        => { :primitive => 'string', :format => 'date'},
            Time        => { :primitive => 'string', :format => 'time'},
            TrueClass   => { :primitive => 'boolean'},
            Types::Text => { :primitive => 'string'},
            DataMapper::Types::Object => { :primitive => 'string'},
            DataMapper::Types::URI   => { :primitive => 'string', :format => 'uri'}
          }.freeze
        end
      end
      
      # This should go away when we have more methods exposed to retrieve versioned data (and schemas)
      attr_accessor :persevere
      
      ##
      # Used by DataMapper to put records into a data-store: "INSERT"
      # in SQL-speak.  It takes an array of the resources (model
      # instances) to be saved. Resources each have a key that can be
      # used to quickly look them up later without searching, if the
      # adapter supports it.
      #
      # @param [Array<DataMapper::Resource>] resources
      #   The set of resources (model instances)
      #
      # @return [Integer]
      #   The number of records that were actually saved into the
      #   data-store
      #
      # @api semipublic
      def create(resources)
        connect if @persevere.nil?
        created = 0
        resources.each do |resource|
          puts "----> Processing a single resource"
          serial = resource.model.serial(self.name)
          path = "/#{resource.model.storage_name}/"
          payload = make_json_compatible_hash(resource)
          payload.delete(:id)
          response = @persevere.create(path, payload)

          # Check the response, this needs to be more robust and raise
          # exceptions when there's a problem
          if response.code == "201"# good:
            rsrc_hash = JSON.parse(response.body)
            # Typecast attributes, DM expects them properly cast
            resource.model.properties.each do |prop|
              value = rsrc_hash[prop.field.to_s]
              rsrc_hash[prop.field.to_s] = prop.typecast(value) unless value.nil?
              # Shift date/time objects to the correct timezone because persevere is UTC
              case prop 
                when DateTime then rsrc_hash[prop.field.to_s] = value.new_offset(Rational(Time.now.getlocal.gmt_offset/3600, 24))
                when Time then rsrc_hash[prop.field.to_s] = value.getlocal
              end
            end

            puts "Result:"
            pp rsrc_hash
            
            serial.set!(resource, rsrc_hash["id"]) unless serial.nil?

            created += 1
          else
            puts "Failed to create object with "
            pp payload
            return false
          end
        end

        # Return the number of resources created in persevere.
        return created
      end

      ##
      # Used by DataMapper to update the attributes on existing
      # records in a data-store: "UPDATE" in SQL-speak. It takes a
      # hash of the attributes to update with, as well as a query
      # object that specifies which resources should be updated.
      #
      # @param [Hash] attributes
      #   A set of key-value pairs of the attributes to update the
      #   resources with.
      # @param [DataMapper::Query] query
      #   The query that should be used to find the resource(s) to
      #   update.
      #
      # @return [Integer]
      #   the number of records that were successfully updated
      #
      # @api semipublic
      def update(attributes, query)
        connect if @persevere.nil?
        updated = 0

        if ! query.is_a?(DataMapper::Query)
          resources = [query].flatten
        else
          resources = read_many(query)
        end

        resources.each do |resource|
          tblname = resource.model.storage_name
          path = "/#{tblname}/#{resource.key.first}"

          payload = make_json_compatible_hash(resource)

          result = @persevere.update(path, payload)

          if result.code == "200"
            updated += 1
          else
            return false
          end
        end
        return updated
      end

      ##
      # Look up a single record from the data-store. "SELECT ... LIMIT
      # 1" in SQL.  Used by Model#get to find a record by its
      # identifier(s), and Model#first to find a single record by some
      # search query.
      #
      # @param [DataMapper::Query] query
      #   The query to be used to locate the resource.
      #
      # @return [DataMapper::Resource]
      #   A Resource object representing the record that was found, or
      #   nil for no matching records.
      #
      # @api semipublic

      def read_one(query)
        results = read_many(query)
        results[0,1]
      end

      ##
      # Looks up a collection of records from the data-store: "SELECT"
      # in SQL.  Used by Model#all to search for a set of records;
      # that set is in a DataMapper::Collection object.
      #
      # @param [DataMapper::Query] query
      #   The query to be used to seach for the resources
      #
      # @return [DataMapper::Collection]
      #   A collection of all the resources found by the query.
      #
      # @api semipublic
      def read_many(query)
        connect if @persevere.nil?

        resources = Array.new
        json_query, headers = make_json_query(query)
        
        tblname = query.model.storage_name
        path = "/#{tblname}/#{json_query}"
        # puts path
        response = @persevere.retrieve(path, headers)

        if response.code.match(/20?/)
          results = JSON.parse(response.body)
          results.each do |rsrc_hash|
            # Typecast attributes, DM expects them properly cast
            query.fields.each do |prop|
              value = rsrc_hash[prop.field.to_s]
              if prop.field == 'id'
                rsrc_hash[prop.field.to_s]  = prop.typecast(value.to_s.match(/(#{tblname})?\/?([a-zA-Z0-9_-]+$)/)[2])
              else
                rsrc_hash[prop.field.to_s] = prop.typecast(value) unless value.nil?
              end
              # Shift date/time objects to the correct timezone because persevere is UTC
              case prop 
                when DateTime then rsrc_hash[prop.field.to_s] = value.new_offset(Rational(Time.now.getlocal.gmt_offset/3600, 24))
                when Time then rsrc_hash[prop.field.to_s] = value.getlocal
              end
            end
          end
          resources = query.model.load(results, query)
        end
        # We could almost elimate this if regexp was working in persevere.

        # This won't work if the RegExp is nested more then 1 layer deep.
        if query.conditions.class == DataMapper::Query::Conditions::AndOperation
          regexp_conds = query.conditions.operands.select{ |obj| obj.is_a?(DataMapper::Query::Conditions::RegexpComparison) || 
             (obj.is_a?(DataMapper::Query::Conditions::NotOperation) && obj.operand.is_a?(DataMapper::Query::Conditions::RegexpComparison))}
          regexp_conds.each{|cond| resources = resources.select{|resource| cond.matches?(resource)} }
         
        end
        # query.match_records(resources)
        resources
      end

      alias :read :read_many

      ##
      # Destroys all the records matching the given query. "DELETE" in SQL.
      #
      # @param [DataMapper::Query] query
      #   The query used to locate the resources to be deleted.
      #
      # @return [Integer]
      #   The number of records that were deleted.
      #
      # @api semipublic
      def delete(query)
        connect if @persevere.nil?

        deleted = 0

        if ! query.is_a?(DataMapper::Query)
          resources = [query].flatten
        else
          resources = read_many(query)
        end

        resources.each do |resource|
          tblname = resource.model.storage_name
          path = "/#{tblname}/#{resource.id}"

          result = @persevere.delete(path)

          if result.code == "204" # ok
            deleted += 1
          end
        end
        return deleted
      end

      ##
      #
      # Other methods for the Yogo Data Management Toolkit
      #
      ##
      def get_schema(name = nil, project = nil)
        path = nil
        single = false
        if name.nil? & project.nil?
          path = "/Class/"
        elsif project.nil?
          path = "/Class/#{name}"
        elsif name.nil?
          path = "/Class/#{project}/"
        else
          path = "/Class/#{project}/#{name}"
        end
        result = @persevere.retrieve(path)
        if result.code == "200"
          schemas = [JSON.parse(result.body)].flatten.select{ |schema| not RESERVED_CLASSNAMES.include?(schema['id']) }
          schemas.each do |schema|
            schema['properties']['id'] = { 'type' => "serial", 'index' => true }
          end
          return name.nil? ? schemas : schemas[0..0]
        else
          return false
        end
      end

      def put_schema(schema_hash, project = nil)
        path = "/Class/"
        if ! project.nil?
          if schema_hash.has_key?("id")
            if ! schema_hash['id'].index(project)
              schema_hash['id'] = "#{project}/#{schema_hash['id']}"
            end
          else
            puts "You need an id key/value in the hash"
          end
        end
        schema_hash['properties'].delete('id') if schema_hash['properties'].has_key?('id')
        schema_hash['extends'] = { "$ref" => "/Class/Versioned" } if @options[:versioned]
        result = @persevere.create(path, schema_hash)
        if result.code == '201'
          return JSON.parse(result.body)
        else
          return false
        end
      end

      def update_schema(schema_hash, project = nil)
        id = schema_hash['id']
        payload = schema_hash.reject{|key,value| key.to_sym.eql?(:id) }
        payload['properties'].delete('id') if payload['properties'].has_key?('id')

        if project.nil?
          path = "/Class/#{id}"
        else
          path =  "/Class/#{project}/#{id}"
        end

        result = @persevere.update(path, payload)

        if result.code == '200'
          return result.body
        else
          return false
        end
      end

      def delete_schema(schema_hash, project = nil)
        if ! project.nil?
          if schema_hash.has_key?("id")
            if ! schema_hash['id'].index(project)
              schema_hash['id'] = "#{project}/#{schema_hash['id']}"
            end
          else
            puts "You need an id key/value in the hash"
          end
        end
        path = "/Class/#{schema_hash['id']}"
        result = @persevere.delete(path)

        if result.code == "204"
          return true
        else
          return false
        end
      end

      private

      ##
      # Make a new instance of the adapter. The @model_records ivar is
      # the 'data-store' for this adapter. It is not shared amongst
      # multiple incarnations of this adapter, eg
      # DataMapper.setup(:default, :adapter => :in_memory);
      # DataMapper.setup(:alternate, :adapter => :in_memory) do not
      # share the data-store between them.
      #
      # @param [String, Symbol] name
      #   The name of the DataMapper::Repository using this adapter.
      # @param [String, Hash] uri_or_options
      #   The connection uri string, or a hash of options to set up
      #   the adapter
      #
      # @api semipublic

      def initialize(name, uri_or_options)
        super

        if uri_or_options.class
          @identity_maps = {}
        end

        @options = Hash.new

        uri_or_options.each do |k,v|
          @options[k.to_sym] = v
        end
        
        @options[:scheme] = @options[:adapter]
        @options.delete(:scheme)

        @resource_naming_convention = NamingConventions::Resource::Underscored
        @identity_maps = {}
        @classes = []
        @persevere = nil
        @prepped = false

        connect
      end
      
      def connect
        if ! @prepped
          uri = URI::HTTP.build(@options).to_s
          @persevere = Persevere.new(uri)
          prep_persvr unless @prepped
        end
      end

      def prep_persvr
        # Because this is an AbstractAdapter and not a
        # DataObjectAdapter, we can't assume there are any schemas
        # present, so we retrieve the ones that exist and keep them up
        # to date
        result = @persevere.retrieve('/Class[=id]')
        if result.code == "200"
          hresult = JSON.parse(result.body)
          hresult.each do |cname|
            junk,name = cname.split("/")
            @classes << name
          end
          @prepped = true
        else
          puts "Error retrieving existing tables: ", result
        end
        
        #
        # If the user specified a versioned datastore load the versioning REST code
        # 
        if ! @classes.include?("Versioned") && @options[:versioned]
          versioned_class = <<-EOF
          {
              id: "Versioned",
              prototype: {
                  getVersionMethod: function() {
                      return java.lang.Class.forName("org.persvr.data.Persistable").getMethod("getVersion");
                  },
                  isCurrentVersion: function() {
                      return this.getVersionMethod().invoke(this).isCurrent();
                  },
                  getVersionNumber: function() {
                      return this.getVersionMethod().invoke(this).getVersionNumber();
                  },
                  getPrevious: function() {
                    var prev = this.getVersionMethod().invoke(this).getPreviousVersion();
                    return prev;
                  },
                  getAllPrevious: function() {

                      var current = this;
                      var prev = current && current.getPrevious();

                      var versions = []
                      while(current && prev) {
                        versions.push(prev);
                        current = prev;
                        prev = current.getPrevious();
                      }

                      return versions;
                  },
                  "representation:application/json+versioned": {
                      quality: 0.2,
                      output: function(object) {
                          var previous = object.getAllPrevious();
                          response.setContentType("application/json+versioned");
                          response.getOutputStream().print(JSON.stringify({
                              version: object.getVersionNumber(),
                              current: object,
                              versions: previous
                          }));
                      }
                  }
              }
          }
          EOF
          begin
            response = @persevere.persevere.send_request('POST', URI.encode('/Class/'), versioned_class, { 'Content-Type' => 'application/javascript' } )
          rescue Timeout::Error, Errno::EINVAL, Errno::ECONNRESET, EOFError,
                Net::HTTPBadResponse, Net::HTTPHeaderSyntaxError, Net::ProtocolError => e
            puts "Persevere Create Failed: #{e}, Trying again."
          end
        end
      end
      
      ##
      # Convert a DataMapper Resource to a JSON.
      #
      # @param [Query] query
      #   The DataMapper query object passed in
      #
      # @api semipublic
      def make_json_compatible_hash(resource)
        model = resource.model
        attributes = resource.dirty_attributes
        json_rsrc = Hash.new

        model.relationships.each_value do |relation|
          # This is where we put the references in the current object
          # But what if they don't have id's (ie they haven't been saved yet?)
          values = relation.get!(resource)
          puts "#{resource.model.name} -> related to : #{values.inspect}"
        end

        model.properties(name).each do |property|
          next unless attributes.key?(property) || attributes[property].nil? || (attributes[property].is_a?(Array) && attributes[property].empty?)
          value = attributes[property]

          json_rsrc[property.field] = case value
            when DateTime then value.new_offset(0).strftime("%Y-%m-%dT%H:%M:%SZ")
            when Date then value.to_s
            when Time then value.strftime("%H:%M:%S")
            when Float then value.to_f
            when BigDecimal then value.to_f
            when Integer then value.to_i
            else resource[property.name]
          end
        end

        puts "JSON RSRC: "
        pp json_rsrc
        puts "-----"

        json_rsrc
      end

      ##
      # Convert a DataMapper Query to a JSON Query.
      #
      # @param [Query] query
      #   The DataMapper query object passed in
      #
      # @api semipublic
      def make_json_query(query)
        def process_in(value, candidate_set)
          result_string = Array.new
          candidate_set.to_a.each do |candidate|
            result_string << "#{value}=#{candidate}"
          end
          if result_string.length > 0
            "(#{result_string.join("|")})"
          else
            "#{value}=''"
          end
        end

        def munge_condition(condition)
          cond = condition.loaded_value

          cond = "\"#{cond}\"" if cond.is_a?(String)
          cond = "date(%10.f)" % (Time.parse(cond.to_s).to_f * 1000) if cond.is_a?(DateTime)
          cond = 'undefined' if cond.nil?
          return cond
        end

        def process_condition(condition)
          case condition
            # Persevere 1.0 regular expressions are disable for security so we pass them back for DataMapper query filtering
            # without regular expressions, the like operator is inordinately challenging hence we pass it back
            # when :regexp then "RegExp(\"#{condition.value.source}\").test(#{condition.subject.name})"
            when DataMapper::Query::Conditions::RegexpComparison then []
            when DataMapper::Query::Conditions::LikeComparison then "#{condition.subject.field}='#{condition.loaded_value.gsub('%', '*')}'"
            when DataMapper::Query::Conditions::AndOperation then 
              inside = condition.operands.map { |op| process_condition(op) }.flatten
              inside.empty? ? []  : "(#{inside.join("&")})"
            when DataMapper::Query::Conditions::OrOperation then "(#{condition.operands.map { |op| process_condition(op) }.join("|")})"
            when DataMapper::Query::Conditions::NotOperation then 
              inside = process_condition(condition.operand) 
              inside.empty? ? [] : "!(%s)" % inside
            when DataMapper::Query::Conditions::InclusionComparison then process_in(condition.subject.name, condition.value)
            when DataMapper::Query::Conditions::EqualToComparison then
              "#{condition.subject.field}=#{munge_condition(condition)}"
            when DataMapper::Query::Conditions::GreaterThanComparison then
              "#{condition.subject.field}>#{munge_condition(condition)}"
            when DataMapper::Query::Conditions::LessThanComparison then
              "#{condition.subject.field}<#{munge_condition(condition)}"
            when DataMapper::Query::Conditions::GreaterThanOrEqualToComparison then
              "#{condition.subject.field}>=#{munge_condition(condition)}"
            when DataMapper::Query::Conditions::LessThanOrEqualToComparison then
              "#{condition.subject.field}<=#{munge_condition(condition)}"
            when DataMapper::Query::Conditions::NullOperation then []
            when Array then
               old_statement, bind_values = condition
               statement = old_statement.dup
               bind_values.each{ |bind_value| statement.sub!('?', bind_value.to_s) }
               statement.gsub(' ', '')
            else condition.to_s.gsub(' ', '')
          end
        end

        json_query = ""
        query_terms = Array.new
        order_operations = Array.new
        field_ops = Array.new
        fields = Array.new
        headers = Hash.new

        query_terms << process_condition(query.conditions) 

        if query_terms.flatten.length != 0
          json_query += "[?#{query_terms.join("][?")}]"
        end
        
        query.fields.each do |field|
          if field.respond_to?(:operator)
          field_ops << case field.operator
            when :count then
              if field.target.is_a?(DataMapper::Property)
                "[?#{field.target.field}!=undefined].length"
              else # field.target is all.
                ".length"
              end
            when :min
              if field.target.type == DateTime || field.target.type == Time || field.target.type == Date
                "[=#{field.target.field}]"
              else
                ".min(?#{field.target.field})"
              end
            when :max
              if field.target.type == DateTime || field.target.type == Time || field.target.type == Date
                "[=#{field.target.field}]"
              else
                ".max(?#{field.target.field})"
              end
            when :sum
              ".sum(?#{field.target.field})"
            when :avg
              "[=#{field.target.field}]"
          end
        else
          fields << "'#{field.field}':#{field.field}"
        end
        end
           
        json_query += field_ops.join("")
        
        if query.order && query.order.any?
          query.order.map do |direction|
            order_operations << case direction.operator
              when :asc then "[\/#{direction.target.field}]"
              when :desc then "[\\#{direction.target.field}]"
            end
          end
        end

        json_query += order_operations.join("")

        json_query += "[={" + fields.join(',') + "}]" unless fields.empty?

        offset = query.offset.to_i
        limit = query.limit.nil? ? nil : query.limit.to_i + offset - 1
        
        if offset != 0 || !limit.nil?
          headers.merge!({"Range", "items=#{offset}-#{limit}"})
        end
#        puts "#{query.inspect}"
        # puts json_query, headers
        return json_query, headers
      end
    end # class PersevereAdapter
    const_added(:PersevereAdapter)
  end # module Adapters
end # module DataMapper