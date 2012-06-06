require 'facets/hash'

module GoodData
  module UserHierarchies
    class User

      attr_accessor :user_id, :managers, :subordinates, :attributes

      def initialize(attributes = {}, options={})
        id_key = (options[:id_key] || :id).to_sym
        @managers = attributes[:managers] || []
        @subordinates = attributes[:subordinates] || []
        @attributes = attributes.symbolize_keys!
        @user_id = attributes[id_key]
      end

      def to_s
        "User: user_id=#{user_id}"
      end

      def get_subordinates(fields=[])
        if fields.empty?
          subordinates
        else
          subordinates.map {|s| fields.map {|f| s.send f}}
        end
      end

      def all_subordinates(fields=[])
        # binding.pry
        all_s = (subordinates + subordinates.collect {|subordinate| subordinate.all_subordinates}.flatten)
        if fields.empty?
          all_s
        else
          all_s.map {|s| fields.map {|f| s.send f}}
        end
        
      end

      def all_managers
        if has_manager?
          managers + managers.collect {|manager| manager.all_managers}.flatten
        else
          []
        end
      end

      def is_manager?
        subordinates.length > 0
      end
  
      def has_subordinates?
        is_manager?
      end
  
      def has_manager?
        !managers.empty?
      end


      def is_standalone?
        !has_subordinates? && !has_manager?
        # subordinates.length == 0 && manager.nil?
      end

      def is_leaf?
        !has_subordinates? && has_manager?
        # subordinates.length == 0 && !manager.nil?
      end
  
      def is_subordinate?
        has_manager?
        # !manager.nil?
      end

      def is_manager_of(user, options = {})
        direct = options[:direct] || false
        direct ? subordinates.include?(user) : all_subordinates.include?(user)
      end

      def is_subordinate_of(user, options = {})
        direct = options[:direct] || false
        direct ? managers.include?(user) : all_managers.include?(user)
      end

      def method_missing(method, *args)
        return @attributes[method] if @attributes.has_key?(method)
        super
      end

    end
  end
end