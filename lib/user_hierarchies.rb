require 'user'
require 'fastercsv'
require 'pp'
require 'ripl'
require 'rforce'

module GDC
  class UserHierarchy
    
    self::USER_ID = "ID"
    self::MANAGER_ID = "MANAGERID"
    self::DESCRIBE = 'USERNAME'
    
    
    def load_from_sf(user, pasword)
    
        rforce_connection = RForce::Binding.new 'https://www.salesforce.com/services/Soap/u/20.0'
        rforce_connection.login(user, pass)
        
        user_description = rforce_connection.describeSOBject("User")
        
        pp user_description
        
        # result = rforce_connection.query :queryString => "SELECT "
        #   file_name = "#{REPORTS_VALIDATION_PATH}/#{report['link'].split('/').last}-#{Date.today.to_s}.json"
        #   File.open(file_name, 'w') do |f|
        #     f.write result.to_json
        #   end
        #   puts "Created file #{file_name}"
        # end
    end
    
    def self::read_from_csv(filename, options = {})
      
      raise "You need a block" if !block_given?
      users_data = {}
      
      FasterCSV.foreach(filename, {:headers => true}) do |row|
        users_data[row[options[:user_id] || self::USER_ID]] = row
      end
      
      yield self.build_hierarchy(users_data, options)
    end
    
    def self::read_from_stdin(*options)
      raise "You need a block" if !block_given?
      users_data = {}
      
      FasterCSV($stdin, {:headers => true}) do |csv_in| 
        csv_in.each do |row|
          users_data[row[options[:user_id] || self::USER_ID]] = row
        end
      end
      yield self.build_hierarchy(users_data, options = {})
      
    end
    
    def self::build_hierarchy(users_data, options)
      users = {}

      # 1. create users
      # puts "1. create users"
      users_data.each_pair do |id, userData|
        users[id] = User.new(userData[options[:user_id] || self::USER_ID], userData.to_hash)
        # pp userData.to_hash
      end

      # 2. fill their managers
      # puts "2. fill their managers"
      users_data.each_pair do |id, user_data|
        user = users[id]
        manager_id = users_data[id][options[:manager_id] || self::MANAGER_ID]
        user.manager = users[manager_id]
      end

      # 3. fill their subordinates
      # puts "3. fill their subordinates"
      us = users.values # just the users array
      managers_subordinates = {}
      us.each do |user|
        if user.has_manager?
          manager_id = user.manager.user_id
          managers_subordinates.has_key?(manager_id) ? managers_subordinates[manager_id] << user : (managers_subordinates[manager_id] = [user])
        end
      end
      
      managers_subordinates.each do |manager_id, subordinates|
        # puts "#{manager_id} #{subordinates}"
        users[manager_id].subordinates = subordinates
      end
      # puts "DONE"
      
      UserHierarchy.new(users.values, options.merge({
        :lookup => users
      }))
      
    end
    
    attr_accessor :users
    
    def initialize(users, options={})
      @users = users
      @user_id_method_name = options[:user_id] || self.class::USER_ID
      @user_manager_id_method_name = options[:manager_id] || self.class::MANAGER_ID
      @user_describe_method_name = options[:describe_with] || self.class::DESCRIBE
      
      options[:lookup].nil? ? build_lookup : @lookup = options[:lookup]
      
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