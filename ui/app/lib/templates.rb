#!/usr/bin/env ruby

require 'pp'

class Templates

  @templates = {}

  def self.define(name, argspecs, erb_file)
    existing_template = @templates.keys.find {|key| @templates[key].erb_file == erb_file}

    if existing_template && existing_template != name
      raise "Error in template '#{name}': File '#{erb_file}' is already used by template: #{existing_template}"
    end

    @templates[name] = TemplateDef.new(name, argspecs, erb_file)
  end

  def self.emit(name, args = {})
    @templates.fetch(name) {
      raise "Template not defined: #{name}"
    }.emit(args)
  end

  def self.emit_with_layout(template, template_args, layout, layout_args = {})
    @templates.fetch(layout).emit(layout_args.merge(template: template, template_args: template_args))
  end

  def self.append_script(&block)
    Thread.current[:append_scripts] ||= []
    Thread.current[:append_scripts]
  end

  class TemplateRenderError < StandardError
    attr_reader :cause

    def initialize(msg, cause, template_file)
      unless msg =~ /error in.*around line/
        template_error_line_number = try_extract_error_line(cause)

        if template_error_line_number
          msg += " (error in #{template_file} around line ##{template_error_line_number})"
        end
      end

      super(msg)
      @cause = cause
    end

    def try_extract_error_line(cause)
      begin
        line_number = nil
        cause.backtrace.each do |line|
          if line =~ /erubis:([0-9]+):/
            return Integer($1)
          end
        end

        return nil
      rescue
        nil
      end
    end
  end

  class TemplateDef
    attr_reader :erb_file

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
        raise "Unexpected arguments: #{(args.keys - @argspecs.keys).inspect}"
      end

      begin
        Erubis::EscapedEruby.new(File.read(@erb_file)).result(EmptyBinding.for(parsed_args))
      rescue MAPAPIClient::SessionGoneError
        # Re-raise to log out the user
        raise $!
      rescue Sequel::DatabaseError
        # Re-raise to allow DB retry logic
        raise $!
      rescue
        $LOG.error("Original error: #{$@.join("\n")}")
        $LOG.error("Args were: #{args.pretty_inspect}")
        raise TemplateRenderError.new("Failure rendering template: #{@name} (#{@erb_file}): #{$!}",
                                     $!,
                                     @erb_file)
      end
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
