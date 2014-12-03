require 'active_support/all'
require 'csv'

module GoodData
  module UserHierarchies
    class UserHierarchy
      self::USER_ID = 'ID'
      self::MANAGER_ID = 'MANAGERID'
      self::DESCRIBE = 'USERNAME'

      def self.crawl(users, level, memo = [], &block)
        return if users.empty?
        users.each { |u| block.call(u, level, memo) }
        crawl(users.mapcat { |u| u.subordinates }, level + 1, memo, &block)
      end

      def self.read_from_csv(filename, options = {})
        data = []
        CSV.foreach(filename, headers: true) do |row|
          data << row.to_hash
        end
        h = build_hierarchy(data, options)
        block_given? ? yield(h) : h
      end

      def self.read_from_stdin(options = {})
        users_data = {}
        CSV($stdin, headers: true) do |csv_in|
          csv_in.each do |row|
            users_data[row[users_data.to_s]] = row.to_hash
          end
        end
        h = build_hierarchy(users_data, options)
        block_given? ? yield(h) : h
      end

      def self.fill_managers!(users, lookup, manager_id_key)
        users.each do |user|
          key = user[manager_id_key]
          unless key.blank?
            managers = if key.respond_to?(:each)
                         key.mapcat { |k| lookup[k] }.compact
                       elsif key.nil? || key.empty?
                         []
                       else
                         lookup[key]
                       end
            user.managers = managers.uniq
          end
        end
        users
      end

      def self.fill_subordinates!(users, lookup, user_id_key)
        # us = users.values # just the users array
        managers_subordinates = {}
        users.each do |user|
          if user.has_manager?
            managers = user.managers.map { |m| m[user_id_key] }
            managers.each do |manager|
              managers_subordinates.key?(manager) ? managers_subordinates[manager] << user : (managers_subordinates[manager] = [user])
            end
          end
        end
        managers_subordinates.each do |manager_key, subordinates|
          managers = lookup[manager_key]
          managers && managers.each { |manager| manager.subordinates = subordinates.uniq }
        end
      end

      def self.build_hierarchy(users_data, options = {})
        user_id_key = options[:id] || options['id'] || self::USER_ID
        hashing_key = options[:hashing_id] || options['hashing_id'] || user_id_key
        manager_id_key = options[:manager_id] || options['manager_id'] || self::MANAGER_ID
        users = users_data.map do |data|
          User.new(data.to_hash)
        end
        mapped_users_data = GoodData::Helpers.create_lookup(users, user_id_key)
        fill_managers!(users, mapped_users_data, manager_id_key)
        fill_subordinates!(users, mapped_users_data, user_id_key)
        UserHierarchy.new(users, options.merge(
          id: user_id_key,
          manager_id: manager_id_key,
          hashing_id: hashing_key))
      end

      attr_accessor :users, :hashing_id

      def initialize(users, options = {})
        @users = users
        @options = options
        @hashing_id = options[:hashing_id] || fail('You have to specify key for hashing')
        @lookup = options[:lookup].nil? ? build_lookup : options[:lookup]
      end

      def build_lookup
        GoodData::Helpers.create_lookup(@users, @hashing_id).reduce({}) do |a, e|
          _, val = [e[0], e[1]]
          a[e.first] = val.nil? ? nil : val.first
          a
        end
      end

      def find_by_id(id)
        @lookup[id]
      end

      def go_interactive
        binding.pry
      end
    end
  end
end
