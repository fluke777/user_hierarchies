require 'user'
require 'fastercsv'
require 'pp'
require 'ripl'
require 'rforce'

module GoodData
  module UserHierarchies
    class UserHierarchy
    
      self::USER_ID = "ID"
      self::MANAGER_ID = "MANAGERID"
      self::DESCRIBE = 'USERNAME'
    
      def self.grab(options)
        sf_module = options[:module] || fail("Specify SFDC module")
        fields = options[:fields]
        binding = options[:sfdc_connection]
        output = options[:output]


          fields = fields.split(', ') if fields.kind_of? String
          values = fields.map {|v| v.to_sym}

          query = "SELECT #{values.join(', ')} from #{sf_module}"
          # puts query
          answer = binding.query({:queryString => query})

          # output << values
          # pp answer
          answer[:queryResponse][:result][:records].each do |row|
            output << row.values_at(*values)
          end

          more_locator = answer[:queryResponse][:result][:queryLocator]

          while more_locator do
            answer_more = binding.queryMore({:queryLocator => more_locator})
            answer_more[:queryMoreResponse][:result][:records].each do |row|
              output << row.values_at(*values)
            end
            more_locator = answer_more[:queryMoreResponse][:result][:queryLocator]
          end
      end
    
      def self::load_from_sf(user, password, options={})
      # puts "self::load_from_sf"
        additional_fields = options[:additional_fields] || []
          rforce_connection = RForce::Binding.new 'https://www.salesforce.com/services/Soap/u/21.0'
          rforce_connection.login(user, password)

          output = []
          fields = [:Email, :Id, :ManagerId] + additional_fields
          grab({
            :module => 'User',
            :output => output,
            :fields => fields,
            :sfdc_connection => rforce_connection
          })

          users_data = {}
          output.each do |record|
            row = {}
            (fields.zip record).each {|pairs| row[pairs[0].to_s] = pairs[1]}
            # puts record[1]
            users_data[record[1]] = row
          end
          
          h = self.build_hierarchy(users_data, {
            :user_id => "Id",
            :manager_id => "ManagerId"
          })
          block_given?() ? yield(h) : h
      end
    
      def self::read_from_csv(filename, options = {})
        user_id_key = options[:user_id] || self::USER_ID

        users_data = {}

        FasterCSV.foreach(filename, {:headers => true}) do |row|
          users_data[row[user_id_key.to_s]] = row.to_hash
        end
        
        h = self.build_hierarchy(users_data, options)
        block_given?() ? yield(h) : h
      end

      def self::read_from_stdin(*options)
        user_id_key = options[:user_id] || self::USER_ID
        users_data = {}

        FasterCSV($stdin, {:headers => true}) do |csv_in| 
          csv_in.each do |row|
            users_data[row[users_data.to_s]] = row.to_hash
          end
        end
        h = self.build_hierarchy(users_data, options = {})
        block_given?() ? yield(h) : h

      end

      def self.create_users(users_data, user_id_key)
        users = {}
        users_data.each_pair do |id, user_data|
          users[id] = User.new(id, user_data)
        end
        users
      end

      def self.fill_managers!(users, manager_id_key)
        users.each do |id, user|
          manager_id = user.send manager_id_key
          user.manager = users[manager_id]
        end
        users
      end

      def self.fill_subordinates!(users, user_id_key)
        us = users.values # just the users array
        managers_subordinates = {}
        us.each do |user|
          if user.has_manager?
            manager_id = user.manager.send user_id_key
            managers_subordinates.has_key?(manager_id) ? managers_subordinates[manager_id] << user : (managers_subordinates[manager_id] = [user])
          end
        end

        managers_subordinates.each do |manager_id, subordinates|
          # puts "#{manager_id} #{subordinates}"
          users[manager_id].subordinates = subordinates
        end
        
      end

      def self::build_hierarchy(users_data, options={})
        user_id_key = options[:user_id] || self::USER_ID
        manager_id_key = options[:manager_id] || self::MANAGER_ID
        users = create_users(users_data, user_id_key)
        fill_managers!(users, manager_id_key)
        fill_subordinates!(users, user_id_key)
        UserHierarchy.new(users.values, options.merge({
          :lookup => users
        }))
      
      end
    
      attr_accessor :users
    
      def initialize(users, options={})
        @users = users
        @options = options
        @user_id_method_name = options[:user_id] || self.class::USER_ID
        @user_manager_id_method_name = options[:manager_id] || self.class::MANAGER_ID
        @user_describe_method_name = options[:describe_with] || self.class::DESCRIBE
      
        options[:lookup].nil? ? build_lookup : @lookup = options[:lookup]
      
      end
      
      def create_subhierarchy(partition_user)
        UserHierarchy.new(partition_user.all_subordinates, @options)
      end
      
      def build_lookup
        @lookup = {}
        x = @user_id_method_name
        @users.each {|u| @lookup[u.send(x)] = u}
      end
    
      def find_by_id(id)
        @lookup[id]
      end
    
      def annotate_left_right
        already_crawled_users = {}
        index = 0
      
        top_of_hierarchies = users.find_all {|user| !user.has_manager?}
      
        top_of_hierarchies.each do |user|
          index = crawl_next(user, index + 1)
        end
      end
    
      def go_interactive
        Ripl.start :binding => self.instance_eval{ binding }
      end
    
      def as_png
        as_format(:png)
      end
    
      def as_dot
        as_format(:dot)
      end
    
      def as_pdf
        as_format(:pdf)
      end
    
      private
      def as_format(format)
        g = GraphViz::new( "structs", "type" => "graph" )
        nodes = users.collect {|u| u.attributes[:graph_node] = g.add_node(u.send(@user_describe_method_name)); u}

        nodes.each do |n|
          n.subordinates.each {|s| g.add_edge(n.graph_node, s.graph_node)} if n.has_subordinates?
          # g.add_edge(n.graph_node, n.manager.graph_node) if n.has_manager?
        end

        g.output(format => "pokus2.#{format}")
      end

      def crawl_next(user, index)
        user.attributes[:left] = index
        if user.is_manager?
          user.subordinates.each do |subordinate|
            index = crawl_next(subordinate, index + 1)
          end
        end
        user.attributes[:right] = index += 1
        index
      end

    end
  end
end