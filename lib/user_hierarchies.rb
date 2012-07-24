require 'user'
require 'fastercsv'
require 'pp'
require 'salesforce'
require 'version'

module GoodData
  module UserHierarchies
    class UserHierarchy

      self::USER_ID = "ID"
      self::MANAGER_ID = "MANAGERID"
      self::DESCRIBE = 'USERNAME'

      def self::load_roles_from_sf(user, password)
        fields = [:Id,:ParentRoleId]
        data = self.load_from_sf(user, password, options={
          :module => "UserRole",
          :fields => fields
        })
        users_data = self.get_mapped_data(data, fields, :Id)
        h = self.build_hierarchy(users_data, {
        :user_id => "Id",
        :manager_id => "ParentRoleId"
        })
        block_given?() ? yield(h) : h

      end

      def self::load_users_from_sf(user, password)
        fields = [:Email,:Id,:ManagerId]
        data = self.load_from_sf(user, password, options={
          :module => "User",
          :fields => fields
        })
        users_data = self.get_mapped_data(data, fields, :Id)

        h = self.build_hierarchy(users_data, {
        :user_id => "Id",
        :manager_id => "ManagerId"
        })
        block_given?() ? yield(h) : h

      end

      def self::get_mapped_data(data, fields, id_field)
        user_data = {}
        data.each do |row|
          hash = {}
          fields.each {|field| hash[field] = row[field]}
          user_data[row[id_field]] = hash 
        end
        user_data
      end

      def self::load_from_sf(user, password, options={})
          client = Salesforce::Client.new(user, password)
          output = []
          client.grab({
            :module => options[:module],
            :output => output,
            :fields => options[:fields],
            :as_hash => true
          })
          output
      end

      def self::read_from_csv(filename, options = {})
        user_id_key = options[:user_id] || self::USER_ID
        manager_id_key = options[:manager_id] || self::MANAGER_ID

        data = []
        fields = nil
        FasterCSV.foreach(filename, {:headers => true}) do |row|
          fields = row.headers
          data << row.to_hash
        end

        users_data = self.get_mapped_data(data, fields, user_id_key)

        h = self.build_hierarchy(users_data, {
          :user_id => user_id_key,
          :manager_id => manager_id_key
        })
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

      def self.read_weird_hierarchy(file, options={})
        users = {}
        fields = options[:fields] || []
        manager_id = options[:manager_id] || MANAGER_ID
        user_id = options[:user_id] || USER_ID

        fail "You have to specify path fields" if fields.empty?

        headers = nil

        FasterCSV.foreach(file, :headers => true, :return_headers => true) do |row|
          if row.header_row?
            headers = row.fields
          else
            index = row.values_at(*fields)
            if index.include? "" then
              puts "#{row.to_s} has wrong definition"
              next
            end
            users.has_key?(index) ?  users[index] << row.to_hash : users[index] = [row.to_hash]
          end
        end
        users_data = []
        users.each_pair do |index, user|
          
          superior_index = index.dup
          while superior_index.last == "0"
            superior_index.pop
          end
          superior_index.pop
          while superior_index.length < 5
            superior_index.push "0"
          end

          user.each do |u|
            u[manager_id] = []
            users[superior_index] && users[superior_index].each do |manager|
              u[manager_id] << manager[user_id]
            end
            users_data << u
          end
          
        end

        hashed_users_data = get_mapped_data(users_data, headers + [manager_id], user_id)
        h = self.build_hierarchy(hashed_users_data, {
          :user_id => user_id,
          :manager_id => manager_id
        })
        block_given?() ? yield(h) : h
      end

      def self.create_users(users_data, user_id_key)
        users_data.values.inject({}) do |memo, data|
          u = User.new(data, {:id_key => user_id_key})
          memo[u.user_id] = u
          memo
        end
      end

      def self.fill_managers!(users, manager_id_key)
        users.values.each do |user|
          manager_ids = user.send manager_id_key
          manager_ids = if manager_ids.class == Array
            manager_ids
          elsif manager_ids.nil? || manager_ids.empty?
            []
          else
            [manager_ids]
          end
          manager_ids.each do |manager_id|
            user.managers << users[manager_id] if users.has_key?(manager_id)
          end
        end
        users
      end

      def self.fill_subordinates!(users, user_id_key)
        # us = users.values # just the users array
        managers_subordinates = {}
        users.values.each do |user|
          if user.has_manager?
            manager_ids = user.managers.map {|m| m.send user_id_key}
            manager_ids.each do |manager_id|
              managers_subordinates.has_key?(manager_id) ? managers_subordinates[manager_id] << user : (managers_subordinates[manager_id] = [user])
            end
          end
        end

        managers_subordinates.each do |manager_id, subordinates|
          # puts "#{manager_id} #{subordinates}"
          users[manager_id].subordinates = subordinates
        end
        
      end

      def self.build_hierarchy(users_data, options={})
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
        binding.pry
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