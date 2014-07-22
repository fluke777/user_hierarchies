require 'ostruct'

module GoodData
  module UserHierarchies
    class User < OpenStruct
      attr_accessor :managers, :subordinates, :attributes

      def initialize(attributes = {})
        super
        @managers = attributes[:managers] || []
        @subordinates = attributes[:subordinates] || []
        @caching_on = true
      end

      def get_subordinates(fields = [])
        if fields.empty?
          subordinates
        else
          subordinates.map { |s| fields.map { |f| s.send f } }
        end
      end

      def all_subordinates_with_self
        @all_subordinates_cache ||= (subordinates + subordinates.mapcat do |subordinate|
          subordinate.all_subordinates
        end).uniq
        @all_subordinates_self_cache ||= @all_subordinates_cache + [self]
        @all_subordinates_self_cache
      end

      def all_subordinates
        @all_subordinates_cache ||= (subordinates + subordinates.mapcat do |subordinate|
          subordinate.all_subordinates
        end).uniq
        @all_subordinates_self_cache ||= @all_subordinates_cache + [self]
        @all_subordinates_cache
      end

      def all_managers
        @all_managers_cache ||= (managers + managers.mapcat { |manager| manager.all_managers }).uniq
        @all_managers_self_cache ||= @all_managers_cache + [self]
        @all_managers_cache
      end

      def all_managers_with_self
        @all_managers_cache ||= managers + managers.mapcat do |manager|
          manager.all_managers
        end.uniq
        @all_managers_self_cache ||= @all_managers_cache + [self]
        @all_managers_self_cache
      end

      def manager?
        subordinates.length > 0
      end

      def has_subordinates?
        manager?
      end

      def has_manager?
        !managers.empty?
      end

      def colleagues
        managers.mapcat { |m| m.subordinates } - [self]
      end

      def standalone?
        !has_subordinates? && !has_manager?
        # subordinates.length == 0 && manager.nil?
      end

      def leaf?
        !has_subordinates? && has_manager?
        # subordinates.length == 0 && !manager.nil?
      end

      def subordinate?
        has_manager?
        # !manager.nil?
      end

      def manager_of?(user, options = {})
        direct = options[:direct] || false
        direct ? subordinates.include?(user) : all_subordinates.include?(user)
      end

      def subordinate_of?(user, options = {})
        direct = options[:direct] || false
        direct ? managers.include?(user) : all_managers.include?(user)
      end

      def []key
        send(key)
      end
    end
  end
end
