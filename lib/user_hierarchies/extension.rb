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
  module Helpers
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

    def self.join(master, slave, on, on2, options = {})
      full_outer = options[:full_outer]

      lookup = create_lookup(slave, on2)
      marked_lookup = {}
      results = master.reduce([]) do |a, line|
        matching_values = lookup[line.values_at(*on)] || []
        marked_lookup[line.values_at(*on)] = 1
        if matching_values.empty?
          a << line.to_hash
        else
          matching_values.each do |matching_value|
            a << matching_value.to_hash.merge(line.to_hash)
          end
        end
        a
      end

      if full_outer
        (lookup.keys - marked_lookup.keys).each do |key|
          results << lookup[key].first.to_hash
        end
      end
      results
    end
  end
end
