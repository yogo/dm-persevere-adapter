module DataMapper
  module Persevere
    class Adapter < DataMapper::Adapters::AbstractAdapter
      extend Chainable
      extend Deprecate
      
      RESERVED_CLASSNAMES = ['User','Transaction','Capability','File','Class', 'Object', 'Versioned']

      
      # Default types for all data object based adapters.
      #
      # @return [Hash] default types for data objects adapters.
      #
      # @api private
      chainable do
        def type_map
          length    = DataMapper::Property::String::DEFAULT_LENGTH
          precision = DataMapper::Property::Numeric::DEFAULT_PRECISION
          scale     = DataMapper::Property::Decimal::DEFAULT_SCALE

          @type_map ||= {
            Property::Serial             => { :primitive => 'integer' },
            Property::Boolean            => { :primitive => 'boolean' },
            Integer                   => { :primitive => 'integer'},
            String                    => { :primitive => 'string'},
            Class                     => { :primitive => 'string'},
            BigDecimal                => { :primitive => 'number'},
            Float                     => { :primitive => 'number'},
            DateTime                  => { :primitive => 'string', :format => 'date-time'},
            Date                      => { :primitive => 'string', :format => 'date'},
            Time                      => { :primitive => 'string', :format => 'time'},
            TrueClass                 => { :primitive => 'boolean'},
            Property::Text               => { :primitive => 'string'},
            DataMapper::Property::Object => { :primitive => 'string'},
            DataMapper::Property::URI    => { :primitive => 'string', :format => 'uri'}
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
        
        check_schemas
        
        resources.each do |resource|          
          serial = resource.model.serial(self.name)
          path = "/#{resource.model.storage_name}/"
          # Invoke to_json_hash with a boolean to indicate this is a create
          # We might want to make this a post-to_json_hash cleanup instead
          payload = resource.to_json_hash.delete_if{|key,value| value.nil? }
          DataMapper.logger.debug("(Create) PATH/PAYLOAD: #{path} #{payload.inspect}")
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
            
            serial.set!(resource, rsrc_hash["id"]) unless serial.nil?

            created += 1
          else
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
        
        check_schemas
        
        if ! query.is_a?(DataMapper::Query)
          resources = [query].flatten
        else
          resources = read_many(query)
        end

        resources.each do |resource|
          tblname = resource.model.storage_name
          path = "/#{tblname}/#{resource.key.first}"
          payload = resource.to_json_hash
          DataMapper.logger.debug("(Update) PATH/PAYLOAD: #{path} #{payload.inspect}")
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
      def read(query)
        connect if @persevere.nil?
        
        resources = Array.new
        tblname = query.model.storage_name
        
        json_query, headers = query.to_json_query
        
        path = "/#{tblname}/#{json_query}"
        DataMapper.logger.debug("--> PATH/QUERY/HEADERS: #{path} #{headers.inspect}")
        
        response = @persevere.retrieve(path, headers)
        
        if response.code.match(/20?/)
          results = JSON.parse(response.body)
          results.each do |rsrc_hash|
            # Typecast attributes, DM expects them properly cast
            query.fields.each do |prop|
              object_reference = false
              pname = prop.field.to_s
              if pname[-3,3] == "_id"
                pname = pname[0..-4] 
                object_reference = true
              end
              value = rsrc_hash[pname]
              # Dereference references
              unless value.nil?
                if value.is_a?(Hash)
                  if value.has_key?("$ref")
                    value = value["$ref"].split("/")[-1]
                  end
                elsif value.is_a?(Array)
                  value = value.map do |v| 
                    if v.has_key?("$ref")
                      v = v["$ref"].split("/")[-1]
                    else
                      v
                    end
                  end
                end
                if prop.field == 'id'
                  rsrc_hash[pname]  = prop.typecast(value.to_s.match(/(#{tblname})?\/?([a-zA-Z0-9_-]+$)/)[2])
                else
                  rsrc_hash[pname] = prop.typecast(value)
                end
              end
              # Shift date/time objects to the correct timezone because persevere is UTC
              case prop 
                when DateTime then rsrc_hash[pname] = value.new_offset(Rational(Time.now.getlocal.gmt_offset/3600, 24))
                when Time then rsrc_hash[pname] = value.getlocal
              end
            end
          end
          resources = query.model.load(results, query)
        end
        # We could almost elimate this if regexp was working in persevere.

        # This won't work if the RegExp is nested more then 1 layer deep.
        if query.conditions.class == DataMapper::Query::Conditions::AndOperation
          regexp_conds = query.conditions.operands.select do |obj| 
            obj.is_a?(DataMapper::Query::Conditions::RegexpComparison) || 
            ( obj.is_a?(DataMapper::Query::Conditions::NotOperation) && obj.operand.is_a?(DataMapper::Query::Conditions::RegexpComparison) )
          end
          regexp_conds.each{|cond| resources = resources.select{|resource| cond.matches?(resource)} }
         
        end

        # query.match_records(resources)
        resources
      end

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

          DataMapper.logger.debug("(Delete) PATH/QUERY: #{path}")

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
            if schema.has_key?('properties')
              schema['properties']['id'] = { 'type' => "serial", 'index' => true }
            end
          end

          return name.nil? ? schemas : schemas[0..0]
        else
          return false
        end
      end

      ##
      # 
      def put_schema(schema_hash, project = nil)
        path = "/Class/"
        if ! project.nil?
          if schema_hash.has_key?("id")
            if ! schema_hash['id'].index(project)
              schema_hash['id'] = "#{project}/#{schema_hash['id']}"
            end
          else
            DataMapper.logger.error("You need an id key/value in the hash")
          end
        end
        
        scrub_schema(schema_hash['properties'])
        properties = schema_hash.delete('properties')
        schema_hash['extends'] = { "$ref" => "/Class/Versioned" } if @options[:versioned]
        schema_hash.delete_if{|key,value| value.nil? }
        result = @persevere.create(path, schema_hash)
        if result.code == '201'
          # return JSON.parse(result.body)
          schema_hash['properties'] = properties
          return update_schema(schema_hash)
        else
          return false
        end
      end

      ##
      # 
      def update_schema(schema_hash, project = nil)
        id = schema_hash['id']
        payload = schema_hash.reject{|key,value| key.to_sym.eql?(:id) }
        scrub_schema(payload['properties'])
        payload['extends'] = { "$ref" => "/Class/Versioned" } if @options[:versioned]

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

      ##
      # 
      def delete_schema(schema_hash, project = nil)
        if ! project.nil?
          if schema_hash.has_key?("id")
            if ! schema_hash['id'].index(project)
              schema_hash['id'] = "#{project}/#{schema_hash['id']}"
            end
          else
            DataMapper.logger.error("You need an id key/value in the hash")
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
        
        # @resource_naming_convention = NamingConventions::Resource::Underscored
        @resource_naming_convention = lambda do |value|
          # value.split('::').map{ |val| Extlib::Inflection.underscore(val) }.join('__')
          Extlib::Inflection.underscore(value).gsub('/', '__')
        end
        
        @identity_maps = {}
        @persevere = nil
        @prepped = false
        @schema_backups = Array.new
        @last_backup = nil
        
        connect
      end
      
      private
      
      ##
      # 
      def connect
        if ! @prepped
          uri = URI::HTTP.build(@options).to_s
          @persevere = Persevere.new(uri)
          prep_persvr unless @prepped
        end
      end

      def scrub_data(json_hash)
        items = [DataMapper::Model.descendants.map{|c| "#{c.name.downcase}_id"}].flatten
        items.each { |item| json_hash.delete(item) if json_hash.has_key?(item) }
        json_hash.reject! { |k,v| v.nil? }
        json_hash
      end
      
      ##
      # 
      def scrub_schema(json_hash)
        items = [DataMapper::Model.descendants.map{|c| "#{c.name.downcase}_id"}, 'id'].flatten
        items.each { |item| json_hash.delete(item) if json_hash.has_key?(item) }
        json_hash
      end

      def check_schemas
        schemas = @persevere.retrieve("/Class").body
        md5 = Digest::MD5.hexdigest(schemas)

        if ! @last_backup.nil?
          if @last_backup[:hash] != md5
            DataMapper.logger.debug("Schemas changed, do you know why? (#{md5} :: #{@last_backup[:hash]})")
            @schema_backups.each do |sb| 
              if sb[:hash] == md5 
                DataMapper.logger.debug("Schemas reverted to #{sb.inspect}")
              end
            end
          end
        end
      end
      
      def save_schemas
        schemas = @persevere.retrieve("/Class").body
        md5 = Digest::MD5.hexdigest(schemas)
        @last_backup = { :hash => md5, :schemas => schemas, :timestamp => Time.now }
        @schema_backups << @last_backup
        # Dump to filesystem
      end
      
      def get_classes
        # Because this is an AbstractAdapter and not a
        # DataObjectAdapter, we can't assume there are any schemas
        # present, so we retrieve the ones that exist and keep them up
        # to date
        classes = Array.new
        result = @persevere.retrieve('/Class[=id]')
        if result.code == "200"
          hresult = JSON.parse(result.body)
          hresult.each do |cname|
            junk,name = cname.split("/")
            classes << name
          end
        else
          DataMapper.logger.error("Error retrieving existing tables: #{result}")
        end
        classes
      end
      
      ##
      # 
      def prep_persvr
        #
        # If the user specified a versioned datastore load the versioning REST code
        # 
        unless get_classes.include?("Versioned") && @options[:versioned]
          versioned_class =<<-EOF
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
          
          response = @persevere.create('/Class/', versioned_class, { 'Content-Type' => 'application/javascript' } )
          
          # Check the response, this needs to be more robust and raise
          # exceptions when there's a problem
          if response.code == "201"# good:
            DataMapper.logger.info("Created versioned class.")
          else
            DataMapper.logger.info("Failed to create versioned class.")
          end
        end
      end
    end # class Adapter
  end # module Persevere

  DataMapper::Adapters::PersevereAdapter = DataMapper::Persevere::Adapter
  DataMapper::Adapters.const_added(:PersevereAdapter)
end # DataMapper
    
    