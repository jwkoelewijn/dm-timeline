DM_VERSION = '>=1.2.0'

require 'rubygems'
gem 'dm-core',        DM_VERSION
gem 'dm-validations', DM_VERSION
gem 'dm-migrations',  DM_VERSION
gem 'gettext'

require 'dm-core'
require 'dm-validations'
require 'dm-migrations'
require 'gettext'
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
          self.valid_from = at.first || self.class.repository.adapter.class::START_OF_TIME
          self.valid_to   = (at.last || self.class.repository.adapter.class::END_OF_TIME) if at.length > 1
        end
        super
      end

      def save(options = {} )
        @original_timeline = [original_values[:valid_from] || (new_record? ? nil : valid_from), original_values[:valid_to] || (new_record? ? nil : valid_to)]

        if options.is_a?(Hash) && times = options.delete(:at)
          self.valid_from = times.first
          self.valid_to   = times.last
        end

        options = :default if options.is_a?(Hash)

        self.valid_from = self.class.repository.adapter.class::START_OF_TIME if self.valid_from.nil? || (self.valid_from.is_a?(String) && self.valid_from.blank?)
        self.valid_to   = self.class.repository.adapter.class::END_OF_TIME   if self.valid_to.nil?   || (self.valid_to.is_a?(String)   && self.valid_to.blank?)

        super()
      end

      def valid_on?(moment = Date.today)
        moment = moment.to_datetime if moment.respond_to?(:to_datetime)
        valid_from <= moment && valid_to > moment
      end

      def valid_during?(period = [Date.today, Date.today])
        unless period.is_a?(Enumerable)
          period = [period]
        end
        period_start   = period.first.to_date if period.first.respond_to?(:to_date)
        period_start ||= self.class.repository.adapter.class::START_OF_TIME
        period_end     = period.last.to_date if period.last.respond_to?(:to_date)
        period_end   ||= self.class.repository.adapter.class::END_OF_TIME
        if period_start == period_end
          period_start < valid_to && period_start >= valid_from
        else
          period_start < valid_to && period_end > valid_from
        end
      end

      def infinite?
        if !self.valid_from.is_a?(String) && !self.valid_to.is_a?(String)
          self.valid_to >= self.class.repository.adapter.class::END_OF_TIME - 1
        else
          true
        end
      end

      def valid_to_may_not_be_before_valid_from
        if self.valid_to && self.valid_from.is_a?(Date) &&
           self.valid_to.is_a?(Date) && self.valid_to < self.valid_from
          return false, _("End date may not be before begin date.")
        end
        true
      end

      def valid_from_should_make_sense
        if self.valid_to && valid_from.is_a?(Date) &&
           valid_from != self.class.repository.adapter.class::START_OF_TIME &&
           (valid_from < Date.civil(1900, 1, 1) || valid_from >= Date.civil(2100, 1, 1))
          return false, _("Start date doesn't make sense as a start date.")
        end
        true
      end

      def valid_to_should_make_sense
        if self.valid_to && valid_to.is_a?(Date) &&
           valid_to != self.class.repository.adapter.class::END_OF_TIME &&
           (valid_to < Date.civil(1900, 1, 1) || valid_to >= Date.civil(2100, 1, 1))
          return false, _("End date doesn't make sense as an end date.")
        end
        true
      end

      def timeline
        Range.new(valid_from, valid_to, true)
      end

      def original_from
        @original_timeline ? @original_timeline.first : nil
      end

      def original_to
        @original_timeline ? @original_timeline.last : nil
      end

      def changed_periods
        return [] unless @original_timeline
        periods = []
        if deleted_at.nil? && original_from && original_to

          if valid_from < original_from
            periods << [valid_from, original_from]
          elsif valid_from > original_from
            periods << [original_from, valid_from]
          end

          if valid_to < original_to
            periods << [valid_to, original_to]
          elsif valid_to > original_to
            periods << [original_to, valid_to]
          end

        else
          periods << [valid_from, valid_to]
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

      def is_on_timeline

        property :valid_from, Date, :default => lambda { Date.today }, :auto_validation => false
        property :valid_to,   Date, :default => repository.adapter.class::END_OF_TIME, :auto_validation => false

        validates_primitive_type_of :valid_from, :message => lambda {_("Valid from is an invalid date")}
        validates_primitive_type_of :valid_to, :message => lambda {_("Valid to is an invalid date")}

        include DataMapper::Timeline::InstanceMethods
        include GetText

        validates_with_method :valid_to, :method => :valid_to_may_not_be_before_valid_from
        validates_with_method :valid_from, :method => :valid_from_should_make_sense
        validates_with_method :valid_to, :method => :valid_to_should_make_sense

        before :valid_from= do |param|
          if param.kind_of?(Hash) && param.has_key?(:date)
            if param[:date].blank? || param[:date].nil?
              self.valid_from = self.class.repository.adapter.class::START_OF_TIME
            else
              date = Timeline::Util.format_date_string(param[:date])
              self.valid_from = date #param[:date]
            end
            throw :halt
          elsif param.is_a?(String)
            param = Timeline::Util.format_date_string(param)
            attribute_set(:valid_from, param)
            throw :halt
          elsif param.blank? || param.nil?
            attribute_set(:valid_from, Date.today)
            throw :halt
          end
        end

        before :valid_to= do |param|
          if param.kind_of?(Hash) && param.has_key?(:date)
            if param[:date].blank? || param[:date].nil?
              self.valid_to = self.class.repository.adapter.class::END_OF_TIME
            else
              self.valid_to = Timeline::Util.format_date_string(param[:date])
            end
            throw :halt
          elsif param.is_a?(String)
            param = Timeline::Util.format_date_string(param)
            attribute_set(:valid_to, param)
            throw :halt
          elsif param.blank? || param.nil?
            attribute_set(:valid_to, self.class.repository.adapter.class::END_OF_TIME)
            throw :halt
          end
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
          {:valid_from.lte => conditions.last, :valid_to.gt => conditions.first}
        else
          first = conditions.first || repository.adapter.class::START_OF_TIME
          last  = conditions.last  || repository.adapter.class::END_OF_TIME
          {:valid_from.lt => last, :valid_to.gt => first}
        end

      end
    end

  end
end

