module DataMapper
  class Query
    ##
    def munge_condition(condition)
      loaded_value = condition.loaded_value
      return_value = ""
              
      if condition.subject.is_a?(DataMapper::Property)
        rhs = case loaded_value
        when String               then "\"#{loaded_value}\""
        when DateTime             then "date(%10.f)" % (Time.parse(loaded_value.to_s).to_f * 1000)
        when nil                  then "undefined"
        else                           loaded_value
        end
        return_value = "#{condition.subject.field}#{condition.__send__(:comparator_string)}#{rhs}"
      end
      
      return_value = _fugly_munger(condition, loaded_value) if condition.subject.is_a?(DataMapper::Associations::Relationship)
      return_value
    end

    def _fugly_munger(condition, loaded_value)
      subject = condition.subject

      case subject
        when DataMapper::Associations::ManyToMany::Relationship then
          return_value = "#{condition.subject.field}.contains(/#{subject.child_model.storage_name}/#{loaded_value.key.first})"            
        when DataMapper::Associations::OneToMany::Relationship then
          return_value = "#{condition.subject.field}.contains(/#{subject.parent_model.storage_name}/#{loaded_value.key.first})"
        when DataMapper::Associations::OneToOne::Relationship then 
          if loaded_value.nil?
            return_value = "#{condition.subject.field}#{condition.__send__(:comparator_string)}undefined"
          else
           return_value = "#{condition.subject.field}#{condition.__send__(:comparator_string)}/#{subject.parent_model.storage_name}/#{loaded_value.key.first}"
         end
        when DataMapper::Associations::ManyToOne::Relationship then
          if self.model != subject.child_model
            return_value = "#{condition.subject.field}.contains(/#{subject.parent_model.storage_name}/#{loaded_value.key.first})"
          else
            if loaded_value.nil?
              return_value = "#{condition.subject.field}#{condition.__send__(:comparator_string)}undefined"
            else
             return_value = "#{condition.subject.field}#{condition.__send__(:comparator_string)}/#{subject.parent_model.storage_name}/#{loaded_value.key.first}"
           end
          end
      end
    end
    
    ##
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
        when DataMapper::Query::Conditions::InclusionComparison then 
          result_string = Array.new
          condition.value.to_a.each do |candidate|
            if condition.subject.is_a?(DataMapper::Associations::Relationship)
              result_string << _fugly_munger(condition, candidate)
            else
              result_string << "#{condition.subject.name}=#{candidate}"
            end
          end
          if result_string.length > 0
            "(#{result_string.join("|")})"
          else
            "#{condition.subject.name}=''"
          end
        when DataMapper::Query::Conditions::EqualToComparison,
             DataMapper::Query::Conditions::GreaterThanComparison,
             DataMapper::Query::Conditions::LessThanComparison, 
             DataMapper::Query::Conditions::GreaterThanOrEqualToComparison,
             DataMapper::Query::Conditions::LessThanOrEqualToComparison then
          munge_condition(condition)
        when DataMapper::Query::Conditions::NullOperation then []
        when Array then
           old_statement, bind_values = condition
           statement = old_statement.dup
           bind_values.each{ |bind_value| statement.sub!('?', bind_value.to_s) }
           statement.gsub(' ', '')
        else condition.to_s.gsub(' ', '')
      end
    end
    
    ##
    # Convert a DataMapper Query to a JSON Query.
    #
    # @param [Query] query
    #   The DataMapper query object passed in
    #
    # @api semipublic
    def to_json_query

      # Body of main function
      json_query = ""
      query_terms = Array.new
      order_operations = Array.new
      field_ops = Array.new
      outfields = Array.new
      headers = Hash.new

      query_terms << process_condition(conditions) 

      if query_terms.flatten.length != 0
        json_query += "[?#{query_terms.join("][?")}]"
      end
      
      self.fields.each do |field|
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
        outfields << "'#{field.field}':#{field.field}"
      end
      end
         
      json_query += field_ops.join("")
      
      if order && order.any?
        order.map do |direction|
          order_operations << case direction.operator
            when :asc then "[\/#{direction.target.field}]"
            when :desc then "[\\#{direction.target.field}]"
          end
        end
      end

      json_query += order_operations.join("")

      json_query += "[={" + outfields.join(',') + "}]" unless outfields.empty?

      offset = self.offset.to_i
      limit = self.limit.nil? ? nil : self.limit.to_i + offset - 1
      
      if offset != 0 || !limit.nil?
        headers.merge!( {"Range" => "items=#{offset}-#{limit}"} )
      end
      # puts "#{inspect}"
      # puts json_query, headers
      return json_query, headers
    end
  end
end