require 'date'

module DTO
  class DTOTypeError < StandardError
  end

  module DTOTypes
    Boolean = Object.new

    def Boolean.name
      "Boolean"
    end

    def self.Boolean(val); !!val; end
    def self.Integer(val); Kernel.Integer(val); end
    def self.Array(val); Kernel.Array(val); end
    def self.Hash(val); Kernel.Hash(val); end
    def self.Date(val); Kernel.const_get('Date').parse(val); end
  end

  def self.included(base)
    base.extend(ClassMethods)
    base.include(DTOTypes)
  end

  def self.clone_and_convert_keys(obj)
    if obj.is_a?(Hash)
      obj.map {|k, v| [k.to_s, clone_and_convert_keys(v)]}.to_h
    elsif obj.is_a?(Array)
      obj.map {|elt| clone_and_convert_keys(elt)}
    else
      obj
    end
  end

  def initialize(hash = {})
    @values = self.class.dto_prepare_hash(hash)
  end

  def fetch(*args, &block)
    @values.fetch(args[0].to_s, *args.drop(1), &block)
  end

  def []=(k, v)
    k = k.to_s
    @values[k] = self.class.dto_coerce_type(k, v)
  end

  def merge(values)
    self.class.from_hash(@values.merge(DTO.dto_prepare_hash(incoming_values)))
  end

  def merge!(values)
    @values.merge!(DTO.dto_prepare_hash(incoming_values))
    self
  end

  def to_hash
    @values
  end

  def to_json(*)
    @values.to_json
  end

  def validate
    errors = []

    self.class.dto_fields.each do |field_def|
      field_value = self.fetch(field_def.name, nil)

      if field_def.required && field_value.nil?
        errors << {code: "REQUIRED_VALUE_MISSING", field: field_def.name}
        next
      end

      # Ensure we can coerce the type
      if field_value
        self.class.dto_coerce_type(field_def.name, field_value) do |clz, _, value|
          errors << {code: "INVALID_TYPE", field: field_def.name, expected_type: field_def.type.inspect}
          next
        end
      end

      if field_value && field_def.validator && (validation_code = field_def.validator.call(self.fetch(field_def.name), self))
        errors << {code: "VALIDATION_FAILED", validation_code: validation_code, field: field_def.name}
        next
      end

      if field_value && field_def.type.is_a?(Array)
        child_type = field_def.type[0]
        if child_type.included_modules.include?(DTO)
          field_value.each do |field_item|
            errors += field_item.validate
          end
        end
      end
    end

    errors
  end

  def new?
    !fetch('id', false)
  end

  module ClassMethods

    def self.extended(base)
      base.instance_variable_set(:"@dto_fields", {})
      base.define_field(:lock_version, Integer, required: false)
    end

    def add_field(field)
      @dto_fields[field.name] = field
    end

    def dto_fields
      @dto_fields.values
    end

    def define_field(field_name, field_type, validator: nil, required: true, default: nil)
      add_field(Field.new(name: field_name.to_s,
                          required: default ? false : required,
                          default: default,
                          type: field_type,
                          validator: validator))
    end

    def dto_field_for_name(name)
      @dto_fields.fetch(name, nil)
    end

    def dto_prepare_hash(values)
      result = DTO.clone_and_convert_keys(values.to_hash).map {|k, v| [k, dto_coerce_type(k, v)]}.to_h

      dto_fields.each do |field|
        if !field.default.nil? && result[field.name].nil?
          result[field.name] ||= dto_try_clone(field.default)
        end
      end

      result
    end

    def dto_try_clone(value)
      case value
      when Numeric, Symbol, true, false, nil
        value
      else
        if value.respond_to?(:clone)
          value.clone
        else
          value
        end
      end
    end

    def dto_coerce_type(field, value, &error_callback)
      field_definition = dto_field_for_name(field)

      if value.nil? && !field_definition.default.nil?
        value = dto_try_clone(field_definition.default)
      end

      if field_definition
        begin
          if field_definition.type.is_a?(Array)
            field_type = field_definition.type[0]

            unless value.is_a?(Array)
              raise TypeError.new("Need an array for this field")
            end

            value.map {|subval|
              if subval.respond_to?(:to_hash) && field_type.respond_to?(:from_hash)
                field_type.from_hash(subval.to_hash)
              else
                DTOTypes.send(field_type.name.intern, subval)
              end
            }
          else
            field_type = field_definition.type

            if value.respond_to?(:to_hash) && field_type.respond_to?(:from_hash)
              field_type.from_hash(value.to_hash)
            else
              DTOTypes.send(field_definition.type.name.intern, value)
            end
          end
        rescue ArgumentError, TypeError
          if error_callback
            error_callback.call(self, field_definition, value)
          end

          return value
        end
      else
        value
      end
    end

    def from_hash(hash)
      new(hash)
    end

    def from_json(json)
      new(JSON.parse(json))
    end

  end

  Field = Struct.new(:name, :required, :type, :validator, :default) do
    def initialize(opts)
      opts.each do |k, v|
        self.send(:"#{k}=", v)
      end
    end
  end
end
