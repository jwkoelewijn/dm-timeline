DM_VERSION = '>=1.2.0'

require 'rubygems'
gem 'dm-core',        DM_VERSION
gem 'dm-validations', DM_VERSION
gem 'dm-migrations',  DM_VERSION

require 'dm-core'
require 'dm-validations'
require 'dm-migrations'
require 'dm-timeline/adapter_extensions'
require 'dm-timeline/collection_extension'
require 'dm-timeline/resource_extension'

module DataMapper
  module Timeline
    def self.included(base)
      base.extend(ClassMethods)
    end

    module InstanceMethods

      def initialize(attributes = {})
        override = attributes.has_key?(:at)
        at = Timeline::Util.extract_timeline_options(attributes)
        at = [self.class.repository.adapter.class::START_OF_TIME,
              self.class.repository.adapter.class::END_OF_TIME]   if override && at.nil?
        if at
          self.timeline_start = at.first || self.class.repository.adapter.class::START_OF_TIME
          self.timeline_end = (at.last || self.class.repository.adapter.class::END_OF_TIME) if at.length > 1
        end
        @initializing = true
        super
        @initializing = false
        self.register_at_timeline_observables
      end

      def save
        self.timeline_start = self.class.repository.adapter.class::START_OF_TIME if self.timeline_start.nil? || (self.timeline_start.is_a?(String) && self.timeline_start.blank?)
        self.timeline_end = self.class.repository.adapter.class::END_OF_TIME   if self.timeline_end.nil?   || (self.timeline_end.is_a?(String)   && self.timeline_end.blank?)

        super
      end

      def on_timeline_at?(moment = Date.today)
        moment = moment.to_datetime if moment.respond_to?(:to_datetime)
        timeline_start <= moment && timeline_end > moment
      end

      def on_timeline_during?(period = [Date.today, Date.today])
        unless period.is_a?(Enumerable)
          period = [period]
        end
        period_start   = period.first.to_date if period.first.respond_to?(:to_date)
        period_start ||= self.class.repository.adapter.class::START_OF_TIME
        period_end     = period.last.to_date if period.last.respond_to?(:to_date)
        period_end   ||= self.class.repository.adapter.class::END_OF_TIME
        if period_start == period_end
          period_start < timeline_end && period_start >= timeline_start
        else
          period_start < timeline_end && period_end > timeline_start
        end
      end

      def infinite?
        if !timeline_start.is_a?(String) && !timeline_end.is_a?(String)
          timeline_end >= self.class.repository.adapter.class::END_OF_TIME - 1
        else
          true
        end
      end

      def timeline_end_may_not_be_before_timeline_start
        if self.timeline_end && self.timeline_start.is_a?(Date) &&
           self.timeline_end.is_a?(Date) && self.timeline_end < self.timeline_start
          return false, _("End date may not be before begin date.")
        end
        true
      end

      def timeline_start_should_make_sense
        if self.timeline_start && timeline_start.is_a?(Date) &&
           timeline_start != self.class.repository.adapter.class::START_OF_TIME &&
           (timeline_start < Date.civil(1900, 1, 1) || timeline_start >= Date.civil(2100, 1, 1))
          return false, _("Start date doesn't make sense as a start date.")
        end
        true
      end

      def timeline_end_should_make_sense
        if self.timeline_end && timeline_start.is_a?(Date) &&
           timeline_end != self.class.repository.adapter.class::END_OF_TIME &&
           (timeline_end < Date.civil(1900, 1, 1) || timeline_end >= Date.civil(2100, 1, 1))
          return false, _("End date doesn't make sense as an end date.")
        end
        true
      end

      def timeline
        Range.new(timeline_start, timeline_end, true)
      end

      def original_from
        if original_values && original_values.has_key?(:timeline_start)
          original_values[:timeline_start]
        else
          @original_timeline ? @original_timeline.first : nil
        end
      end

      def original_to
        if original_values && original_values.has_key?(:timeline_end)
          original_values[:timeline_end]
        else
          @original_timeline ? @original_timeline.last : nil
        end
      end

      def changed_periods
        return [] unless @original_timeline
        periods = []
        if deleted_at.nil? && original_from && original_to

          if timeline_start < original_from
            periods << [timeline_start, original_from]
          elsif timeline_start > original_from
            periods << [original_from, timeline_start]
          end

          if timeline_end < original_to
            periods << [timeline_end, original_to]
          elsif timeline_end > original_to
            periods << [original_to, timeline_end]
          end

        else
          periods << [timeline_start, timeline_end]
        end
        periods
      end

      def crop_timeline_children(children)
        children.each do |c|
          yield(c) if block_given?
          if c.valid_from >= self.valid_to || c.valid_to <= self.valid_from
            c.destroy
          elsif c.valid_from < self.valid_from || c.valid_to > self.valid_to
            c.valid_from = [c.valid_from, self.valid_from].max
            c.valid_to   = [c.valid_to,   self.valid_to].min
            c.save
          end
        end
      end

      def crop_timeline(parent)
        if timeline_start >= parent.timeline_end || timeline_end <= parent.timeline_start
          self.destroy
        elsif timeline_start < parent.timeline_start || timeline_end > parent.timeline_end
          self.timeline_start = [self.timeline_start, parent.timeline_start].max
          self.timeline_end   = [self.timeline_end, parent.timeline_end].min
        elsif self.has_sticky_timeline? && (
              (timeline_end == parent.original_to && timeline_end < parent.timeline_end) ||
              (timeline_start == parent.original_from && timeline_start > parent.timeline_start))
          self.timeline_start = [self.timeline_start, parent.timeline_start].min
          self.timeline_end   = [self.timeline_end, parent.timeline_end].max
        end
      end

      # This is who are observing this timelined resource
      def timeline_observers
         @timeline_observers ||= []
      end

      def register_at_timeline_observables
        self.class.timeline_observables.each do |observable|
          send(observable).register_observer(self)
        end
      end

      def unregister_observer(observer)
        timeline_observers.delete(observer)
      end

      def register_observer(observer)
        timeline_observers << observer unless timeline_observers.include?(observer)
      end

      def should_notify_observers?
        (original_values.keys.include?(:timeline_start) || original_values.keys.include?(:timeline_end))
      end

      def notify_observers
        timeline_observers.each do |observer|
          observer.notify_timeline_change(self) if observer.respond_to?(:notify_timeline_change)
        end if should_notify_observers?
      end

      def notify_timeline_change(observable)
        crop_timeline(observable)
        self.notify_observers
      end

      def has_sticky_timeline?
        self.class.has_sticky_timeline?
      end
    end

    module HideableInstanceMethods
      def hidden_from=(param)
        self.timeline_end = param
      end

      def hidden_from
        self.timeline_end
      end

      def visible_on?(param)
        self.on_timeline_at?(param)
      end

      def visible_during?(param)
        self.on_timeline_during?(param)
      end
    end

    module ValidityInstanceMethods
      def valid_from=(param)
        self.timeline_start = param
      end

      def valid_from
        self.timeline_start
      end

      def valid_to=(param)
        self.timeline_end = param
      end

      def valid_to
        self.timeline_end
      end

      def valid_on?(param)
        self.on_timeline_at?(param)
      end

      def valid_during?(param)
        self.on_timeline_during?(param)
      end
    end

    module ClassMethods
      def all_with_timeline(query = {})
        query_arguments     = query

        if query.respond_to?(:has_key?) && !query.has_key?(*self.key)
          conditions          = Timeline::Util.extract_timeline_options(query)
          query_arguments     = query.merge(Timeline::Util.generation_timeline_conditions(conditions))
        end

        all_without_timeline(query_arguments)
      end

      def first_with_timeline(query = nil)
        if query.nil?
          first_without_timeline
        else
          conditions       = Timeline::Util.extract_timeline_options(query)
          query_arguments  = Timeline::Util.generation_timeline_conditions(conditions)

          first_without_timeline(query.merge(query_arguments))
        end
      end

      # This is what the current timelined resource observes
      def timeline_observables
        @timeline_observables ||= []
      end

      def create_before_filter(observable)
        # The method should not be called as part of the first #attributes= call
        class_eval <<-EOS, __FILE__, __LINE__
          before "#{observable}=".to_sym do |param|
            return if @initializing
            observable = send(:#{observable})
            observable.unregister_observer(self) if observable
            param.register_observer(self)
          end
        EOS
      end

      def hideable?
        @is_hideable || false
      end

      def has_sticky_timeline?
        @sticky_timeline
      end

      def is_on_timeline(options = {})
        @is_hideable = options.delete(:hideable) || false

        property :timeline_start, Date, :default => (hideable? ? lambda {repository.adapter.class::START_OF_TIME} : lambda { Date.today }), :auto_validation => false
        property :timeline_end,   Date, :default => repository.adapter.class::END_OF_TIME, :auto_validation => false

        validates_primitive_type_of :timeline_start, :message => lambda {_("Valid from is an invalid date")}
        validates_primitive_type_of :timeline_start, :message => lambda {_("Valid to is an invalid date")}

        include DataMapper::Timeline::InstanceMethods
        if hideable?
          include DataMapper::Timeline::HideableInstanceMethods
        else
          include DataMapper::Timeline::ValidityInstanceMethods
        end
        include GetText

        validates_with_method :timeline_end, :method => :timeline_end_may_not_be_before_timeline_start
        validates_with_method :timeline_start, :method => :timeline_start_should_make_sense
        validates_with_method :timeline_end, :method => :timeline_end_should_make_sense

        if options
          observes = options.delete(:limited_by)
          unless observes.nil?
            observes = [observes] unless observes.kind_of?(Enumerable)
            observes.each do |observable|
              timeline_observables << observable
              create_before_filter(observable)
            end

            @sticky_timeline = options.delete(:sticky) || false
          end
        end

        before :timeline_start= do |param|
          if param.kind_of?(Hash) && param[:date]
            if param[:date].blank?
              self.timeline_start = self.class.repository.adapter.class::START_OF_TIME
            else
              date = Timeline::Util.format_date_string(param[:date])
              self.timeline_start = param[:date]
            end
            throw :halt
          elsif param.is_a?(String)
            param = Timeline::Util.format_date_string(param)
            attribute_set(:timeline_start, param)
            throw :halt
          elsif param.blank?
            attribute_set(:timeline_start, Date.today)
            throw :halt
          end
        end

        before :timeline_end= do |param|
          if param.kind_of?(Hash) && param[:date]
            if param[:date].blank?
              self.timeline_end = self.class.repository.adapter.class::END_OF_TIME
            else
              self.timeline_end = Timeline::Util.format_date_string(param[:date])
            end
            throw :halt
          elsif param.is_a?(String)
            param = Timeline::Util.format_date_string(param)
            attribute_set(:timeline_end, param)
            throw :halt
          elsif param.blank?
            attribute_set(:timeline_end, self.class.repository.adapter.class::END_OF_TIME)
            throw :halt
          end
        end

        before :destroy do
          self.class.timeline_observables.each do |observable|
            send(observable).unregister_observer(self)
          end
        end

        before :valid? do
          self.notify_observers
        end

        class << self
          alias_method :all_without_timeline, :all
          alias_method :all, :all_with_timeline

          alias_method :first_without_timeline, :first
          alias_method :first, :first_with_timeline
        end
      end
    end

    module Util
      def self.format_date_string(string)
        if string =~ /[0-9]{8}/
          string = "#{string[0..1]}-#{string[2..3]}-#{string[4..7]}"
        elsif string =~ /[0-9]{6}/
          string = "#{string[0..1]}-#{string[2..3]}-19#{string[4..5]}"
        end
        string
      end

      def self.extract_timeline_options(query)
        if Hash === query && query.has_key?(:at)
          conditions = query.delete(:at)

          if conditions.nil?
            # Explicitly don't want any conditions
            conditions = nil
          elsif conditions.class == Date
            conditions = [conditions, conditions + 1]
          elsif conditions.kind_of?(Date) || conditions.kind_of?(Time)
            conditions = [conditions]
          end
          conditions
        else
          nil
        end
      end

      def self.generation_timeline_conditions(conditions)
        return {} if conditions.nil?
        conditions = [conditions] unless conditions.respond_to?(:first) && conditions.respond_to?(:last)
        if conditions.length < 2 || (conditions.first && conditions.first == conditions.last)
          {:timeline_start.lte => conditions.last, :timeline_end.gt => conditions.first}
        else
          first = conditions.first || repository.adapter.class::START_OF_TIME
          last  = conditions.last  || repository.adapter.class::END_OF_TIME
          {:timeline_start.lt => last, :timeline_end.gt => first}
        end

      end
    end

  end
end

