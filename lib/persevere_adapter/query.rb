module DataMapper
  module Persevere
    module Query
      ##
      # TODO: Clean this mess up.
      # 
      # @author lamb
      def munge_condition(condition)
        loaded_value = condition.loaded_value
        return_value = ""
        subject = condition.subject 
        
        if subject.is_a?(DataMapper::Property)
          rhs = case loaded_value
          when String               then "\"#{loaded_value}\""
          when DateTime             then "date(%10.f)" % (Time.parse(loaded_value.to_s).to_f * 1000)
          when nil                  then "undefined"
          else                           loaded_value
          end
          return_value = "#{condition.subject.field}#{condition.__send__(:comparator_string)}#{rhs}"
        elsif subject.is_a?(DataMapper::Associations::ManyToOne::Relationship)
          # Join relationship, bury it down!
          if self.model != subject.child_model
            my_side_of_join = links.select{|relation| 
              relation.kind_of?(DataMapper::Associations::ManyToOne::Relationship) &&
              relation.child_model == subject.child_model &&
              # I would really like this to not look at the name, 
              # but sometimes they are different object of the same model
              relation.parent_model.name == self.model.name }.first
              
            # join_results = subject.child_model.all(subject.field.to_sym => loaded_value)
            join_results = subject.child_model.all(subject.child_key.first.name => loaded_value[subject.parent_key.first.name])
            
            return_value = join_results.map{|r| "#{self.model.key.first.name}=#{r[my_side_of_join.child_key.first.name]}"}.join('|')
          else
            comparator = loaded_value.nil? ? 'undefined' : loaded_value.key.first
            return_value = "#{subject.child_key.first.name}#{condition.__send__(:comparator_string)}#{comparator}"
          end
        elsif subject.is_a?(DataMapper::Associations::Relationship)
          if self.model != subject.child_model
            return_value = "#{subject.child_key.first.name}#{condition.__send__(:comparator_string)}#{loaded_value.key.first}"
          else
            comparator = loaded_value.nil? ? 'undefined' : loaded_value.key.first
            return_value = "#{subject.field}_id#{condition.__send__(:comparator_string)}#{comparator}"
          end
        end
        return_value
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
              result_string << "#{condition.subject.child_key.first.name}=#{candidate.key.first}" #munge_condition(condition)
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

        json_query = ''
        field_ops = Array.new
        outfields = Array.new
        
        json_query += self.to_json_query_filter

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
              if field.target.kind_of?(DataMapper::Property::DateTime) || 
                field.target.kind_of?(DataMapper::Property::Time) || 
                field.target.kind_of?(DataMapper::Property::Date)
                "[=#{field.target.field}]"
              else
                ".min(?#{field.target.field})"
              end
            when :max
              if field.target.kind_of?(DataMapper::Property::DateTime) || 
                field.target.kind_of?(DataMapper::Property::Time) || 
                field.target.kind_of?(DataMapper::Property::Date)
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

        json_query += self.to_json_query_ordering

        json_query += "[={" + outfields.join(',') + "}]" unless outfields.empty?


        # puts json_query, headers
        return json_query, self.json_query_headers
      end
      
      ##
      # The filter portion on a json query
      # 
      # @author lamb
      def to_json_query_filter
        query_terms = []
        query_terms << process_condition(conditions) 

        if query_terms.flatten.length != 0
          return "[?#{query_terms.join("][?")}]"
        else
          return ''
        end
        
      end
      
      ##
      # The ordering portion of a json query
      # 
      # @author lamb
      def to_json_query_ordering
        order_operations = []
        if order && order.any?
          order.map do |direction|
            order_operations << case direction.operator
            when :asc then "[\/#{direction.target.field}]"
            when :desc then "[\\#{direction.target.field}]"
            end
          end
        end

        order_operations.join("")
      end
      
      ##
      # The headers of a json query
      # 
      # @author lamb
      def json_query_headers
        headers = Hash.new
        offset = self.offset.to_i
        limit = self.limit.nil? ? nil : self.limit.to_i + offset - 1

        if offset != 0 || !limit.nil?
          headers.merge!( {"Range" => "items=#{offset}-#{limit}"} )
        end
        return headers
      end
      
    end # Query
  end # Persevere
end # DataMapper