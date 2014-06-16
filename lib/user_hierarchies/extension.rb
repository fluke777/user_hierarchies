module Enumerable
  def mapcat(initial = [], &block)
    reduce(initial) do |a, e|
      block.call(e).each do |x|
        a << x
      end
      a
    end
  end
end

module GoodData
  module Utils
    def self.create_lookup(collection, on)
      lookup = {}
      if on.is_a?(Array)
        collection.each do |e|
          key = e.values_at(*on)
          lookup[key] = [] unless lookup.key?(key)
          lookup[key] << e
        end
      else
        collection.each do |e|
          key = e[on]
          lookup[key] = [] unless lookup.key?(key)
          lookup[key] << e
        end
      end
      lookup
    end

    def self.lookup(master, slave, on, on2)
      lookup = create_lookup(slave, on2)
      marked_lookup = {}
      results = master.reduce([]) do |a, line|
        matching_values = lookup[line.values_at(*on)] || []
        marked_lookup[line.values_at(*on)] = 1
        if matching_values.empty?
          a << line.to_h
        else
          matching_values.each do |matching_value|
            a << matching_value.to_h.merge(line.to_h)
          end
        end
        a
      end
      (lookup.keys - marked_lookup.keys).each do |key|
        results << lookup[key].first.to_h
      end
      results
    end
  end
end
