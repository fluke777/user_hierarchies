require 'facets/hash'

class User

  attr_accessor :user_id, :manager, :subordinates, :attributes

  def initialize(id, attributes = {})
    @user_id = id
    @manager = attributes[:manager]
    @subordinates = attributes[:subordinates] || []
    @attributes = attributes.symbolize_keys!
  end

  # def to_s
  #   "User: user_id=#{user_id}, #{name}, manager: #{manager.name if manager}, subordinates: #{subordinates.collect {|u| u.name}.join(', ')}"
  # end
  # 
  # def name
  #   "#{first_name} #{last_name}"
  # end

  def all_subordinates
    subordinates + subordinates.collect {|subordinate| subordinate.all_subordinates}.flatten
  end

  def all_managers
     manager ? [manager] + manager.all_managers : []
  end

  def is_manager?
    subordinates.length > 0
  end
  
  def has_subordinates?
    is_manager?
  end
  
  def has_manager?
    !manager.nil?
  end


  def is_standalone?
    subordinates.length == 0 && manager.nil?
  end

  def is_leaf?
    subordinates.length == 0 && !manager.nil?
  end
  
  def is_subordinate?
    !manager.nil?
  end

  def is_manager_of(user, options = {})
    direct = options[:direct] || false
    direct ? subordinates.include?(user) : all_subordinates.include?(user)
  end

  def is_subordinate_of(user, options = {})
    direct = options[:direct] || false
    direct ? manager == user : all_managers.include?(user)
  end

  def method_missing(method, *args)
    return @attributes[method] if @attributes.has_key?(method)
    super
  end

end