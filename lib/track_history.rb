module TrackHistory

  autoload :VERSION, File.join(File.dirname(__FILE__), 'track_history', 'version')
  require 'rubygems'
  require 'active_record'

  def self.install
    ActiveRecord::Base.send(:include, self)
  end

  def self.included(base)
    base.extend ActsAsMethods
    base.send(:include, InstanceMethods)
  end

  module ActsAsMethods

    # Make a model historical
    # Takes a hash of options, which can only be :model_name to force a different model name
    # Default model name is ModelHistory
    def track_history(options = {}, &block)
      options.assert_valid_keys(:model_name, :table_name, :reference)
      define_historical_model(self, options[:model_name], options[:table_name], options.has_key?(:reference) ? !!options[:reference] : true)
      module_eval(&block) if block_given?
    end

    def annotate(field, options = {}, &block) # haha
      options.assert_valid_keys(:as)
      save_as = options.has_key?(:as) ? options[:as] : field

      unless historical_class.columns_hash.has_key?(save_as.to_s)
        raise ActiveRecord::StatementInvalid.new("No such attribute '#{field}' on #{@klass_reference.name}")
      end

      historical_class.historical_tracks[save_as] = block.nil? ? field : block
    end

    def historical_class
      @klass_reference
    end

    private

    def define_historical_model(base, model_name, table_name, track_reference)

      # figure out the model name
      model_name ||= "#{base.name}History"
      klass = Object.const_set(model_name, Class.new(ActiveRecord::Base))
      @klass_reference = klass

      # set up a way to record tracks
      def @klass_reference.historical_tracks; @historical_tracks ||= {}; end
      def @klass_reference.historical_fields; @historical_fields ||= []; end
      def @klass_reference.track_historical_reference?; @track_historical_reference; end
      @klass_reference.instance_variable_set(:@track_historical_reference, track_reference)

      # infer fields
      klass.send(:table_name=, table_name) unless table_name.nil?
      klass.columns_hash.each_key do |k| 
        matches = k.match(/(.+?)_before$/)
        if matches && matches.size == 2 && field_name = matches[1]
          klass.historical_fields << field_name if klass.columns_hash.has_key?("#{field_name}_after")
        end
      end
     
      # create the history class
      rel = base.name.singularize.underscore.downcase.to_sym
      klass.send(:include, HistoricalRelationHelpers)

      if track_reference
        klass.belongs_to rel
        klass.send(:alias_method, :historical_relation, rel)
        self.class.send(:define_method, :historical_fields) { klass.historical_fields }
      end

      # tell the other class about us
      # purposely don't define these until after getting historical_fields
      has_many :histories, :class_name => model_name, :order => 'created_at desc' if track_reference
      before_update :record_historical_changes

    end

  end

  module HistoricalRelationHelpers

    # Get a list of the modifications in a given history
    def modifications
      self.class.historical_fields.reject do |field|
        send(:"#{field}_before") == send(:"#{field}_after")
      end
    end

    def to_s
      return 'modified nothing' if modifications.empty?
      str = 'modified ' + modifications.sort.join(', ')
      str += " on #{historical_relation}" if self.class.instance_variable_get(:@track_historical_reference)
      str
    end

  end

  module InstanceMethods

    private

    def record_historical_changes
      historical_fields = self.class.historical_class.historical_fields
      historical_tracks = self.class.historical_class.historical_tracks
      return if historical_fields.empty? && historical_tracks.empty?
      # go through each and build the hashes
      attributes = {}
      historical_fields.each do |field|
        next unless send(:"#{field}_changed?")
        attributes.merge! :"#{field}_before" => send(:"#{field}_was"), :"#{field}_after" => send(field.to_sym)
      end
      return if attributes.empty? # nothing changed - skip out 
      # then go through each track
      historical_tracks.each do |field, block|
        attributes[field] = block.is_a?(Symbol) ? send(block) : (block.arity == 1 ? block.call(self) : instance_eval(&block)) # give access to the user object
      end
      # record the change
      if self.class.historical_class.track_historical_reference?
        self.histories.create(attributes)
      else
        self.class.historical_class.create(attributes)
      end
    end

  end

end

TrackHistory::install
