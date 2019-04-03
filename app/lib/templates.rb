#!/usr/bin/env ruby

class Templates

  @templates = {}

  def self.define(name, argspecs, erb_file)
    @templates[name] = TemplateDef.new(name, argspecs, erb_file)
  end

  def self.emit(name, args = {})
    @templates.fetch(name) {
      raise "Template not defined: #{name}"
    }.emit(args)
  end

  class TemplateDef
    def initialize(name, argspecs, erb_file)
      @name = name
      @argspecs = argspecs.map {|a| parse_argspec(a)}.map {|argspec| [argspec.name, argspec]}.to_h
      @erb_file = erb_file
    end

    def emit(args)
      parsed_args = @argspecs.map {|argname, argspec|
        value = args.fetch(argname, nil)

        begin
          [argname, argspec.call(value)]
        rescue
          raise "Template #{@name} (#{@erb_file}): #{argname}: #{$!}"
        end
      }.to_h

      unless (args.keys - @argspecs.keys).empty?
        # Too annoying?  Maybe we just want to drop unknown stuff?
        raise "Unexpected arguments: #{(args.keys - @argspecs.keys).inspect}"
      end

      Erubis::EscapedEruby.new(File.read(@erb_file)).result(EmptyBinding.for(parsed_args))
    end


    private


    def parse_argspec(a)
      if a.is_a?(Array)
        ArrayType.new(a[0])
      elsif a.is_a?(Symbol)
        if a.to_s.end_with?('?')
          NullableType.new(a.to_s[0..-2].intern)
        else
          RequiredType.new(a)
        end
      else
        raise "Couldn't parse argspec: #{a}"
      end
    end

    BaseType ||= Struct.new(:name)

    class ArrayType < BaseType
      def call(value)
        if value.nil?
          []
        elsif value.is_a?(Array)
          value
        else
          raise "invalid array value: #{value}"
        end
      end
    end

    class NullableType < BaseType
      def call(value)
        value
      end
    end

    class RequiredType < BaseType
      def call(value)
        if value.nil?
          raise "value can't be nil"
        else
          value
        end
      end
    end
  end

  class EmptyBinding
    def self.for(args)
      result = binding
      args.each do |key, val|
        result.local_variable_set(key, val)
      end

      result
    end
  end

end
