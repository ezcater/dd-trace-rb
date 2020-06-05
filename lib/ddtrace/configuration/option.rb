module Datadog
  module Configuration
    # Represents an instance of an integration configuration option
    class Option
      attr_reader \
        :definition

      def initialize(definition, context)
        @definition = definition
        @context = context
        @value = nil
        @is_set = false
      end

      def set(value)
        # TODO safeguard against :tracer=
        require 'rspec/mocks/test_double'
        if !(definition.class < RSpec::Mocks::TestDouble) && definition.name == :tracer && !(value.class < Datadog::Configuration::Base) && !value.instance_variable_get(:@dd_use_real_tracer)
          if value.is_a?(Proc)
            raise "setting tracer PROC! #{value}"
          else
            raise "setting tracer! #{value}"
          end
        end

        old_value = @value
        (@value = context_exec(value, old_value, &definition.setter)).tap do |v|
          @is_set = true
          context_exec(v, old_value, &definition.on_set) if definition.on_set
        end
      end

      def get
        if @is_set
          @value
        elsif definition.delegate_to
          context_eval(&definition.delegate_to)
        else
          set(default_value)
        end
      end

      def reset
        @value = if definition.resetter
                   # Don't change @is_set to false; custom resetters are
                   # responsible for changing @value back to a good state.
                   # Setting @is_set = false would cause a default to be applied.
                   context_exec(@value, &definition.resetter)
                 else
                   @is_set = false
                   nil
                 end
      end

      def default_value
        if definition.lazy
          context_eval(&definition.default)
        else
          definition.default
        end
      end

      private

      def context_exec(*args, &block)
        @context.instance_exec(*args, &block)
      end

      def context_eval(&block)
        @context.instance_eval(&block)
      end
    end
  end
end
